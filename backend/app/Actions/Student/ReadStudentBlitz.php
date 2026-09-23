<?php

namespace App\Actions\Student;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\Topic;
use App\Models\User;
use App\Support\Student\StudentBlitzAccess;
use App\Support\Student\StudentBlitzAttemptSummary;
use App\Support\Student\StudentBlitzReadSnapshot;
use App\Support\Student\StudentBlitzTiming;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class ReadStudentBlitz
{
    public function __construct(
        private readonly StudentBlitzAccess $access,
        private readonly StudentBlitzAttemptSummary $history,
        private readonly StudentBlitzTiming $timing,
        private readonly StudentBlitzReadSnapshot $snapshots,
        private readonly ReconcileStudentBlitzTimeouts $reconcileTimeouts,
        private readonly FinalizeTimedOutBlitzAttempts $finalizeTimeouts,
    ) {}

    /** @return Collection<int, Assessment> */
    public function __invoke(User $student, ?string $blitzId = null): Collection
    {
        if ($blitzId === null) {
            $this->reconcileTimeouts->all($student, $this->timing->now());
        } else {
            $authorized = $this->access->resolveAssigned($student, $blitzId);
            $this->reconcileTimeouts->one($student, $authorized, $this->timing->now());
        }

        $reconciled = [];
        do {
            [$assessments, $due, $dueAt] = $this->snapshots->read(function (CarbonImmutable $snapshotAt) use ($student, $blitzId): array {
                $assessments = $blitzId === null
                    ? $this->access->activeQuery($student, $snapshotAt)->get()
                    : $this->access->readQuery($student)->whereKey($blitzId)->get();
                if ($blitzId !== null && $assessments->isEmpty()) {
                    throw new NotFoundHttpException;
                }

                $due = [];
                foreach ($assessments as $assessment) {
                    if ($blitzId !== null && $assessment->getRelation('blitzTask')->status !== BlitzStatus::Active) {
                        throw new StudentBlitzNotActiveException;
                    }
                    foreach ($assessment->getRelation('attempts') as $attempt) {
                        if ($attempt->status === AssessmentAttemptStatus::InProgress
                            && $attempt->deadline_at !== null && $attempt->deadline_at->lte($snapshotAt)) {
                            $due[$attempt->id] = $assessment->id;
                        }
                    }
                }
                if ($due !== []) {
                    return [new Collection, $due, $snapshotAt];
                }

                $eligible = new Collection;
                foreach ($assessments as $assessment) {
                    $blitz = $assessment->getRelation('blitzTask');
                    if (! $blitz instanceof BlitzTask || ! $assessment->getRelation('topic') instanceof Topic) {
                        throw new LogicException('Student Blitz requires its scoped task and Topic projection.');
                    }
                    $exceptions = $assessment->getRelation('blitzAttemptExceptions');
                    if ($exceptions->count() > 1) {
                        throw new LogicException('Blitz permits at most one exception per Student.');
                    }
                    $exception = $exceptions->first();
                    $this->timing->assertValidTask($blitz);
                    $attempt = $this->history->validateHistory($student, $assessment, $blitz,
                        $assessment->getAttribute('student_recipient_id'), $assessment->getRelation('attempts'), $exception);
                    $available = $this->history->replacementAvailable($attempt, $exception, $blitz);
                    if ($blitzId === null && $attempt !== null
                        && $attempt->status !== AssessmentAttemptStatus::InProgress && ! $available) {
                        continue;
                    }
                    if ($blitzId !== null) {
                        $this->timing->assertExecutable($blitz, $attempt, $snapshotAt, $available);
                    }
                    $timing = $this->timing->project($blitz, $attempt, $snapshotAt, $available);
                    if ($blitzId === null && $timing['remaining_seconds'] === 0) {
                        continue;
                    }
                    $assessment->setAttribute('student_blitz_timing', $timing);
                    $assessment->setAttribute('student_blitz_attempt_summary', $this->history->project($attempt, $exception, $blitz));
                    $eligible->push($assessment);
                }

                return [$eligible, [], $snapshotAt];
            });
            if ($due === []) {
                return $assessments;
            }
            if (array_intersect_key($due, $reconciled) !== []) {
                throw new LogicException('Blitz timeout reconciliation made no progress between final snapshots.');
            }
            $reconciled += $due;
            foreach (array_unique($due) as $assessmentId) {
                ($this->finalizeTimeouts)($student->institution_id, $assessmentId, $dueAt);
            }
        } while (true);
    }
}
