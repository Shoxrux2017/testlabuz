<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\IdempotencyOperation;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\IdempotencyRecord;
use App\Models\User;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use LogicException;

final readonly class StudentBlitzHistoricalAnswerReadProof
{
    private function __construct(
        public IdempotencyOperation $originOperation,
        public string $referencedAttemptId,
        public int $completedResponseStatus,
        public AssessmentAttemptFinalizationReason $terminalFinalizationReason,
        public ?string $startIntent,
        public ?string $resumeAttemptId,
        private string $institutionId,
        private string $studentId,
        private string $assessmentId,
        private string $recipientId,
    ) {}

    public static function forSubmit(User $student, Assessment $assessment, AssessmentAttempt $attempt, IdempotencyRecord $record, string $key, string $fingerprint): self
    {
        self::assertRequestFingerprint($student, IdempotencyOperation::StudentBlitzAttemptSubmit, ['attempt_id' => strtolower($attempt->id)], [], $fingerprint);
        self::assertCompletedIdentity($student, $assessment, $attempt, $record, $key, $fingerprint, IdempotencyOperation::StudentBlitzAttemptSubmit);

        if ($record->response_status !== 200 || $attempt->finalization_reason !== AssessmentAttemptFinalizationReason::StudentSubmit) {
            throw new LogicException('Historical Submit replay requires its original Student Submit lineage.');
        }

        self::assertHistoricalLineage($attempt);

        return self::fromVerifiedReplay($student, $attempt, $record, null, null);
    }

    public static function forStart(User $student, Assessment $assessment, AssessmentAttempt $attempt, IdempotencyRecord $record, string $key, string $fingerprint, string $intent, ?string $resumeAttemptId = null): self
    {
        $body = ['intent' => $intent];

        if ($intent === 'resume' && $resumeAttemptId !== null) {
            $body['attempt_id'] = strtolower($resumeAttemptId);
        }

        self::assertRequestFingerprint($student, IdempotencyOperation::StudentBlitzAttemptStart, ['blitz_id' => strtolower($assessment->id)], $body, $fingerprint);
        self::assertCompletedIdentity($student, $assessment, $attempt, $record, $key, $fingerprint, IdempotencyOperation::StudentBlitzAttemptStart);
        $validIntent = match ($intent) {
            'start_normal' => $attempt->attempt_number === 1 && $resumeAttemptId === null,
            'resume' => $resumeAttemptId === $attempt->id && $record->response_status === 200,
            'start_replacement' => $attempt->attempt_number === 2 && $resumeAttemptId === null
                && BlitzAttemptException::query()->where('institution_id', $student->institution_id)
                    ->where('assessment_id', $assessment->id)->where('student_id', $student->id)
                    ->where('assessment_student_id', $attempt->assessment_student_id)
                    ->where('replacement_attempt_id', $attempt->id)->exists(),
            default => false,
        };

        if (! $validIntent || ! in_array($record->response_status, [200, 201], true)) {
            throw new LogicException('Historical Start replay requires its original intent-specific Attempt.');
        }

        self::assertHistoricalLineage($attempt);

        return self::fromVerifiedReplay($student, $attempt, $record, $intent, $resumeAttemptId);
    }

    public function assertMatches(User $student, Assessment $assessment, AssessmentAttempt $attempt): void
    {
        if ($this->institutionId !== $student->institution_id || $this->studentId !== $student->id
            || $this->assessmentId !== $assessment->id || $this->referencedAttemptId !== $attempt->id
            || $this->institutionId !== $attempt->institution_id || $this->studentId !== $attempt->student_id
            || $this->assessmentId !== $attempt->assessment_id || $this->recipientId !== $attempt->assessment_student_id
            || $this->terminalFinalizationReason !== $attempt->finalization_reason) {
            throw new LogicException('Historical answer read proof does not match the authorized Attempt.');
        }

        self::assertHistoricalLineage($attempt);
    }

    private static function assertRequestFingerprint(User $student, IdempotencyOperation $operation, array $route, array $body, string $fingerprint): void
    {
        if ((new IdempotencyRequestFingerprint)->make($student, $operation, $route, $body) !== $fingerprint) {
            throw new LogicException('Historical replay proof requires the exact original semantic request.');
        }
    }

    private static function assertCompletedIdentity(User $student, Assessment $assessment, AssessmentAttempt $attempt, IdempotencyRecord $record, string $key, string $fingerprint, IdempotencyOperation $operation): void
    {
        if (! $record->exists || $record->institution_id !== $student->institution_id || $record->user_id !== $student->id
            || $record->operation !== $operation || $record->idempotency_key !== strtolower($key)
            || $record->request_fingerprint !== $fingerprint || $record->completed_at === null
            || $record->result_resource_type !== 'assessment_attempt' || $record->result_resource_id !== $attempt->id
            || $assessment->institution_id !== $student->institution_id || $assessment->type !== AssessmentType::Blitz
            || $attempt->institution_id !== $student->institution_id || $attempt->student_id !== $student->id
            || $attempt->assessment_id !== $assessment->id
            || ! AssessmentStudent::query()->where('institution_id', $student->institution_id)
                ->where('assessment_id', $assessment->id)->where('student_id', $student->id)
                ->whereKey($attempt->assessment_student_id)->exists()) {
            throw new LogicException('Historical answer read requires an authorized completed replay identity.');
        }
    }

    private static function assertHistoricalLineage(AssessmentAttempt $attempt): void
    {
        if (! in_array($attempt->status, [AssessmentAttemptStatus::WaitingForTeacherReview, AssessmentAttemptStatus::Checked], true)
            || $attempt->started_at === null || $attempt->deadline_at === null
            || ! $attempt->started_at->lt($attempt->deadline_at)
            || $attempt->finalized_at === null || $attempt->locked_at === null
            || ! $attempt->locked_at->equalTo($attempt->finalized_at)) {
            throw new LogicException('Historical answer read requires a valid terminal execution lineage.');
        }

        $valid = match ($attempt->finalization_reason) {
            AssessmentAttemptFinalizationReason::StudentSubmit => $attempt->submitted_at !== null
                && $attempt->submitted_at->equalTo($attempt->finalized_at) && $attempt->finalized_at->lt($attempt->deadline_at),
            AssessmentAttemptFinalizationReason::TimeoutAutoSubmit => $attempt->submitted_at === null
                && $attempt->finalized_at->equalTo($attempt->deadline_at),
            AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize => $attempt->submitted_at === null
                && $attempt->finalized_at->lt($attempt->deadline_at),
            default => false,
        };

        if (! $valid) {
            throw new LogicException('Historical answer read requires a valid terminal execution lineage.');
        }
    }

    private static function fromVerifiedReplay(User $student, AssessmentAttempt $attempt, IdempotencyRecord $record, ?string $intent, ?string $resumeAttemptId): self
    {
        return new self($record->operation, $attempt->id, $record->response_status, $attempt->finalization_reason,
            $intent, $resumeAttemptId, $student->institution_id, $student->id, $attempt->assessment_id, $attempt->assessment_student_id);
    }
}
