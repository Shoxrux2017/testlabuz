<?php

namespace App\Http\Resources\Student;

use App\Models\File;
use App\Models\LearningMaterial;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin LearningMaterial */
class StudentLearningMaterialResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $file = $this->relationLoaded('file') ? $this->getRelation('file') : null;

        if (! $file instanceof File) {
            throw new LogicException('Student Learning Material resources require a preloaded File projection.');
        }

        return [
            'id' => $this->id,
            'title' => $this->title,
            'file' => [
                'id' => $file->id,
                'original_name' => $file->original_name,
                'extension' => $file->extension->value,
                'size_bytes' => $file->size_bytes,
            ],
        ];
    }
}
