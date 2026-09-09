<?php

namespace App\Actions\Student;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\IdempotencyOperation;
use App\Enums\TopicStatus;
use App\Exceptions\Student\AttemptsExhaustedException;
use App\Exceptions\Student\StudentHomeworkArchivedException;
use App\Exceptions\Student\StudentHomeworkClosedException;
use App\Exceptions\Student\StudentHomeworkConflictException;
use App\Exceptions\Student\StudentHomeworkDeadlinePassedException;
use App\Exceptions\Student\StudentHomeworkNotActiveException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Student\StudentHomeworkAccess;
use App\Support\Student\StudentHomeworkAttemptAccess;
use App\Support\Student\StudentHomeworkAttemptStartResult;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;

final class StartStudentHomeworkAttempt
{
    public function __construct(
        private readonly StudentHomeworkAccess $homeworkAccess,
        private readonly StudentHomeworkAttemptAccess $attemptAccess,
        private readonly IdempotencyRequestFingerprint $fingerprints,
        private readonly IdempotencyGuard $idempotency,
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeAtDeadline,
    ) {}

    public function __invoke(User $student, string $homeworkId, string $idempotencyKey): StudentHomeworkAttemptStartResult
    {
        $authorizedHomework = $this->homeworkAccess->resolve($student, $homeworkId);
        $operation = IdempotencyOperation::StudentHomeworkAttemptStart;
        $fingerprint = $this->fingerprints->make($student, $operation, ['homework_id' => strtolower($authorizedHomework->id)]);

        $result = DB::transaction(function () use ($student, $authorizedHomework, $operation, $idempotencyKey, $fingerprint): ?StudentHomeworkAttemptStartResult {
            ['topic' => $topic, 'assessment' => $assessment, 'homework' => $homework] = $this->attemptAccess->lockHomework($student, $authorizedHomework);

            $replay = $this->idempotency->completedReplay($student, $operation, $idempotencyKey, $fingerprint);

            if ($replay !== null) {
                return $this->replay($student, $assessment, $replay);
            }

            $recipient = $this->attemptAccess->lockRecipient($student, $assessment);
            $claim = $this->idempotency->claim($student, $operation, $idempotencyKey, $fingerprint);

            if (! $claim->new) {
                return $this->replay($student, $assessment, $claim->record);
            }

            $this->assertActive($topic, $homework);
            $pair = $this->attemptAccess->lockPair($student, $topic);
            $official = $pair !== null && $pair->homework_assessment_id === $assessment->id;
            $attempts = $official
                ? $this->attemptAccess->lockAllAttempts($student, $assessment)
                : $this->attemptAccess->lockStudentAttempts($student, $assessment);
            $studentAttempts = $this->validateHistory($student, $assessment, $recipient, $attempts);

            // All parent, idempotency and activity waits precede the Start decision instant.
            $startedAt = now();

            if ($homework->deadline_at !== null && $startedAt->gte($homework->deadline_at)) {
                $this->idempotency->abandon($claim);

                if (! $official) {
                    $attempts = $this->attemptAccess->lockAllAttempts($student, $assessment);
                    $this->validateHistory($student, $assessment, $recipient, $attempts);
                }

                $this->finalizeAtDeadline->finalizeLocked($homework, $attempts, $startedAt);

                // A rejected Start must commit due-work reconciliation before raising its error.
                return null;
            }

            if ($official) {
                $this->assertOfficialPair($pair, $assessment, $recipient, $attempts);
            }

            if ($assessment->total_possible_points <= 0) {
                throw new StudentHomeworkConflictException;
            }

            $current = $studentAttempts->first(fn (AssessmentAttempt $attempt) => $attempt->status === AssessmentAttemptStatus::InProgress);

            if ($current !== null) {
                $this->idempotency->complete($claim, 'assessment_attempt', $current->id, 200);

                return new StudentHomeworkAttemptStartResult($current->id, 200);
            }

            $lastNumber = $studentAttempts->max('attempt_number') ?? 0;

            if ($lastNumber >= 3) {
                throw new AttemptsExhaustedException;
            }

            if ($official && $pair->locked_at === null) {
                $pair->locked_at = $startedAt;
                $pair->updated_at = $startedAt;
                $pair->save();
            }

            $attempt = AssessmentAttempt::query()->create([
                'institution_id' => $student->institution_id,
                'assessment_id' => $assessment->id,
                'assessment_student_id' => $recipient->id,
                'student_id' => $student->id,
                'attempt_number' => $lastNumber + 1,
                'status' => AssessmentAttemptStatus::InProgress,
                'started_at' => $startedAt,
                'deadline_at' => null,
                'submitted_at' => null,
                'finalized_at' => null,
                'finalization_reason' => null,
                'locked_at' => null,
                'official_score_eligible' => true,
                'earned_points' => null,
                'possible_points' => $assessment->total_possible_points,
                'normalized_score' => null,
                'scoring_completed_at' => null,
            ]);
            $this->idempotency->complete($claim, 'assessment_attempt', $attempt->id, 201);

            return new StudentHomeworkAttemptStartResult($attempt->id, 201);
        });

        if ($result === null) {
            throw new StudentHomeworkDeadlinePassedException;
        }

        return $result;
    }

    private function replay(User $student, Assessment $assessment, IdempotencyRecord $record): StudentHomeworkAttemptStartResult
    {
        if ($record->result_resource_type !== 'assessment_attempt'
            || ! is_string($record->result_resource_id)
            || ! Str::isUuid($record->result_resource_id)
            || ! in_array($record->response_status, [200, 201], true)) {
            throw new LogicException('Completed Start idempotency metadata must reference a successful Attempt.');
        }

        $attempt = $this->attemptAccess->replayAttempt($student, $assessment, $record->result_resource_id);

        if ($attempt === null) {
            throw new LogicException('Completed Start must reference its authorized Student Homework Attempt.');
        }

        $this->assertValidAttempt($student, $assessment, $attempt);

        return new StudentHomeworkAttemptStartResult($attempt->id, $record->response_status);
    }

    private function assertActive(Topic $topic, HomeworkAssignment $homework): void
    {
        if ($topic->status !== TopicStatus::Active) {
            throw new StudentHomeworkNotActiveException;
        }

        match ($homework->status) {
            HomeworkStatus::Active => null,
            HomeworkStatus::Closed => throw new StudentHomeworkClosedException,
            HomeworkStatus::Archived => throw new StudentHomeworkArchivedException,
            default => throw new StudentHomeworkNotActiveException,
        };
    }

    /**
     * @param  Collection<int, AssessmentAttempt>  $attempts
     * @return Collection<int, AssessmentAttempt>
     */
    private function validateHistory(User $student, Assessment $assessment, AssessmentStudent $recipient, Collection $attempts): Collection
    {
        foreach ($attempts as $attempt) {
            $this->assertValidAttempt($student, $assessment, $attempt);

            if ($attempt->student_id === $student->id && $attempt->assessment_student_id !== $recipient->id) {
                throw new LogicException('Homework Attempt must match the locked Student recipient.');
            }
        }

        $studentAttempts = $attempts->where('student_id', $student->id)->sortBy('attempt_number')->values();
        $numbers = $studentAttempts->pluck('attempt_number')->all();

        if ($numbers !== ($numbers === [] ? [] : range(1, count($numbers)))
            || count($numbers) > 3
            || $studentAttempts->where('status', AssessmentAttemptStatus::InProgress)->count() > 1) {
            throw new LogicException('Homework Attempt history must form the normal sequential prefix.');
        }

        return $studentAttempts;
    }

    private function assertValidAttempt(User $student, Assessment $assessment, AssessmentAttempt $attempt): void
    {
        $recipient = $attempt->relationLoaded('assessmentStudent') ? $attempt->getRelation('assessmentStudent') : null;

        if ($attempt->institution_id !== $student->institution_id
            || $attempt->assessment_id !== $assessment->id
            || ! $recipient instanceof AssessmentStudent
            || $recipient->id !== $attempt->assessment_student_id
            || $recipient->institution_id !== $student->institution_id
            || $recipient->assessment_id !== $assessment->id
            || $recipient->student_id !== $attempt->student_id) {
            throw new LogicException('Homework Attempt must match its authoritative recipient graph.');
        }

        if ($attempt->deadline_at !== null
            || ! in_array($attempt->status, [
                AssessmentAttemptStatus::InProgress,
                AssessmentAttemptStatus::Submitted,
                AssessmentAttemptStatus::WaitingForTeacherReview,
                AssessmentAttemptStatus::Checked,
            ], true)
            || $attempt->finalization_reason === AssessmentAttemptFinalizationReason::TimeoutAutoSubmit) {
            throw new LogicException('Homework Attempt contains an invalid Homework state.');
        }

        if ($attempt->status === AssessmentAttemptStatus::InProgress
            && ($attempt->submitted_at !== null || $attempt->finalized_at !== null
                || $attempt->locked_at !== null || $attempt->finalization_reason !== null)) {
            throw new LogicException('An in-progress Homework Attempt must remain structurally editable.');
        }
    }

    /** @param Collection<int, AssessmentAttempt> $attempts */
    private function assertOfficialPair(TopicResultPair $pair, Assessment $assessment, AssessmentStudent $recipient, Collection $attempts): void
    {
        if ($pair->cohort_snapshotted_at === null
            || $assessment->assignment_mode !== AssessmentAssignmentMode::Group
            || $recipient->assignment_source !== AssessmentAssignmentSource::Group
            || ($pair->locked_at === null && $attempts->isNotEmpty())
            || ($pair->locked_at !== null && $attempts->isEmpty())) {
            throw new StudentHomeworkConflictException;
        }
    }
}
