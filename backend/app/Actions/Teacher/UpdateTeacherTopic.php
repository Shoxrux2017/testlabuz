<?php

namespace App\Actions\Teacher;

use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\User;
use App\Support\Teacher\InstitutionLessonAt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class UpdateTeacherTopic
{
    public function __construct(private readonly InstitutionLessonAt $institutionLessonAt) {}

    /** @param array<string, string|null> $attributes */
    public function __invoke(User $teacher, string $topic, array $attributes): Topic
    {
        $groupId = $this->readableTopicGroupId($teacher, $topic);

        return DB::transaction(function () use ($teacher, $topic, $groupId, $attributes): Topic {
            $group = Group::query()
                ->where('institution_id', $teacher->institution_id)
                ->whereKey($groupId)
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

            $lockedTopic = Topic::query()
                ->where('institution_id', $teacher->institution_id)
                ->where('teacher_id', $teacher->id)
                ->where('group_id', $group->id)
                ->whereKey($topic)
                ->lockForUpdate()
                ->first();

            if (! $lockedTopic instanceof Topic) {
                throw new NotFoundHttpException;
            }

            if ($group->status !== GroupStatus::Active
                || ! in_array($lockedTopic->status, [TopicStatus::Draft, TopicStatus::Active], true)) {
                throw new TopicNotEditableException;
            }

            foreach ($attributes as $attribute => $value) {
                $lockedTopic->setAttribute(
                    $attribute,
                    $attribute === 'lesson_at' && is_string($value)
                        ? $this->institutionLessonAt->parse($teacher, $value)
                        : $value,
                );
            }

            if ($lockedTopic->isDirty()) {
                $lockedTopic->save();
            }

            $lockedTopic->setRelation('group', $group);

            return $lockedTopic;
        });
    }

    private function readableTopicGroupId(User $teacher, string $topic): string
    {
        if (! Str::isUuid($topic)) {
            throw new NotFoundHttpException;
        }

        $groupId = Topic::query()
            ->visibleToTeacher($teacher)
            ->whereKey($topic)
            ->value('group_id');

        if (! is_string($groupId)) {
            throw new NotFoundHttpException;
        }

        return $groupId;
    }
}
