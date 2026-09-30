<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\StudentResultReleaseMode;
use App\Models\AssessmentAttempt;
use LogicException;

/**
 * The one Stage 9 rule for showing an Attempt result to its Student (docs/09 §17.4,
 * S09-DOC-001 §12): the Institution releases results automatically and the Attempt is checked
 * and eligible. A Blitz result also needs the task closed or archived; Blitz callers read only
 * such tasks.
 */
final class StudentResultVisibility
{
    public function released(?StudentResultReleaseMode $mode): bool
    {
        return $mode === StudentResultReleaseMode::Automatic;
    }

    public function visible(AssessmentAttempt $attempt, bool $released): bool
    {
        $visible = $released && $attempt->status === AssessmentAttemptStatus::Checked && $attempt->official_score_eligible;

        if ($visible && $attempt->normalized_score === null) {
            throw new LogicException('A checked Attempt has no normalized score.');
        }

        return $visible;
    }
}
