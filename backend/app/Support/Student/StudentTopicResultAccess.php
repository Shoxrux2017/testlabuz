<?php

namespace App\Support\Student;

use App\Enums\TopicStatus;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * The Topics whose result a Student may read (docs/09 §29.5): an active, closed or archived Topic of
 * the Student's Institution whose Group the Student currently belongs to, or whose official Homework or
 * Blitz holds the Student as a persisted recipient (a cohort member keeps access after leaving the Group).
 */
final class StudentTopicResultAccess
{
    public function resolve(User $student, string $topicId): Topic
    {
        if (! Str::isUuid($topicId)) {
            throw new NotFoundHttpException;
        }

        return Topic::query()
            ->select(['id', 'institution_id'])
            ->where('topics.institution_id', $student->institution_id)
            ->whereKey(strtolower($topicId))
            ->whereIn('topics.status', [TopicStatus::Active->value, TopicStatus::Closed->value, TopicStatus::Archived->value])
            ->where(fn ($query) => $query
                ->whereExists(fn (Builder $membership) => $membership
                    ->selectRaw('1')
                    ->from('group_student_memberships')
                    ->whereColumn('group_student_memberships.group_id', 'topics.group_id')
                    ->where('group_student_memberships.institution_id', $student->institution_id)
                    ->where('group_student_memberships.student_id', $student->id)
                    ->whereNull('group_student_memberships.ended_at'))
                ->orWhereExists(fn (Builder $pair) => $pair
                    ->selectRaw('1')
                    ->from('topic_result_pairs')
                    ->whereColumn('topic_result_pairs.topic_id', 'topics.id')
                    ->where('topic_result_pairs.institution_id', $student->institution_id)
                    ->whereExists(fn (Builder $recipient) => $recipient
                        ->selectRaw('1')
                        ->from('assessment_students')
                        ->where('assessment_students.institution_id', $student->institution_id)
                        ->where('assessment_students.student_id', $student->id)
                        ->where(fn (Builder $task) => $task
                            ->whereColumn('assessment_students.assessment_id', 'topic_result_pairs.homework_assessment_id')
                            ->orWhereColumn('assessment_students.assessment_id', 'topic_result_pairs.blitz_assessment_id')))))
            ->first() ?? throw new NotFoundHttpException;
    }
}
