<?php

namespace App\Actions\Files;

use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use App\Support\Files\ProtectedFileDownload;
use App\Support\Files\ProtectedLearningMaterialAccess;
use Illuminate\Support\Facades\DB;
use Throwable;

class DownloadLearningMaterialFile
{
    public function __construct(
        private readonly ProtectedLearningMaterialAccess $access,
        private readonly PrivateFileStorage $storage,
    ) {}

    public function __invoke(User $actor, string $fileId): ProtectedFileDownload
    {
        $target = $this->access->resolve($actor, $fileId);
        $openedStream = null;

        try {
            return DB::transaction(function () use ($actor, $target, &$openedStream): ProtectedFileDownload {
                $file = $this->access->lock($actor, $target);
                $openedStream = $this->storage->openReadStream(
                    $file->storage_disk,
                    $file->storage_key,
                    $file->id,
                );

                return new ProtectedFileDownload(
                    stream: $openedStream,
                    mimeType: $file->mime_type,
                    displayFilename: $file->original_name,
                    canonicalExtension: $file->extension->value,
                );
            });
        } catch (Throwable $exception) {
            if (is_resource($openedStream)) {
                fclose($openedStream);
            }

            throw $exception;
        }
    }
}
