<?php

namespace App\Support\Results;

use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Enums\TopicResultStatus;

/**
 * The Topic-result visibility rule (docs/09 §27.1-27.2): the values reach the Student only once the
 * result is an outcome and the Student's work is finished, then by automatic release or a Teacher
 * release; the Parent never before the Student, and never in the hidden mode. The current
 * Institution modes apply; Teacher releases already made stay (S10-D5, S10-D6).
 */
final class TopicResultVisibility
{
    public function of(TopicResultView $view, ?StudentResultReleaseMode $studentMode, ?ParentResultReleaseMode $parentMode): TopicResultVisibilityState
    {
        $outcome = ($view->terminal || $view->status === TopicResultStatus::Closed) && $view->workFinished;
        $studentReleased = $view->row?->student_released_at !== null;
        $parentReleased = $view->row?->parent_released_at !== null;
        $studentVisible = $outcome && ($studentMode === StudentResultReleaseMode::Automatic || $studentReleased);

        return new TopicResultVisibilityState(
            studentVisible: $studentVisible,
            parentVisible: $studentVisible && ($parentMode === ParentResultReleaseMode::WithStudent
                || ($parentMode === ParentResultReleaseMode::ManualTeacher && $parentReleased)),
            canReleaseToStudent: $studentMode === StudentResultReleaseMode::ManualTeacher && ! $studentReleased && $outcome,
            canReleaseToParent: $parentMode === ParentResultReleaseMode::ManualTeacher && ! $parentReleased && $studentVisible,
        );
    }
}
