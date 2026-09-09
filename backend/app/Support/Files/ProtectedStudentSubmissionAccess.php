<?php

namespace App\Support\Files;

use App\Enums\AssessmentType;
use App\Enums\FileCategory;
use App\Enums\HomeworkStatus;
use App\Enums\QuestionType;
use App\Enums\UserRole;
use App\Models\File;
use App\Models\User;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use stdClass;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ProtectedStudentSubmissionAccess
{
    /** @return array{file_id: string, answer_file_id: string, answer_id: string, attempt_id: string, recipient_id: string, question_id: string, assessment_id: string} */
    public function resolve(User $actor, string $fileId): array
    {
        $this->assertStudentAndUuid($actor, $fileId);
        $target = $this->ownershipQuery($actor, $fileId)->first([
            'files.id as file_id',
            'answer_files.id as answer_file_id',
            'attempt_answers.id as answer_id',
            'assessment_attempts.id as attempt_id',
            'assessment_students.id as recipient_id',
            'questions.id as question_id',
            'assessments.id as assessment_id',
        ]);

        if (! $target instanceof stdClass) {
            throw new NotFoundHttpException;
        }

        return [
            'file_id' => (string) $target->file_id,
            'answer_file_id' => (string) $target->answer_file_id,
            'answer_id' => (string) $target->answer_id,
            'attempt_id' => (string) $target->attempt_id,
            'recipient_id' => (string) $target->recipient_id,
            'question_id' => (string) $target->question_id,
            'assessment_id' => (string) $target->assessment_id,
        ];
    }

    /** @param array{file_id: string, answer_file_id: string, answer_id: string, attempt_id: string, recipient_id: string, question_id: string, assessment_id: string} $target */
    public function lock(User $actor, array $target): File
    {
        $this->assertStudentAndUuid($actor, $target['file_id']);
        $file = File::query()
            ->select(['id', 'storage_disk', 'storage_key', 'mime_type', 'original_name', 'extension'])
            ->where('institution_id', $actor->institution_id)
            ->whereKey($target['file_id'])
            ->where('category', FileCategory::StudentSubmission->value)
            ->where('uploaded_by_user_id', $actor->id)
            ->whereNull('removed_at')
            ->sharedLock()
            ->first();

        if (! $file instanceof File || ! $this->ownershipQuery($actor, $file->id)
            ->where('answer_files.id', $target['answer_file_id'])
            ->where('attempt_answers.id', $target['answer_id'])
            ->where('assessment_attempts.id', $target['attempt_id'])
            ->where('assessment_students.id', $target['recipient_id'])
            ->where('questions.id', $target['question_id'])
            ->where('assessments.id', $target['assessment_id'])
            ->exists()) {
            throw new NotFoundHttpException;
        }

        return $file;
    }

    private function assertStudentAndUuid(User $actor, string $fileId): void
    {
        if ($actor->role !== UserRole::Student || ! Str::isUuid($fileId)) {
            throw new NotFoundHttpException;
        }
    }

    private function ownershipQuery(User $actor, string $fileId): Builder
    {
        return DB::table('files')
            ->where('files.institution_id', $actor->institution_id)
            ->where('files.id', $fileId)
            ->where('files.category', FileCategory::StudentSubmission->value)
            ->where('files.uploaded_by_user_id', $actor->id)
            ->whereNull('files.removed_at')
            ->join('answer_files', 'answer_files.file_id', '=', 'files.id')
            ->where('answer_files.institution_id', $actor->institution_id)
            ->join('attempt_answers', 'attempt_answers.id', '=', 'answer_files.answer_id')
            ->where('attempt_answers.institution_id', $actor->institution_id)
            ->join('assessment_attempts', 'assessment_attempts.id', '=', 'attempt_answers.attempt_id')
            ->where('assessment_attempts.institution_id', $actor->institution_id)
            ->where('assessment_attempts.student_id', $actor->id)
            ->join('assessment_students', 'assessment_students.id', '=', 'assessment_attempts.assessment_student_id')
            ->where('assessment_students.institution_id', $actor->institution_id)
            ->whereColumn('assessment_students.assessment_id', 'assessment_attempts.assessment_id')
            ->where('assessment_students.student_id', $actor->id)
            ->join('questions', 'questions.id', '=', 'attempt_answers.question_id')
            ->where('questions.institution_id', $actor->institution_id)
            ->whereColumn('questions.assessment_id', 'assessment_attempts.assessment_id')
            ->where('questions.type', QuestionType::FileBased->value)
            ->join('assessments', 'assessments.id', '=', 'assessment_attempts.assessment_id')
            ->where('assessments.institution_id', $actor->institution_id)
            ->where('assessments.type', AssessmentType::Homework->value)
            ->join('homework_assignments', 'homework_assignments.assessment_id', '=', 'assessments.id')
            ->where('homework_assignments.institution_id', $actor->institution_id)
            ->whereIn('homework_assignments.status', [HomeworkStatus::Active->value, HomeworkStatus::Closed->value, HomeworkStatus::Archived->value]);
    }
}
