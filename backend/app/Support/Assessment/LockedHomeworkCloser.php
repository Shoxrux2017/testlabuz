<?php

namespace App\Support\Assessment;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\HomeworkStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\HomeworkAssignment;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;

/**
 * Closes an active Homework whose Assessment, Homework row and Attempts the caller holds locked
 * (BR-HW-012): a passed deadline is reconciled first, otherwise every in-progress Attempt is frozen
 * with `task_closed_auto_finalize`; frozen Attempts are checked after the response. A Teacher close
 * and the official Blitz activation (S10-D8) close a Homework the same way.
 */
final class LockedHomeworkCloser
{
    public function __construct(
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeAtDeadline,
        private readonly HomeworkAttemptFinalizer $finalizer,
    ) {}

    /** @param Collection<int, AssessmentAttempt> $attempts Every Attempt of this Homework, locked */
    public function close(Assessment $assessment, HomeworkAssignment $homework, Collection $attempts, CarbonInterface $closedAt): void
    {
        if ($this->finalizeAtDeadline->finalizeLocked($homework, $attempts, $closedAt) === null) {
            foreach ($attempts as $attempt) {
                $this->finalizer->finalizeAtClose($attempt, $closedAt);
            }
        }

        $homework->status = HomeworkStatus::Closed;
        $homework->closed_at = $closedAt;
        $homework->updated_at = $closedAt;
        $homework->save();

        $assessment->updated_at = $closedAt;
        $assessment->save();
    }
}
