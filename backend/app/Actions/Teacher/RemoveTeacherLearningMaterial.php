<?php

namespace App\Actions\Teacher;

use App\Models\File;
use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use App\Support\Teacher\TeacherLearningMaterialAccess;
use Illuminate\Support\Facades\DB;

class RemoveTeacherLearningMaterial
{
    public function __construct(
        private readonly TeacherLearningMaterialAccess $access,
        private readonly PrivateFileStorage $storage,
    ) {}

    public function __invoke(User $teacher, string $materialId): void
    {
        $preliminaryMaterial = $this->access->resolveMaterial($teacher, $materialId);
        $removed = DB::transaction(function () use ($teacher, $preliminaryMaterial): array {
            $locked = $this->access->lockEditableMaterial($teacher, $preliminaryMaterial);
            $removedAt = now();
            $material = $locked['material'];
            /** @var File $file */
            $file = $locked['file'];

            $material->removed_at = $removedAt;
            $material->save();
            $file->removed_at = $removedAt;
            $file->save();

            return [
                'disk_name' => $file->storage_disk,
                'storage_key' => $file->storage_key,
                'file_id' => $file->id,
            ];
        });

        $this->storage->deleteBestEffort(
            $removed['disk_name'],
            $removed['storage_key'],
            'remove_blob_cleanup',
            $removed['file_id'],
        );
    }
}
