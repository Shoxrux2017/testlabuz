<?php

namespace App\Actions\Files;

use App\Enums\FileCategory;
use App\Models\User;
use App\Support\Files\ProtectedFileDownload;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class DownloadProtectedFile
{
    public function __construct(
        private readonly DownloadLearningMaterialFile $downloadLearningMaterial,
        private readonly DownloadStudentSubmissionFile $downloadStudentSubmission,
    ) {}

    public function __invoke(User $actor, string $fileId): ProtectedFileDownload
    {
        if (! Str::isUuid($fileId)) {
            throw new NotFoundHttpException;
        }

        $category = DB::table('files')
            ->where('institution_id', $actor->institution_id)
            ->where('id', $fileId)
            ->whereNull('removed_at')
            ->value('category');

        return match ($category) {
            FileCategory::LearningMaterial->value => ($this->downloadLearningMaterial)($actor, $fileId),
            FileCategory::StudentSubmission->value => ($this->downloadStudentSubmission)($actor, $fileId),
            default => throw new NotFoundHttpException,
        };
    }
}
