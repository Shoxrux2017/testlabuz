<?php

namespace App\Actions\Teacher;

use App\Enums\FileCategory;
use App\Models\InstitutionSetting;
use App\Models\LearningMaterial;
use App\Models\User;
use App\Support\Files\LearningMaterialUploadPolicy;
use App\Support\Teacher\TeacherLearningMaterialAccess;
use Illuminate\Database\Eloquent\Builder;
use LogicException;

class ListTeacherLearningMaterials
{
    public function __construct(
        private readonly TeacherLearningMaterialAccess $access,
        private readonly LearningMaterialUploadPolicy $uploadPolicy,
    ) {}

    public function __invoke(User $teacher, string $topicId): TeacherLearningMaterialList
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);
        $materials = LearningMaterial::query()
            ->select(['id', 'institution_id', 'topic_id', 'file_id', 'teacher_id', 'title', 'position', 'created_at', 'updated_at'])
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->where('teacher_id', $teacher->id)
            ->whereNull('removed_at')
            ->whereHas('file', function (Builder $query) use ($teacher): void {
                $query
                    ->where('files.institution_id', $teacher->institution_id)
                    ->where('files.category', FileCategory::LearningMaterial->value)
                    ->whereNull('files.removed_at');
            })
            ->with(['file:id,institution_id,original_name,mime_type,extension,size_bytes,removed_at'])
            ->orderBy('position')
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        $setting = InstitutionSetting::query()->whereKey($teacher->institution_id)->first();

        if (! $setting instanceof InstitutionSetting) {
            throw new LogicException('The Institution upload setting is missing.');
        }

        return new TeacherLearningMaterialList(
            materials: $materials,
            maxSizeBytes: $this->uploadPolicy->maxSizeBytes($setting),
        );
    }
}
