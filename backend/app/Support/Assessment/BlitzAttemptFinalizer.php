<?php

namespace App\Support\Assessment;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use Carbon\CarbonInterface;
use LogicException;

final class BlitzAttemptFinalizer
{
    public function assertValidAttempt(AssessmentAttempt $attempt, string $institutionId, string $assessmentId): void
    {
        if ($attempt->institution_id !== $institutionId || $attempt->assessment_id !== $assessmentId) {
            throw new LogicException('A locked Attempt does not belong to the Blitz aggregate.');
        }

        if ($attempt->started_at === null || $attempt->deadline_at === null
            || $attempt->deadline_at->lte($attempt->started_at)) {
            throw new LogicException('An in-progress Blitz Attempt has inconsistent execution timestamps.');
        }

        $this->assertUnfinalized($attempt);
    }

    public function finalizeByStudentSubmit(AssessmentAttempt $attempt, CarbonInterface $submittedAt): bool
    {
        if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
            return false;
        }

        $this->assertUnfinalized($attempt);

        if ($submittedAt->gte($attempt->deadline_at)) {
            throw new LogicException('A due Blitz Attempt cannot be finalized by Student Submit.');
        }

        $attempt->status = AssessmentAttemptStatus::Submitted;
        $attempt->submitted_at = $submittedAt;
        $attempt->finalized_at = $submittedAt;
        $attempt->locked_at = $submittedAt;
        $attempt->finalization_reason = AssessmentAttemptFinalizationReason::StudentSubmit;
        $attempt->updated_at = $submittedAt;
        $attempt->save();

        return true;
    }

    public function finalizeAtTimeout(AssessmentAttempt $attempt): bool
    {
        if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
            return false;
        }

        $this->assertUnfinalized($attempt);

        return $this->finalize($attempt, $attempt->deadline_at,
            AssessmentAttemptStatus::TimedOutFinalized, AssessmentAttemptFinalizationReason::TimeoutAutoSubmit);
    }

    public function finalizeAtClose(AssessmentAttempt $attempt, CarbonInterface $closedAt): bool
    {
        if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
            return false;
        }

        $this->assertUnfinalized($attempt);

        if ($closedAt->gte($attempt->deadline_at)) {
            throw new LogicException('A due Blitz Attempt must be finalized at its deadline.');
        }

        return $this->finalize($attempt, $closedAt,
            AssessmentAttemptStatus::Submitted, AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize);
    }

    private function assertUnfinalized(AssessmentAttempt $attempt): void
    {
        if ($attempt->deadline_at === null || $attempt->submitted_at !== null || $attempt->finalized_at !== null
            || $attempt->locked_at !== null || $attempt->finalization_reason !== null) {
            throw new LogicException('An in-progress Blitz Attempt has inconsistent finalization fields.');
        }
    }

    // The caller holds the Attempt row lock until the surrounding transaction commits.
    private function finalize(
        AssessmentAttempt $attempt,
        CarbonInterface $finalizedAt,
        AssessmentAttemptStatus $status,
        AssessmentAttemptFinalizationReason $reason,
    ): bool {
        $attempt->status = $status;
        $attempt->submitted_at = null;
        $attempt->finalized_at = $finalizedAt;
        $attempt->locked_at = $finalizedAt;
        $attempt->finalization_reason = $reason;
        $attempt->save();

        return true;
    }
}
