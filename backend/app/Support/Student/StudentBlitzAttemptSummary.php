<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

final class StudentBlitzAttemptSummary
{
    public function __construct(private readonly StudentBlitzTiming $timing) {}

    /** @param Collection<int, AssessmentAttempt> $attempts */
    public function validateHistory(User $student, Assessment $assessment, BlitzTask $blitz, string $recipientId, Collection $attempts, ?BlitzAttemptException $exception = null): ?AssessmentAttempt
    {
        if ($attempts->count() > 2) {
            throw new LogicException('Blitz history permits one normal and one replacement Attempt.');
        }

        // Official pair locks use assessment_id/id order; normalize numbered history in memory.
        $attempts = $attempts->sortBy([['attempt_number', 'asc'], ['id', 'asc']])->values();

        foreach ($attempts as $index => $attempt) {
            if ($attempt->institution_id !== $student->institution_id
                || $attempt->assessment_id !== $assessment->id || $attempt->student_id !== $student->id
                || $attempt->assessment_student_id !== $recipientId || $attempt->attempt_number !== $index + 1
                || $attempt->possible_points !== $assessment->total_possible_points
                || ! $attempt->status instanceof AssessmentAttemptStatus) {
                throw new LogicException('Blitz Attempt must match its authoritative recipient history.');
            }

            if ($attempt->status === AssessmentAttemptStatus::InProgress
                && ($attempt->submitted_at !== null || $attempt->finalized_at !== null
                    || $attempt->locked_at !== null || $attempt->finalization_reason !== null)) {
                throw new LogicException('An in-progress Blitz Attempt must remain structurally editable.');
            }

            $this->timing->assertValidAttempt($blitz, $attempt);
        }

        $normal = $attempts->first();
        $replacement = $attempts->get(1);

        if ($exception === null) {
            if ($replacement !== null || ($normal !== null && ! $normal->official_score_eligible)) {
                throw new LogicException('Replacement or invalidation requires a committed Blitz exception.');
            }
        } else {
            if ($exception->institution_id !== $student->institution_id
                || $exception->assessment_id !== $assessment->id || $exception->student_id !== $student->id
                || $exception->assessment_student_id !== $recipientId || $normal === null
                || $normal->status === AssessmentAttemptStatus::InProgress || $normal->official_score_eligible
                || $exception->invalidated_attempt_id !== $normal->id
                || $exception->replacement_attempt_id !== $replacement?->id
                || ($replacement !== null && ! $replacement->official_score_eligible)
                || ! in_array($blitz->status, [BlitzStatus::Active, BlitzStatus::Closed, BlitzStatus::Archived], true)) {
                throw new LogicException('Blitz exception must link the exact terminal normal and optional replacement Attempts.');
            }

            $this->assertTerminal($normal);
            if ($replacement !== null && $replacement->status !== AssessmentAttemptStatus::InProgress) {
                $this->assertTerminal($replacement);
            }
        }

        return $replacement ?? $normal;
    }

    public function assertTerminal(AssessmentAttempt $attempt): void
    {
        if ($attempt->status === AssessmentAttemptStatus::InProgress
            || $attempt->finalized_at === null || $attempt->locked_at === null
            || ! $attempt->locked_at->equalTo($attempt->finalized_at)) {
            throw new LogicException('Terminal Blitz Attempt requires a valid finalization lineage.');
        }

        $valid = match ($attempt->finalization_reason) {
            AssessmentAttemptFinalizationReason::StudentSubmit => $attempt->submitted_at !== null
                && $attempt->submitted_at->equalTo($attempt->finalized_at) && $attempt->finalized_at->lt($attempt->deadline_at)
                && $attempt->status !== AssessmentAttemptStatus::TimedOutFinalized,
            AssessmentAttemptFinalizationReason::TimeoutAutoSubmit => $attempt->submitted_at === null
                && $attempt->finalized_at->equalTo($attempt->deadline_at)
                && $attempt->status !== AssessmentAttemptStatus::Submitted,
            AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize => $attempt->submitted_at === null
                && $attempt->finalized_at->lt($attempt->deadline_at)
                && $attempt->status !== AssessmentAttemptStatus::TimedOutFinalized,
            default => false,
        };

        if (! $valid) {
            throw new LogicException('Terminal Blitz Attempt requires a valid finalization lineage.');
        }
    }

    public function replacementAvailable(?AssessmentAttempt $attempt, ?BlitzAttemptException $exception, BlitzTask $blitz): bool
    {
        return $exception !== null && $exception->replacement_attempt_id === null
            && $attempt !== null && $attempt->status !== AssessmentAttemptStatus::InProgress
            && $blitz->status === BlitzStatus::Active;
    }

    /** @return array<string, mixed> */
    public function project(?AssessmentAttempt $attempt, ?BlitzAttemptException $exception = null, ?BlitzTask $blitz = null): array
    {
        return [
            'normal_attempts' => 1,
            'normal_used' => $attempt === null ? 0 : 1,
            'in_progress_attempt_id' => $attempt?->status === AssessmentAttemptStatus::InProgress ? $attempt->id : null,
            'additional_exception_granted' => $exception !== null,
            'replacement_attempt_available' => $blitz !== null && $this->replacementAvailable($attempt, $exception, $blitz),
        ];
    }
}
