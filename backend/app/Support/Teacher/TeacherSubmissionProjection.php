<?php

namespace App\Support\Teacher;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\AssessmentAttempt;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;

/**
 * What every review resource shows of a submission (docs/09 §21.1): its task, Topic, Group and
 * Student, the answer review counts and the derived `official` and `review_overdue` flags.
 * Applied to a TeacherSubmissionAccess query.
 */
final class TeacherSubmissionProjection
{
    /** Official: the Attempt counts for its Topic pair's Homework or Blitz (one pair per Topic). */
    private const OFFICIAL_SQL = 'assessment_attempts.official_score_eligible and exists (select 1 from topic_result_pairs'
        .' where topic_result_pairs.institution_id = assessment_attempts.institution_id'
        .' and topic_result_pairs.topic_id = assessments.topic_id'
        .' and (topic_result_pairs.homework_assessment_id = assessment_attempts.assessment_id'
        .' or topic_result_pairs.blitz_assessment_id = assessment_attempts.assessment_id))';

    /** Overdue: still waiting for review at or after the Homework review deadline (bound: server now). */
    private const OVERDUE_SQL = "coalesce(assessment_attempts.status = 'waiting_for_teacher_review'"
        .' and homework_assignments.review_due_at is not null and homework_assignments.review_due_at <= ?, false)';

    /**
     * @param  Builder<AssessmentAttempt>  $query
     * @return Builder<AssessmentAttempt>
     */
    public function apply(Builder $query, CarbonInterface $now): Builder
    {
        return $query
            ->selectRaw('('.self::OFFICIAL_SQL.') as submission_official')
            ->selectRaw('('.self::OVERDUE_SQL.') as submission_overdue', [$now])
            ->leftJoin('homework_assignments', fn ($join) => $join->on('homework_assignments.assessment_id', '=', 'assessment_attempts.assessment_id')
                ->on('homework_assignments.institution_id', '=', 'assessment_attempts.institution_id'))
            ->with([
                'assessment' => fn ($relation) => $relation->select(['id', 'institution_id', 'topic_id', 'type', 'title']),
                'assessment.topic' => fn ($relation) => $relation->select(['id', 'institution_id', 'group_id', 'title']),
                'assessment.topic.group' => fn ($relation) => $relation->select(['id', 'institution_id', 'name']),
                'assessment.homeworkAssignment' => fn ($relation) => $relation->select(['assessment_id', 'institution_id', 'review_due_at']),
                'student' => fn ($relation) => $relation->select(['id', 'institution_id', 'full_name']),
            ])
            ->withCount([
                'answers as waiting_answers_count' => fn ($answers) => $answers->where('checking_status', AttemptAnswerCheckingStatus::WaitingForTeacherReview->value),
                'answers as reviewed_answers_count' => fn ($answers) => $answers->where('checking_status', AttemptAnswerCheckingStatus::TeacherChecked->value),
            ]);
    }

    /** @param Builder<AssessmentAttempt> $query A query this projection was applied to */
    public function whereOfficial(Builder $query, bool $official): void
    {
        $query->whereRaw(($official ? '' : 'not ').'('.self::OFFICIAL_SQL.')');
    }

    /** @param Builder<AssessmentAttempt> $query A query this projection was applied to, with the same now */
    public function whereOverdue(Builder $query, CarbonInterface $now): void
    {
        $query->whereRaw(self::OVERDUE_SQL, [$now]);
    }
}
