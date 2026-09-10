<?php

namespace App\Support\Assessment;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use Carbon\CarbonInterface;
use LogicException;

final class HomeworkAttemptFinalizer
{
    public function finalizeByStudentSubmit(AssessmentAttempt $attempt, CarbonInterface $submittedAt): bool
    {
        if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
            return false;
        }

        if ($attempt->submitted_at !== null || $attempt->finalized_at !== null
            || $attempt->locked_at !== null || $attempt->finalization_reason !== null) {
            throw new LogicException('An in-progress Homework Attempt has inconsistent finalization fields.');
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

    public function finalizeAtDeadline(AssessmentAttempt $attempt, CarbonInterface $deadlineAt): bool
    {
        return $this->finalize($attempt, $deadlineAt, AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit);
    }

    public function finalizeAtClose(AssessmentAttempt $attempt, CarbonInterface $closedAt): bool
    {
        return $this->finalize($attempt, $closedAt, AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize);
    }

    // The caller holds the Attempt row lock until the surrounding transaction commits.
    private function finalize(
        AssessmentAttempt $attempt,
        CarbonInterface $finalizedAt,
        AssessmentAttemptFinalizationReason $reason,
    ): bool {
        if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
            return false;
        }

        if ($attempt->submitted_at !== null || $attempt->finalized_at !== null
            || $attempt->locked_at !== null || $attempt->finalization_reason !== null) {
            throw new LogicException('An in-progress Homework Attempt has inconsistent finalization fields.');
        }

        $attempt->status = AssessmentAttemptStatus::Submitted;
        $attempt->submitted_at = null;
        $attempt->finalized_at = $finalizedAt;
        $attempt->locked_at = $finalizedAt;
        $attempt->finalization_reason = $reason;
        $attempt->save();

        return true;
    }
}
