<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentType;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class TeacherBlitzAccess
{
    public function resolveTopic(User $teacher, string $topicId): Topic
    {
        if (! Str::isUuid($topicId)) {
            throw new NotFoundHttpException;
        }

        $topic = Topic::query()
            ->select(['id', 'institution_id', 'group_id', 'teacher_id', 'status'])
            ->visibleToTeacher($teacher)
            ->whereKey($topicId)
            ->first();

        if (! $topic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        return $topic;
    }

    /** @return array{group: Group, topic: Topic} */
    public function lockTopic(User $teacher, Topic $preliminaryTopic): array
    {
        $group = $this->lockGroup($teacher, $preliminaryTopic->group_id);
        $this->lockMembership($teacher, $group);

        $topic = Topic::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('group_id', $group->id)
            ->whereKey($preliminaryTopic->id)
            ->lockForUpdate()
            ->first();

        if (! $topic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        return ['group' => $group, 'topic' => $topic];
    }

    public function resolveBlitz(User $teacher, string $blitzId): Assessment
    {
        if (! Str::isUuid($blitzId)) {
            throw new NotFoundHttpException;
        }

        $assessment = $this->visibleBlitzQuery($teacher)
            ->whereKey($blitzId)
            ->first();

        if (! $assessment instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        return $assessment;
    }

    /** @return array{group: Group, topic: Topic, assessment: Assessment, blitz: BlitzTask} */
    public function lockBlitz(User $teacher, Assessment $preliminaryAssessment): array
    {
        $preliminaryTopic = $preliminaryAssessment->topic;

        if (! $preliminaryTopic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        ['group' => $group, 'topic' => $topic] = $this->lockTopic($teacher, $preliminaryTopic);

        $assessment = Assessment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('topic_id', $topic->id)
            ->where('type', AssessmentType::Blitz->value)
            ->whereKey($preliminaryAssessment->id)
            ->lockForUpdate()
            ->first();

        if (! $assessment instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        $blitz = BlitzTask::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->lockForUpdate()
            ->first();

        if (! $blitz instanceof BlitzTask) {
            throw new NotFoundHttpException;
        }

        return compact('group', 'topic', 'assessment', 'blitz');
    }

    public function resolveGroup(User $teacher, string $groupId): Group
    {
        if (! Str::isUuid($groupId)) {
            throw new NotFoundHttpException;
        }

        $group = Group::query()
            ->select(['id', 'institution_id'])
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($groupId)
            ->whereHas('teacherMemberships', fn ($query) => $query
                ->where('institution_id', $teacher->institution_id)
                ->where('teacher_id', $teacher->id)
                ->whereNull('ended_at'))
            ->first();

        if (! $group instanceof Group) {
            throw new NotFoundHttpException;
        }

        return $group;
    }

    public function lockResultPair(User $teacher, Topic $topic, Assessment $assessment): ?TopicResultPair
    {
        return TopicResultPair::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->where('blitz_assessment_id', $assessment->id)
            ->lockForUpdate()
            ->first();
    }

    /** @return Collection<int, AssessmentAttempt> */
    public function lockAttempts(User $teacher, Assessment $assessment): Collection
    {
        return AssessmentAttempt::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('id')
            ->lockForUpdate()
            ->get(['id', 'status']);
    }

    private function lockGroup(User $teacher, string $groupId): Group
    {
        $group = Group::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($groupId)
            ->lockForUpdate()
            ->first();

        if (! $group instanceof Group) {
            throw new NotFoundHttpException;
        }

        return $group;
    }

    private function lockMembership(User $teacher, Group $group): GroupTeacherMembership
    {
        $membership = GroupTeacherMembership::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('group_id', $group->id)
            ->where('teacher_id', $teacher->id)
            ->whereNull('ended_at')
            ->lockForUpdate()
            ->first();

        if (! $membership instanceof GroupTeacherMembership) {
            throw new NotFoundHttpException;
        }

        return $membership;
    }

    public function visibleBlitzQuery(User $teacher): Builder
    {
        return Assessment::query()
            ->select([
                'id',
                'institution_id',
                'topic_id',
                'teacher_id',
                'type',
                'title',
                'description',
                'student_instructions',
                'assignment_mode',
                'total_possible_points',
                'created_at',
                'updated_at',
            ])
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('type', AssessmentType::Blitz->value)
            ->whereHas('blitzTask', fn ($query) => $query->where('institution_id', $teacher->institution_id))
            ->whereHas('topic', fn ($query) => $query->visibleToTeacher($teacher))
            ->with('topic:id,institution_id,group_id,teacher_id,status');
    }
}
