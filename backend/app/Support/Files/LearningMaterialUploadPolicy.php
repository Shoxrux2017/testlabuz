<?php

namespace App\Support\Files;

use App\Exceptions\Files\FileTooLargeException;
use App\Models\InstitutionSetting;

final class LearningMaterialUploadPolicy
{
    public const BYTES_PER_MIB = 1_048_576;

    public const PLATFORM_MAX_SIZE_BYTES = 26_214_400;

    public function maxSizeBytes(InstitutionSetting $setting): int
    {
        return min(
            self::PLATFORM_MAX_SIZE_BYTES,
            $setting->learning_material_max_mb * self::BYTES_PER_MIB,
        );
    }

    public function ensureWithinLimit(int $sizeBytes, int $maxSizeBytes): void
    {
        if ($sizeBytes > $maxSizeBytes) {
            throw new FileTooLargeException($maxSizeBytes);
        }
    }
}
