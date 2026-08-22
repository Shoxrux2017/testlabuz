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
        DB::transaction(function () use ($teacher, $preliminaryMaterial): void {
            $locked = $this->access->lockEditableMaterial($teacher, $preliminaryMaterial);
            $removedAt = now();
            $material = $locked['material'];
            /** @var File $file */
            $file = $locked['file'];

            $material->removed_at = $removedAt;
            $material->save();
            $file->removed_at = $removedAt;
            $file->save();

            DB::afterCommit(function () use ($file): void {
                $this->storage->deleteBestEffort(
                    $file->storage_disk,
                    $file->storage_key,
                    'remove_blob_cleanup',
                    $file->id,
                );
            });
        });
    }
}
