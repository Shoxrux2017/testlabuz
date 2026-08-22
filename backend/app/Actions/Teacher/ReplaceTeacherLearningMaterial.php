<?php

namespace App\Actions\Teacher;

use App\Models\File;
use App\Models\InstitutionSetting;
use App\Models\LearningMaterial;
use App\Models\User;
use App\Support\Files\LearningMaterialFileInspector;
use App\Support\Files\LearningMaterialUploadPolicy;
use App\Support\Files\PrivateFileStorage;
use App\Support\Teacher\TeacherLearningMaterialAccess;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use Throwable;

class ReplaceTeacherLearningMaterial
{
    public function __construct(
        private readonly TeacherLearningMaterialAccess $access,
        private readonly LearningMaterialFileInspector $fileInspector,
        private readonly LearningMaterialUploadPolicy $uploadPolicy,
        private readonly PrivateFileStorage $storage,
    ) {}

    public function __invoke(User $teacher, string $materialId, UploadedFile $upload): LearningMaterial
    {
        $preliminaryMaterial = $this->access->resolveMaterial($teacher, $materialId);
        $metadata = $this->fileInspector->inspect($upload);
        $earlySetting = $this->institutionSetting($teacher);
        $this->uploadPolicy->ensureWithinLimit($metadata->sizeBytes, $this->uploadPolicy->maxSizeBytes($earlySetting));

        $storageKey = $this->storageKey(
            $teacher->institution_id,
            $preliminaryMaterial->topic_id,
            $metadata->extension->value,
        );
        $diskName = $this->storage->store($upload, $storageKey);
        $newBlobCleanupAttempted = false;
        $cleanupNewBlob = function () use ($diskName, $storageKey, &$newBlobCleanupAttempted): void {
            if ($newBlobCleanupAttempted) {
                return;
            }

            $newBlobCleanupAttempted = true;
            $this->storage->deleteBestEffort($diskName, $storageKey, 'replace_compensation');
        };

        try {
            return DB::transaction(function () use ($teacher, $preliminaryMaterial, $metadata, $diskName, $storageKey, $cleanupNewBlob): LearningMaterial {
                DB::afterRollBack($cleanupNewBlob);

                $locked = $this->access->lockEditableMaterial($teacher, $preliminaryMaterial);
                $setting = InstitutionSetting::query()
                    ->whereKey($teacher->institution_id)
                    ->lockForUpdate()
                    ->first();

                if (! $setting instanceof InstitutionSetting) {
                    throw new LogicException('The Institution upload setting is missing.');
                }

                $this->uploadPolicy->ensureWithinLimit($metadata->sizeBytes, $this->uploadPolicy->maxSizeBytes($setting));

                /** @var LearningMaterial $material */
                $material = $locked['material'];
                /** @var File $file */
                $file = $locked['file'];
                $oldDiskName = $file->storage_disk;
                $oldStorageKey = $file->storage_key;

                $file->fill([
                    'original_name' => $metadata->originalName,
                    'storage_disk' => $diskName,
                    'storage_key' => $storageKey,
                    'mime_type' => $metadata->mimeType,
                    'extension' => $metadata->extension,
                    'size_bytes' => $metadata->sizeBytes,
                    'checksum_sha256' => $metadata->checksumSha256,
                ]);
                $file->save();
                $material->touch();
                $material->setRelation('file', $file);

                DB::afterCommit(function () use ($oldDiskName, $oldStorageKey, $file): void {
                    $this->storage->deleteBestEffort(
                        $oldDiskName,
                        $oldStorageKey,
                        'replace_old_blob_cleanup',
                        $file->id,
                    );
                });

                return $material;
            });
        } catch (Throwable $exception) {
            $cleanupNewBlob();

            throw $exception;
        }
    }

    private function institutionSetting(User $teacher): InstitutionSetting
    {
        $setting = InstitutionSetting::query()->whereKey($teacher->institution_id)->first();

        if (! $setting instanceof InstitutionSetting) {
            throw new LogicException('The Institution upload setting is missing.');
        }

        return $setting;
    }

    private function storageKey(string $institutionId, string $topicId, string $extension): string
    {
        return "learning-materials/{$institutionId}/{$topicId}/".Str::uuid().".{$extension}";
    }
}
