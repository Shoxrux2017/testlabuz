<?php

namespace App\Actions\Teacher;

use App\Enums\FileCategory;
use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\File;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class ActivateTeacherTopic
{
    public function __construct(private readonly TeacherTopicLifecycleAccess $access) {}

    public function __invoke(User $teacher, string $topicId): Topic
    {
        $preliminaryTopic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $preliminaryTopic): Topic {
            $locked = $this->access->lockTopic($teacher, $preliminaryTopic);
            $group = $locked['group'];
            $topic = $locked['topic'];

            if ($group->status !== GroupStatus::Active) {
                throw new TopicNotEditableException;
            }

            if ($topic->status === TopicStatus::Active) {
                return $topic;
            }

            if ($topic->status !== TopicStatus::Draft
                || ! $this->hasValidRequiredMetadata($topic)) {
                throw new TopicNotEditableException;
            }

            $this->lockValidCurrentMaterial($teacher, $topic);

            $transitionedAt = now();
            $topic->status = TopicStatus::Active;
            $topic->activated_at = $transitionedAt;
            $topic->closed_at = null;
            $topic->archived_at = null;
            $topic->updated_at = $transitionedAt;
            $topic->save();

            return $topic;
        });
    }

    private function hasValidRequiredMetadata(Topic $topic): bool
    {
        return $this->isTrimmedStringWithinLimit($topic->title, 255)
            && $this->isTrimmedStringWithinLimit($topic->subject, 160)
            && is_string($topic->student_instructions)
            && trim($topic->student_instructions) !== '';
    }

    private function isTrimmedStringWithinLimit(mixed $value, int $limit): bool
    {
        return is_string($value)
            && trim($value) !== ''
            && mb_strlen(trim($value)) <= $limit;
    }

    private function lockValidCurrentMaterial(User $teacher, Topic $topic): void
    {
        $material = LearningMaterial::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('topic_id', $topic->id)
            ->whereNull('removed_at')
            ->whereHas('file', function (Builder $query) use ($teacher): void {
                $query
                    ->where('files.institution_id', $teacher->institution_id)
                    ->where('files.category', FileCategory::LearningMaterial->value)
                    ->whereNull('files.removed_at');
            })
            ->orderBy('position')
            ->orderBy('created_at')
            ->orderBy('id')
            ->lockForUpdate()
            ->first();

        if (! $material instanceof LearningMaterial) {
            throw new TopicNotEditableException;
        }

        $file = File::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('category', FileCategory::LearningMaterial->value)
            ->whereKey($material->file_id)
            ->whereNull('removed_at')
            ->lockForUpdate()
            ->first();

        if (! $file instanceof File
            || $material->institution_id !== $teacher->institution_id
            || $material->teacher_id !== $teacher->id
            || $material->topic_id !== $topic->id
            || $material->removed_at !== null) {
            throw new TopicNotEditableException;
        }
    }
}
