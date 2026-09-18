<?php

namespace App\Actions\Teacher;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\UserRole;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TaskNotActiveException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\User;
use App\Support\Student\StudentBlitzAttemptSummary;
use App\Support\Student\StudentBlitzReadSnapshot;
use App\Support\Student\StudentBlitzTiming;
use App\Support\Teacher\TeacherBlitzAccess;
use App\Support\Teacher\TeacherBlitzMonitoring;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class ShowTeacherBlitzMonitoring
{
    public function __construct(
        private readonly TeacherBlitzAccess $access,
        private readonly FinalizeTimedOutBlitzAttempts $finalizeTimeouts,
        private readonly StudentBlitzReadSnapshot $snapshots,
        private readonly StudentBlitzAttemptSummary $history,
        private readonly StudentBlitzTiming $timing,
    ) {}

    public function __invoke(User $teacher, string $blitzId): TeacherBlitzMonitoring
    {
        $authorized = $this->access->resolveBlitz($teacher, $blitzId);
        if ($this->task($teacher, $authorized)->status === BlitzStatus::Active) {
            ($this->finalizeTimeouts)($teacher->institution_id, $authorized->id);
        }

        $reconciled = [];
        do {
            [$projection, $due] = $this->snapshots->read(
                fn (CarbonImmutable $snapshotAt): array => $this->read($teacher, $authorized->id, $snapshotAt),
            );
            if ($due === []) {
                return $projection;
            }
            if (array_intersect_key($due, $reconciled) !== []) {
                throw new LogicException('Blitz timeout reconciliation made no progress between final snapshots.');
            }
            $reconciled += $due;
            ($this->finalizeTimeouts)($teacher->institution_id, $authorized->id);
        } while (true);
    }

    /** @return array{?TeacherBlitzMonitoring, array<string, true>} */
    private function read(User $teacher, string $blitzId, CarbonImmutable $snapshotAt): array
    {
        $assessment = $this->access->resolveBlitz($teacher, $blitzId);
        $blitz = $this->task($teacher, $assessment);
        match ($blitz->status) {
            BlitzStatus::Active => null,
            BlitzStatus::Closed => throw new TaskClosedException,
            BlitzStatus::Archived => throw new TaskArchivedException,
            default => throw new TaskNotActiveException,
        };
        $this->timing->assertValidTask($blitz);

        $recipients = AssessmentStudent::query()->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->get(['id', 'institution_id', 'assessment_id', 'student_id'])->keyBy('student_id');
        $students = User::query()->where('institution_id', $teacher->institution_id)
            ->whereIn('id', $recipients->keys())->orderByRaw('lower(users.full_name) ASC')->orderBy('users.id')
            ->get(['id', 'institution_id', 'role', 'full_name']);
        if ($students->count() !== $recipients->count()) {
            throw new LogicException('Every Blitz recipient requires a same-Institution Student.');
        }
        $attempts = AssessmentAttempt::query()->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)->get([
                'id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id',
                'attempt_number', 'status', 'started_at', 'deadline_at', 'submitted_at', 'finalized_at',
                'locked_at', 'finalization_reason', 'official_score_eligible', 'possible_points',
            ])->groupBy('student_id');
        $exceptions = BlitzAttemptException::query()->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)->get([
                'id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id',
                'invalidated_attempt_id', 'replacement_attempt_id', 'reason_type', 'reason', 'granted_at',
            ])->groupBy('student_id');
        if ($attempts->keys()->diff($recipients->keys())->isNotEmpty()
            || $exceptions->keys()->diff($recipients->keys())->isNotEmpty()) {
            throw new LogicException('Blitz history requires an authoritative recipient.');
        }

        $rows = [];
        $due = [];
        foreach ($students as $student) {
            if ($student->role !== UserRole::Student) {
                throw new LogicException('Every Blitz recipient requires a same-Institution Student.');
            }
            $studentAttempts = $attempts->get($student->id, new Collection);
            $studentExceptions = $exceptions->get($student->id, new Collection);
            if ($studentExceptions->count() > 1) {
                throw new LogicException('Blitz permits at most one exception per Student.');
            }
            $exception = $studentExceptions->first();
            $attempt = $this->history->validateHistory($student, $assessment, $blitz,
                $recipients->get($student->id)->id, $studentAttempts, $exception);
            foreach ($studentAttempts as $historicalAttempt) {
                if ($historicalAttempt->status !== AssessmentAttemptStatus::InProgress) {
                    $this->history->assertTerminal($historicalAttempt);
                } elseif ($historicalAttempt->deadline_at->lte($snapshotAt)) {
                    $due[$historicalAttempt->id] = true;
                }
            }
            $available = $this->history->replacementAvailable($attempt, $exception, $blitz);
            // An unused exception invalidates #1; the current replacement path has no Attempt yet.
            $rows[] = $this->studentRow($student, $blitz, $available ? null : $attempt, $exception, $available, $snapshotAt);
        }
        if ($due !== []) {
            return [null, $due];
        }

        $summary = ['assigned' => count($rows), 'not_started' => 0, 'in_progress' => 0,
            'finalized' => 0, 'waiting_for_teacher_review' => 0, 'attempt_exceptions_granted' => 0];
        foreach ($rows as $row) {
            $summary[$row['status']]++;
            $summary['attempt_exceptions_granted'] += $row['attempt_exception'] === null ? 0 : 1;
        }

        return [new TeacherBlitzMonitoring([
            'id' => $assessment->id,
            'status' => $blitz->status->value,
            'duration_seconds' => $blitz->duration_seconds,
            'activated_at' => $this->serialize($blitz->activated_at),
            'timing' => [
                'mode' => $blitz->timer_start_mode_snapshot->value,
                'synchronized_ends_at' => $this->serialize($blitz->synchronized_ends_at),
                'server_now' => $this->serialize($snapshotAt),
            ],
        ], $summary, $rows), []];
    }

    private function task(User $teacher, Assessment $assessment): BlitzTask
    {
        return BlitzTask::query()->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)->first([
                'assessment_id', 'institution_id', 'status', 'duration_seconds', 'activated_at',
                'timer_start_mode_snapshot', 'synchronized_ends_at',
            ]) ?? throw new NotFoundHttpException;
    }

    /** @return array<string, mixed> */
    private function studentRow(User $student, BlitzTask $blitz, ?AssessmentAttempt $attempt,
        ?BlitzAttemptException $exception, bool $available, CarbonImmutable $snapshotAt): array
    {
        $status = match ($attempt?->status) {
            null => 'not_started',
            AssessmentAttemptStatus::InProgress => 'in_progress',
            AssessmentAttemptStatus::WaitingForTeacherReview => 'waiting_for_teacher_review',
            default => 'finalized',
        };
        $timing = $this->timing->project($blitz, $attempt, $snapshotAt, $available);

        return [
            'student' => ['id' => $student->id, 'full_name' => $student->full_name],
            'status' => $status,
            'attempt_number' => $attempt?->attempt_number,
            'started_at' => $this->serialize($attempt?->started_at),
            'deadline_at' => $this->serialize($attempt?->deadline_at),
            'remaining_seconds' => $timing['remaining_seconds'],
            'finalization_reason' => $attempt?->finalization_reason?->value,
            'score' => null,
            'attempt_exception' => $exception === null ? null : [
                'id' => $exception->id,
                'invalidated_attempt_id' => $exception->invalidated_attempt_id,
                'replacement_attempt_id' => $exception->replacement_attempt_id,
                'reason_type' => $exception->reason_type->value,
                'reason' => $exception->reason,
                'granted_at' => $this->serialize($exception->granted_at),
                'replacement_attempt_available' => $available,
            ],
        ];
    }

    private function serialize(?CarbonInterface $instant): ?string
    {
        return $instant?->copy()->utc()->format('Y-m-d\TH:i:s\Z');
    }
}
