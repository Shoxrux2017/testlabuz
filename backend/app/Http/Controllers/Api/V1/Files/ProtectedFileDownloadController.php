<?php

namespace App\Http\Controllers\Api\V1\Files;

use App\Actions\Files\DownloadLearningMaterialFile;
use App\Http\Controllers\Controller;
use App\Http\Requests\Files\ProtectedFileDownloadRequest;
use App\Models\User;
use App\Support\Files\ProtectedFileDownload;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\HeaderUtils;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ProtectedFileDownloadController extends Controller
{
    public function __invoke(
        ProtectedFileDownloadRequest $request,
        string $file,
        DownloadLearningMaterialFile $downloadLearningMaterialFile,
    ): StreamedResponse {
        /** @var User $actor */
        $actor = $request->user();
        $download = $downloadLearningMaterialFile($actor, $file);
        $filename = $this->safeFilename($download);
        $fallback = $this->asciiFallback($filename, $download->canonicalExtension);

        return response()->stream(function () use ($download): void {
            try {
                fpassthru($download->stream);
            } finally {
                if (is_resource($download->stream)) {
                    fclose($download->stream);
                }
            }
        }, headers: [
            'Content-Type' => $download->mimeType,
            'Content-Disposition' => HeaderUtils::makeDisposition(
                HeaderUtils::DISPOSITION_ATTACHMENT,
                $filename,
                $fallback,
            ),
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    private function safeFilename(ProtectedFileDownload $download): string
    {
        $filename = preg_replace('/[\x00-\x1F\x7F]+/u', '', $download->displayFilename);

        if (! is_string($filename)) {
            return $this->fallbackFilename($download->canonicalExtension);
        }

        $filename = trim(str_replace(['/', '\\'], '_', $filename));

        if ($filename === '' || $filename === '.' || $filename === '..') {
            return $this->fallbackFilename($download->canonicalExtension);
        }

        return $filename;
    }

    private function asciiFallback(string $filename, string $extension): string
    {
        $fallback = Str::ascii($filename);
        $fallback = preg_replace('/[^\x20-\x7E]+/', '_', $fallback);

        if (! is_string($fallback)) {
            return $this->fallbackFilename($extension);
        }

        $fallback = trim(str_replace(['%', '/', '\\'], '_', $fallback));

        if ($fallback === '' || $fallback === '.' || $fallback === '..') {
            return $this->fallbackFilename($extension);
        }

        return $fallback;
    }

    private function fallbackFilename(string $extension): string
    {
        return 'download.'.$extension;
    }
}
