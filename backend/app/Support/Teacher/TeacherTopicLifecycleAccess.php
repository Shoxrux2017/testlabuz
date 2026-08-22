<?php

namespace App\Support\Teacher;

use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class TeacherTopicLifecycleAccess
{
    public function resolveTopic(User $teacher, string $topicId): Topic
    {
        if (! Str::isUuid($topicId)) {
            throw new NotFoundHttpException;
        }

        $topic = Topic::query()
            ->select(['id', 'institution_id', 'group_id', 'teacher_id'])
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
        $group = Group::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($preliminaryTopic->group_id)
            ->lockForUpdate()
            ->first();

        if (! $group instanceof Group) {
            throw new NotFoundHttpException;
        }

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

        $topic->setRelation('group', $group);

        return ['group' => $group, 'topic' => $topic];
    }
}
