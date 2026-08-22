<?php

namespace App\Actions\Teacher;

use App\Models\LearningMaterial;
use App\Models\User;
use App\Support\Teacher\TeacherLearningMaterialAccess;
use Illuminate\Support\Facades\DB;

class UpdateTeacherLearningMaterial
{
    public function __construct(private readonly TeacherLearningMaterialAccess $access) {}

    public function __invoke(User $teacher, string $materialId, ?string $title): LearningMaterial
    {
        $preliminaryMaterial = $this->access->resolveMaterial($teacher, $materialId);

        return DB::transaction(function () use ($teacher, $preliminaryMaterial, $title): LearningMaterial {
            $locked = $this->access->lockEditableMaterial($teacher, $preliminaryMaterial);
            $material = $locked['material'];

            if ($material->title !== $title) {
                $material->title = $title;
                $material->save();
            }

            return $material;
        });
    }
}
