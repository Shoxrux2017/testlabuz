<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use LogicException;

/**
 * The one rule for showing an Attempt result to its Student (docs/09 §17.4): the task's results are
 * released (StudentResultRelease), the Attempt is checked and eligible, and a Blitz Attempt's Blitz
 * is closed or archived (a Student who finishes early never sees a score while the Blitz is still running).
 */
final class StudentResultVisibility
{
    /** @param Assessment $task The Attempt's task; a Blitz needs its `blitzTask` loaded */
    public function visible(AssessmentAttempt $attempt, Assessment $task, bool $released): bool
    {
        if ($attempt->assessment_id !== $task->id) {
            throw new LogicException('An Attempt result is shown for the Attempt\'s own task.');
        }

        // Evaluated first, so a caller that omits the task type or Blitz status fails even when nothing is released.
        $finished = $this->finished($task);
        $visible = $released && $finished
            && $attempt->status === AssessmentAttemptStatus::Checked && $attempt->official_score_eligible;

        if ($visible && $attempt->normalized_score === null) {
            throw new LogicException('A checked Attempt has no normalized score.');
        }

        return $visible;
    }

    private function finished(Assessment $task): bool
    {
        if (! $task->type instanceof AssessmentType) {
            throw new LogicException('An Attempt result needs its task type.');
        }

        if ($task->type === AssessmentType::Homework) {
            return true;
        }

        $blitz = $task->relationLoaded('blitzTask') ? $task->getRelation('blitzTask') : null;

        if (! $blitz instanceof BlitzTask) {
            throw new LogicException('A Blitz Attempt result needs its loaded Blitz status.');
        }

        return in_array($blitz->status, [BlitzStatus::Closed, BlitzStatus::Archived], true);
    }
}
