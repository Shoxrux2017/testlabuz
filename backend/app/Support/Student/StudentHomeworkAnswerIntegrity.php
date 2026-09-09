<?php

namespace App\Support\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Enums\QuestionType;
use App\Exceptions\Student\SelectionLimitExceededException;
use App\Exceptions\Student\StudentHomeworkConflictException;
use App\Models\AnswerFile;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\Question;
use App\Support\Files\StudentSubmissionUploadPolicy;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use LogicException;

final class StudentHomeworkAnswerIntegrity
{
    public function __construct(private readonly StudentHomeworkAnswerValue $values) {}

    /** @param Collection<int, AttemptAnswer> $answers */
    public function load(Collection $answers, string $institutionId, bool $lockFile = false): void
    {
        // Load every family: filtering out incompatible rows would hide corruption.
        $answers->load([
            'selectedOptions' => fn ($query) => $query->select([
                'question_choice_options.id', 'question_choice_options.institution_id', 'question_choice_options.question_id',
            ]),
            'booleanValue:answer_id,institution_id,boolean_value',
            'textValue:answer_id,institution_id,text_value',
            'matchingPairs:id,answer_id,institution_id,left_item_id,right_item_id',
            'orderingItems:id,answer_id,institution_id,ordering_item_id,submitted_position',
            'fillBlankValues:id,answer_id,institution_id,blank_id,text_value',
            'answerFile' => fn ($query) => $query->select(['id', 'answer_id', 'institution_id', 'file_id'])
                ->when($lockFile, fn ($query) => $query->lockForUpdate()),
            'answerFile.file' => fn ($query) => $query
                ->select(['id', 'institution_id', 'uploaded_by_user_id', 'category', 'removed_at',
                    'extension', 'size_bytes', 'checksum_sha256', 'storage_disk', 'storage_key', 'original_name', 'mime_type'])
                ->where('institution_id', $institutionId)
                ->when($lockFile, fn ($query) => $query->lockForUpdate()),
        ]);
    }

    /** @return array<string, mixed> */
    public function canonical(AttemptAnswer $answer, AssessmentAttempt $attempt, Question $question): array
    {
        $this->requireValid($answer->institution_id === $attempt->institution_id
            && $answer->attempt_id === $attempt->id && $answer->question_id === $question->id
            && $question->assessment_id === $attempt->assessment_id
            && $answer->getRawOriginal('checking_status') === AttemptAnswerCheckingStatus::Pending->value
            && $answer->awarded_points === null && $answer->feedback === null
            && $answer->checked_by_user_id === null && $answer->checked_at === null);

        $family = match ($question->type) {
            QuestionType::SingleChoice, QuestionType::MultipleChoice => 'selectedOptions',
            QuestionType::TrueFalse => 'booleanValue',
            QuestionType::ShortWritten, QuestionType::OpenWritten => 'textValue',
            QuestionType::Matching => 'matchingPairs',
            QuestionType::Ordering => 'orderingItems',
            QuestionType::FillInBlank => 'fillBlankValues',
            QuestionType::FileBased => 'answerFile',
            default => throw new LogicException('Unsupported persisted Student answer state.'),
        };

        foreach (['selectedOptions', 'booleanValue', 'textValue', 'matchingPairs', 'orderingItems', 'fillBlankValues', 'answerFile'] as $relation) {
            $this->requireValid($answer->relationLoaded($relation));
            $related = $answer->getRelation($relation);
            $rows = $related instanceof Collection ? $related : new Collection($related === null ? [] : [$related]);
            $this->requireValid($relation === $family ? $rows->isNotEmpty() : $rows->isEmpty());

            foreach ($rows as $row) {
                $this->requireValid($row->institution_id === $attempt->institution_id);

                if ($relation === 'selectedOptions') {
                    $this->requireValid($row->question_id === $question->id
                        && $row->pivot->institution_id === $attempt->institution_id
                        && $row->pivot->answer_id === $answer->id);
                } else {
                    $this->requireValid($row->answer_id === $answer->id);
                }
            }
        }

        $rows = $answer->getRelation($family);

        if ($family === 'answerFile') {
            return $this->canonicalFile($rows, $attempt);
        }

        $payload = match ($family) {
            'selectedOptions' => ['selected_option_ids' => $rows->modelKeys()],
            'booleanValue' => ['value' => $rows->boolean_value],
            'textValue' => ['text' => $rows->text_value],
            'matchingPairs' => ['pairs' => $rows->map(fn ($row): array => [
                'left_item_id' => $row->left_item_id, 'right_item_id' => $row->right_item_id,
            ])->all()],
            'orderingItems' => ['items' => $rows->map(fn ($row): array => [
                'item_id' => $row->ordering_item_id, 'position' => $row->submitted_position,
            ])->all()],
            'fillBlankValues' => ['values' => $rows->map(fn ($row): array => [
                'blank_id' => $row->blank_id, 'text' => $row->text_value,
            ])->all()],
        };

        try {
            $canonical = $this->values->resolve($question, $payload);
        } catch (ValidationException|SelectionLimitExceededException|StudentHomeworkConflictException $exception) {
            throw new LogicException('Persisted Student answer integrity failed.', previous: $exception);
        }

        $this->requireValid($canonical !== null);

        return $canonical;
    }

    /** @return array{file: array{id: string, original_name: string, extension: string, size_bytes: int}} */
    private function canonicalFile(AnswerFile $answerFile, AssessmentAttempt $attempt): array
    {
        $this->requireValid($answerFile->exists && Str::isUuid($answerFile->id)
            && $answerFile->relationLoaded('file'));
        $file = $answerFile->getRelation('file');
        $this->requireValid($file instanceof File && $file->exists);
        $extension = FileExtension::tryFrom((string) $file->getRawOriginal('extension'));
        $this->requireValid(Str::isUuid($file->id) && $file->id === $answerFile->file_id
            && $file->institution_id === $attempt->institution_id
            && $file->uploaded_by_user_id === $attempt->student_id
            && $file->getRawOriginal('category') === FileCategory::StudentSubmission->value
            && $file->removed_at === null && $extension !== null
            && $file->size_bytes > 0 && $file->size_bytes <= StudentSubmissionUploadPolicy::PLATFORM_MAX_SIZE_BYTES
            && is_string($file->checksum_sha256) && preg_match('/\A[a-f0-9]{64}\z/', $file->checksum_sha256) === 1
            && is_string($file->storage_disk) && $file->storage_disk !== ''
            && is_string($file->storage_key) && $file->storage_key !== ''
            && is_string($file->original_name) && $file->original_name !== ''
            && mb_strlen($file->original_name, 'UTF-8') <= 500);
        $mimeType = match ($extension) {
            FileExtension::Pdf => 'application/pdf',
            FileExtension::Docx => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            FileExtension::Ppt => 'application/vnd.ms-powerpoint',
            FileExtension::Pptx => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        };
        $this->requireValid($file->mime_type === $mimeType
            && strtolower((string) pathinfo($file->original_name, PATHINFO_EXTENSION)) === $extension->value);

        return ['file' => [
            'id' => $file->id, 'original_name' => $file->original_name,
            'extension' => $extension->value, 'size_bytes' => $file->size_bytes,
        ]];
    }

    private function requireValid(bool $valid): void
    {
        if (! $valid) {
            throw new LogicException('Persisted Student answer integrity failed.');
        }
    }
}
