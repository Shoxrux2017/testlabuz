<?php

namespace App\Actions\Teacher;

use App\Models\LearningMaterial;
use Illuminate\Database\Eloquent\Collection;

final readonly class TeacherLearningMaterialList
{
    /** @param Collection<int, LearningMaterial> $materials */
    public function __construct(
        public Collection $materials,
        public int $maxSizeBytes,
    ) {}
}
