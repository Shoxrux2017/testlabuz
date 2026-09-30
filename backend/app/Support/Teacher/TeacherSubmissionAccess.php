<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\Topic;
use App\Models\User;
use Closure;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * The review access rule (S09-DOC-001 §10.1): a terminal Attempt of a Homework or Blitz in a
 * Topic visible to the Teacher, taken by a persisted recipient of that task. Topic and task
 * status never restrict review.
 */
final class TeacherSubmissionAccess
{
    public const TERMINAL = [
        AssessmentAttemptStatus::Submitted,
        AssessmentAttemptStatus::TimedOutFinalized,
        AssessmentAttemptStatus::WaitingForTeacherReview,
        AssessmentAttemptStatus::Checked,
    ];

    /** @return Builder<AssessmentAttempt> Attempts with their Assessment joined as `assessments` */
    public function query(User $teacher): Builder
    {
        return AssessmentAttempt::query()
            ->select('assessment_attempts.*')
            ->join('assessments', fn ($join) => $join->on('assessments.id', '=', 'assessment_attempts.assessment_id')
                ->on('assessments.institution_id', '=', 'assessment_attempts.institution_id'))
            // The foreign key only ties the recipient to the Institution: require its task and Student too.
            ->join('assessment_students as recipients', fn ($join) => $join->on('recipients.id', '=', 'assessment_attempts.assessment_student_id')
                ->on('recipients.institution_id', '=', 'assessment_attempts.institution_id')
                ->on('recipients.assessment_id', '=', 'assessment_attempts.assessment_id')
                ->on('recipients.student_id', '=', 'assessment_attempts.student_id'))
            ->where('assessment_attempts.institution_id', $teacher->institution_id)
            ->whereIn('assessment_attempts.status', array_map(fn (AssessmentAttemptStatus $status): string => $status->value, self::TERMINAL))
            ->whereIn('assessments.topic_id', Topic::query()->select('topics.id')->visibleToTeacher($teacher));
    }

    /** @param (Closure(Builder<AssessmentAttempt>): mixed)|null $scope Adds the caller's projection */
    public function resolve(User $teacher, string $submissionId, ?Closure $scope = null): AssessmentAttempt
    {
        if (! Str::isUuid($submissionId)) {
            throw new NotFoundHttpException;
        }

        $query = $this->query($teacher)->where('assessment_attempts.id', $submissionId);

        if ($scope !== null) {
            $scope($query);
        }

        return $query->first() ?? throw new NotFoundHttpException;
    }
}
