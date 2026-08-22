<?php

namespace App\Actions\Teacher;

use App\Enums\FileCategory;
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

class UploadTeacherLearningMaterial
{
    public function __construct(
        private readonly TeacherLearningMaterialAccess $access,
        private readonly LearningMaterialFileInspector $fileInspector,
        private readonly LearningMaterialUploadPolicy $uploadPolicy,
        private readonly PrivateFileStorage $storage,
    ) {}

    public function __invoke(User $teacher, string $topicId, UploadedFile $upload, ?string $title): LearningMaterial
    {
        $preliminaryTopic = $this->access->resolveTopic($teacher, $topicId);
        $metadata = $this->fileInspector->inspect($upload);
        $earlySetting = $this->institutionSetting($teacher);
        $this->uploadPolicy->ensureWithinLimit($metadata->sizeBytes, $this->uploadPolicy->maxSizeBytes($earlySetting));

        $storageKey = $this->storageKey($teacher->institution_id, $preliminaryTopic->id, $metadata->extension->value);
        $diskName = $this->storage->store($upload, $storageKey);
        $newBlobCleanupAttempted = false;
        $cleanupNewBlob = function () use ($diskName, $storageKey, &$newBlobCleanupAttempted): void {
            if ($newBlobCleanupAttempted) {
                return;
            }

            $newBlobCleanupAttempted = true;
            $this->storage->deleteBestEffort($diskName, $storageKey, 'upload_compensation');
        };

        try {
            return DB::transaction(function () use ($teacher, $preliminaryTopic, $metadata, $diskName, $storageKey, $title, $cleanupNewBlob): LearningMaterial {
                DB::afterRollBack($cleanupNewBlob);

                $topic = $this->access->lockEditableTopic($teacher, $preliminaryTopic);
                $setting = InstitutionSetting::query()
                    ->whereKey($teacher->institution_id)
                    ->lockForUpdate()
                    ->first();

                if (! $setting instanceof InstitutionSetting) {
                    throw new LogicException('The Institution upload setting is missing.');
                }

                $this->uploadPolicy->ensureWithinLimit($metadata->sizeBytes, $this->uploadPolicy->maxSizeBytes($setting));

                $position = ((int) LearningMaterial::query()
                    ->where('institution_id', $teacher->institution_id)
                    ->where('topic_id', $topic->id)
                    ->whereNull('removed_at')
                    ->max('position'));

                if (LearningMaterial::query()
                    ->where('institution_id', $teacher->institution_id)
                    ->where('topic_id', $topic->id)
                    ->whereNull('removed_at')
                    ->exists()) {
                    $position++;
                }

                $file = File::query()->create([
                    'institution_id' => $teacher->institution_id,
                    'uploaded_by_user_id' => $teacher->id,
                    'category' => FileCategory::LearningMaterial,
                    'original_name' => $metadata->originalName,
                    'storage_disk' => $diskName,
                    'storage_key' => $storageKey,
                    'mime_type' => $metadata->mimeType,
                    'extension' => $metadata->extension,
                    'size_bytes' => $metadata->sizeBytes,
                    'checksum_sha256' => $metadata->checksumSha256,
                    'removed_at' => null,
                ]);

                $material = LearningMaterial::query()->create([
                    'institution_id' => $teacher->institution_id,
                    'topic_id' => $topic->id,
                    'file_id' => $file->id,
                    'teacher_id' => $teacher->id,
                    'title' => $title,
                    'position' => $position,
                    'removed_at' => null,
                ]);
                $material->setRelation('file', $file);

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
