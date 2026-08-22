<?php

namespace App\Http\Resources\Teacher;

use App\Support\Files\LearningMaterialUploadPolicy;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

class TeacherLearningMaterialCollection extends ResourceCollection
{
    public $collects = TeacherLearningMaterialResource::class;

    public function __construct($resource, private readonly int $maxSizeBytes)
    {
        parent::__construct($resource);
    }

    /** @return array<string, mixed> */
    public function with(Request $request): array
    {
        return [
            'meta' => [
                'upload' => [
                    'max_size_bytes' => $this->maxSizeBytes,
                    'platform_max_size_bytes' => LearningMaterialUploadPolicy::PLATFORM_MAX_SIZE_BYTES,
                    'allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx'],
                ],
            ],
        ];
    }
}
