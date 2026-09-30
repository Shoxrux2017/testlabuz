<?php

namespace App\Actions\Files;

use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use App\Support\Files\ProtectedFileDownload;
use App\Support\Files\TeacherSubmissionFileAccess;
use Illuminate\Support\Facades\DB;
use Throwable;

/** A Teacher's download of a Student's submitted answer file (docs/09 §22.2). */
class DownloadReviewedSubmissionFile
{
    public function __construct(
        private readonly TeacherSubmissionFileAccess $access,
        private readonly PrivateFileStorage $storage,
    ) {}

    public function __invoke(User $teacher, string $fileId): ProtectedFileDownload
    {
        $target = $this->access->resolve($teacher, $fileId);
        $openedStream = null;

        try {
            return DB::transaction(function () use ($teacher, $target, &$openedStream): ProtectedFileDownload {
                $file = $this->access->lock($teacher, $target);
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
