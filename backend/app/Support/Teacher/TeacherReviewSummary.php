<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\User;
use Carbon\CarbonInterface;

/**
 * The review counts on a Teacher task resource (docs/09 §21.3): the task's reviewable
 * submissions waiting for review, and those past the Homework review deadline.
 */
final class TeacherReviewSummary
{
    public function __construct(private readonly TeacherSubmissionAccess $access) {}

    /** @return array{waiting_for_teacher_review: int, overdue: int} */
    public function forTask(User $teacher, Assessment $assessment, ?CarbonInterface $reviewDueAt): array
    {
        $waiting = $this->access->query($teacher)
            ->where('assessment_attempts.assessment_id', $assessment->id)
            ->where('assessment_attempts.status', AssessmentAttemptStatus::WaitingForTeacherReview->value)
            ->count();

        return [
            'waiting_for_teacher_review' => $waiting,
            'overdue' => $reviewDueAt !== null && $reviewDueAt->lte(now()) ? $waiting : 0,
        ];
    }
}
