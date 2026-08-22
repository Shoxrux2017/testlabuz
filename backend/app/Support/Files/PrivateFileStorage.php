<?php

namespace App\Support\Files;

use App\Exceptions\Files\FileUploadFailedException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use LogicException;
use Throwable;

class PrivateFileStorage
{
    public function configuredDiskName(): string
    {
        $diskName = config('filesystems.private_files_disk');
        $disks = config('filesystems.disks');

        if (! is_string($diskName) || $diskName === '' || ! is_array($disks) || ! array_key_exists($diskName, $disks)) {
            throw new LogicException('The configured private files disk does not exist.');
        }

        $diskConfiguration = $disks[$diskName];

        if (! is_array($diskConfiguration) || ($diskConfiguration['visibility'] ?? null) === 'public') {
            throw new LogicException('The configured private files disk must not be public.');
        }

        return $diskName;
    }

    public function store(UploadedFile $upload, string $storageKey): string
    {
        $diskName = $this->configuredDiskName();
        $stream = null;

        try {
            $stream = fopen($upload->getPathname(), 'rb');

            if (! is_resource($stream) || ! Storage::disk($diskName)->put($storageKey, $stream)) {
                throw new FileUploadFailedException;
            }
        } catch (FileUploadFailedException $exception) {
            throw $exception;
        } catch (Throwable $exception) {
            throw new FileUploadFailedException(previous: $exception);
        } finally {
            if (is_resource($stream)) {
                fclose($stream);
            }
        }

        return $diskName;
    }

    public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
    {
        try {
            $deleted = Storage::disk($diskName)->delete($storageKey);
        } catch (Throwable) {
            $deleted = false;
        }

        if (! $deleted) {
            Log::warning('Private file cleanup failed.', array_filter([
                'operation' => $operation,
                'file_id' => $fileId,
            ]));
        }

        return $deleted;
    }
}
