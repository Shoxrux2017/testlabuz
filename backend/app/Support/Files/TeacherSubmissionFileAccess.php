<?php

namespace App\Support\Files;

use App\Enums\FileCategory;
use App\Enums\QuestionType;
use App\Enums\UserRole;
use App\Models\AssessmentAttempt;
use App\Models\File;
use App\Models\User;
use App\Support\Teacher\TeacherSubmissionAccess;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use stdClass;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * A Teacher's access to a submitted answer file (docs/09 §22.2, S09-T5): the Student's own live
 * file on a file-based answer of a submission the Teacher may review. Files of in-progress
 * Attempts stay Student-only because such an Attempt is not a submission.
 */
final class TeacherSubmissionFileAccess
{
    public function __construct(private readonly TeacherSubmissionAccess $submissions) {}

    /** @return array{file_id: string, answer_file_id: string, answer_id: string, attempt_id: string} */
    public function resolve(User $teacher, string $fileId): array
    {
        $this->assertTeacherAndUuid($teacher, $fileId);
        $target = $this->graph($teacher, $fileId)->toBase()->select([
            'files.id as file_id',
            'answer_files.id as answer_file_id',
            'attempt_answers.id as answer_id',
            'assessment_attempts.id as attempt_id',
        ])->first();

        if (! $target instanceof stdClass) {
            throw new NotFoundHttpException;
        }

        return [
            'file_id' => (string) $target->file_id,
            'answer_file_id' => (string) $target->answer_file_id,
            'answer_id' => (string) $target->answer_id,
            'attempt_id' => (string) $target->attempt_id,
        ];
    }

    /** @param array{file_id: string, answer_file_id: string, answer_id: string, attempt_id: string} $target */
    public function lock(User $teacher, array $target): File
    {
        $this->assertTeacherAndUuid($teacher, $target['file_id']);
        $file = File::query()
            ->select(['id', 'storage_disk', 'storage_key', 'mime_type', 'original_name', 'extension'])
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($target['file_id'])
            ->where('category', FileCategory::StudentSubmission->value)
            ->whereNull('removed_at')
            ->sharedLock()
            ->first();

        if (! $file instanceof File || ! $this->graph($teacher, $file->id)
            ->where('answer_files.id', $target['answer_file_id'])
            ->where('attempt_answers.id', $target['answer_id'])
            ->where('assessment_attempts.id', $target['attempt_id'])
            ->exists()) {
            throw new NotFoundHttpException;
        }

        return $file;
    }

    private function assertTeacherAndUuid(User $actor, string $fileId): void
    {
        if ($actor->role !== UserRole::Teacher || ! Str::isUuid($fileId)) {
            throw new NotFoundHttpException;
        }
    }

    /** @return Builder<AssessmentAttempt> */
    private function graph(User $teacher, string $fileId): Builder
    {
        return $this->submissions->query($teacher)
            ->join('attempt_answers', fn ($join) => $join->on('attempt_answers.attempt_id', '=', 'assessment_attempts.id')
                ->on('attempt_answers.institution_id', '=', 'assessment_attempts.institution_id'))
            ->join('questions', fn ($join) => $join->on('questions.id', '=', 'attempt_answers.question_id')
                ->on('questions.institution_id', '=', 'attempt_answers.institution_id')
                ->on('questions.assessment_id', '=', 'assessment_attempts.assessment_id'))
            ->where('questions.type', QuestionType::FileBased->value)
            ->join('answer_files', fn ($join) => $join->on('answer_files.answer_id', '=', 'attempt_answers.id')
                ->on('answer_files.institution_id', '=', 'attempt_answers.institution_id'))
            ->join('files', fn ($join) => $join->on('files.id', '=', 'answer_files.file_id')
                ->on('files.institution_id', '=', 'answer_files.institution_id'))
            ->where('files.id', $fileId)
            ->where('files.category', FileCategory::StudentSubmission->value)
            ->whereNull('files.removed_at')
            ->whereColumn('files.uploaded_by_user_id', 'assessment_attempts.student_id');
    }
}
