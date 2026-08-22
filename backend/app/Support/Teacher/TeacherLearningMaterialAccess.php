<?php

namespace App\Support\Teacher;

use App\Enums\FileCategory;
use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class TeacherLearningMaterialAccess
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

    public function resolveMaterial(User $teacher, string $materialId): LearningMaterial
    {
        if (! Str::isUuid($materialId)) {
            throw new NotFoundHttpException;
        }

        $material = LearningMaterial::query()
            ->where('learning_materials.institution_id', $teacher->institution_id)
            ->where('learning_materials.teacher_id', $teacher->id)
            ->whereKey($materialId)
            ->whereNull('learning_materials.removed_at')
            ->whereHas('topic', fn (Builder $query): Builder => $query->visibleToTeacher($teacher))
            ->whereHas('file', function (Builder $query) use ($teacher): void {
                $query
                    ->where('files.institution_id', $teacher->institution_id)
                    ->where('files.category', FileCategory::LearningMaterial->value)
                    ->whereNull('files.removed_at');
            })
            ->with([
                'topic:id,institution_id,group_id,teacher_id,status',
                'file:id,institution_id,uploaded_by_user_id,category,original_name,storage_disk,storage_key,mime_type,extension,size_bytes,checksum_sha256,removed_at,created_at,updated_at',
            ])
            ->first();

        if (! $material instanceof LearningMaterial) {
            throw new NotFoundHttpException;
        }

        return $material;
    }

    public function lockEditableTopic(User $teacher, Topic $preliminaryTopic): Topic
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

        $this->ensureEditable($group, $topic);

        return $topic;
    }

    /** @return array{material: LearningMaterial, file: File, topic: Topic} */
    public function lockEditableMaterial(User $teacher, LearningMaterial $preliminaryMaterial): array
    {
        $preliminaryTopic = $preliminaryMaterial->getRelation('topic');
        $preliminaryFile = $preliminaryMaterial->getRelation('file');

        if (! $preliminaryTopic instanceof Topic || ! $preliminaryFile instanceof File) {
            throw new LogicException('Teacher material resolution requires Topic and File projections.');
        }

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

        $material = LearningMaterial::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('topic_id', $preliminaryTopic->id)
            ->whereKey($preliminaryMaterial->id)
            ->whereNull('removed_at')
            ->lockForUpdate()
            ->first();

        $file = File::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('category', FileCategory::LearningMaterial->value)
            ->whereKey($preliminaryFile->id)
            ->whereNull('removed_at')
            ->lockForUpdate()
            ->first();

        if (! $topic instanceof Topic || ! $material instanceof LearningMaterial || ! $file instanceof File
            || $material->file_id !== $file->id) {
            throw new NotFoundHttpException;
        }

        $this->ensureEditable($group, $topic);
        $material->setRelation('file', $file);
        $material->setRelation('topic', $topic);

        return ['material' => $material, 'file' => $file, 'topic' => $topic];
    }

    private function ensureEditable(Group $group, Topic $topic): void
    {
        if ($group->status !== GroupStatus::Active
            || ! in_array($topic->status, [TopicStatus::Draft, TopicStatus::Active], true)) {
            throw new TopicNotEditableException;
        }
    }
}
