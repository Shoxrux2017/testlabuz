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

        try {
            $replacement = DB::transaction(function () use ($teacher, $preliminaryMaterial, $metadata, $diskName, $storageKey): array {
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

                return [
                    'material' => $material,
                    'old_disk_name' => $oldDiskName,
                    'old_storage_key' => $oldStorageKey,
                ];
            });
        } catch (Throwable $exception) {
            $this->storage->deleteBestEffort($diskName, $storageKey, 'replace_compensation');

            throw $exception;
        }

        /** @var LearningMaterial $material */
        $material = $replacement['material'];
        $file = $material->getRelation('file');
        $this->storage->deleteBestEffort(
            $replacement['old_disk_name'],
            $replacement['old_storage_key'],
            'replace_old_blob_cleanup',
            $file instanceof File ? $file->id : null,
        );

        return $material;
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
