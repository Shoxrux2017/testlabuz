<?php

namespace App\Support\Files;

use App\Enums\FileExtension;

final readonly class LearningMaterialFileMetadata
{
    public function __construct(
        public string $originalName,
        public FileExtension $extension,
        public string $mimeType,
        public int $sizeBytes,
        public string $checksumSha256,
    ) {}
}
