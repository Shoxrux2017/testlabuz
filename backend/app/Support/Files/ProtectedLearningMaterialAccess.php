<?php

namespace App\Support\Files;

use App\Enums\FileCategory;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use stdClass;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ProtectedLearningMaterialAccess
{
    /** @return array{file_id: string, material_id: string, topic_id: string, group_id: string} */
    public function resolve(User $actor, string $fileId): array
    {
        if (! Str::isUuid($fileId)) {
            throw new NotFoundHttpException;
        }

        $query = DB::table('learning_materials')
            ->join('files', 'files.id', '=', 'learning_materials.file_id')
            ->join('topics', 'topics.id', '=', 'learning_materials.topic_id')
            ->where('learning_materials.institution_id', $actor->institution_id)
            ->whereNull('learning_materials.removed_at')
            ->where('files.institution_id', $actor->institution_id)
            ->where('files.category', FileCategory::LearningMaterial->value)
            ->whereNull('files.removed_at')
            ->where('files.id', $fileId)
            ->where('topics.institution_id', $actor->institution_id)
            ->select([
                'files.id as file_id',
                'learning_materials.id as material_id',
                'topics.id as topic_id',
                'topics.group_id as group_id',
            ]);

        match ($actor->role) {
            UserRole::Teacher => $this->scopeTeacher($query, $actor),
            UserRole::Student => $this->scopeStudent($query, $actor),
            default => throw new NotFoundHttpException,
        };

        $target = $query->first();

        if (! $target instanceof stdClass) {
            throw new NotFoundHttpException;
        }

        return [
            'file_id' => (string) $target->file_id,
            'material_id' => (string) $target->material_id,
            'topic_id' => (string) $target->topic_id,
            'group_id' => (string) $target->group_id,
        ];
    }

    /**
     * @param  array{file_id: string, material_id: string, topic_id: string, group_id: string}  $target
     */
    public function lock(User $actor, array $target): File
    {
        $group = Group::query()
            ->select('id')
            ->where('institution_id', $actor->institution_id)
            ->whereKey($target['group_id'])
            ->lockForUpdate()
            ->first();

        if (! $group instanceof Group) {
            throw new NotFoundHttpException;
        }

        $this->lockMembership($actor, $group);

        $topicQuery = Topic::query()
            ->select('id')
            ->where('institution_id', $actor->institution_id)
            ->where('group_id', $group->id)
            ->whereKey($target['topic_id']);

        if ($actor->role === UserRole::Teacher) {
            $topicQuery->where('teacher_id', $actor->id);
        } elseif ($actor->role === UserRole::Student) {
            $topicQuery->whereIn('status', [
                TopicStatus::Active->value,
                TopicStatus::Closed->value,
                TopicStatus::Archived->value,
            ]);
        } else {
            throw new NotFoundHttpException;
        }

        $topic = $topicQuery->lockForUpdate()->first();

        if (! $topic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        $materialQuery = LearningMaterial::query()
            ->select(['id', 'file_id'])
            ->where('institution_id', $actor->institution_id)
            ->where('topic_id', $topic->id)
            ->where('file_id', $target['file_id'])
            ->whereKey($target['material_id'])
            ->whereNull('removed_at');

        if ($actor->role === UserRole::Teacher) {
            $materialQuery->where('teacher_id', $actor->id);
        }

        $material = $materialQuery->lockForUpdate()->first();

        if (! $material instanceof LearningMaterial) {
            throw new NotFoundHttpException;
        }

        $file = File::query()
            ->select(['id', 'storage_disk', 'storage_key', 'mime_type', 'original_name', 'extension'])
            ->where('institution_id', $actor->institution_id)
            ->where('category', FileCategory::LearningMaterial->value)
            ->whereKey($target['file_id'])
            ->whereNull('removed_at')
            ->lockForUpdate()
            ->first();

        if (! $file instanceof File || $material->file_id !== $file->id) {
            throw new NotFoundHttpException;
        }

        return $file;
    }

    private function scopeTeacher(Builder $query, User $teacher): void
    {
        $query
            ->where('learning_materials.teacher_id', $teacher->id)
            ->where('topics.teacher_id', $teacher->id)
            ->whereExists(function (Builder $query) use ($teacher): void {
                $query
                    ->selectRaw('1')
                    ->from('group_teacher_memberships')
                    ->whereColumn('group_teacher_memberships.group_id', 'topics.group_id')
                    ->where('group_teacher_memberships.institution_id', $teacher->institution_id)
                    ->where('group_teacher_memberships.teacher_id', $teacher->id)
                    ->whereNull('group_teacher_memberships.ended_at');
            });
    }

    private function scopeStudent(Builder $query, User $student): void
    {
        $query
            ->whereIn('topics.status', [
                TopicStatus::Active->value,
                TopicStatus::Closed->value,
                TopicStatus::Archived->value,
            ])
            ->whereExists(function (Builder $query) use ($student): void {
                $query
                    ->selectRaw('1')
                    ->from('group_student_memberships')
                    ->whereColumn('group_student_memberships.group_id', 'topics.group_id')
                    ->where('group_student_memberships.institution_id', $student->institution_id)
                    ->where('group_student_memberships.student_id', $student->id)
                    ->whereNull('group_student_memberships.ended_at');
            });
    }

    private function lockMembership(User $actor, Group $group): void
    {
        $membership = match ($actor->role) {
            UserRole::Teacher => GroupTeacherMembership::query()
                ->select('id')
                ->where('institution_id', $actor->institution_id)
                ->where('group_id', $group->id)
                ->where('teacher_id', $actor->id)
                ->whereNull('ended_at')
                ->lockForUpdate()
                ->first(),
            UserRole::Student => GroupStudentMembership::query()
                ->select('id')
                ->where('institution_id', $actor->institution_id)
                ->where('group_id', $group->id)
                ->where('student_id', $actor->id)
                ->whereNull('ended_at')
                ->lockForUpdate()
                ->first(),
            default => null,
        };

        if (! $membership instanceof GroupTeacherMembership && ! $membership instanceof GroupStudentMembership) {
            throw new NotFoundHttpException;
        }
    }
}
