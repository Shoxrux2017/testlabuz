<?php

namespace App\Actions\Student;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\FileCategory;
use App\Enums\HomeworkStatus;
use App\Enums\QuestionType;
use App\Enums\TopicStatus;
use App\Exceptions\Student\AttemptNotEditableException;
use App\Exceptions\Student\StudentHomeworkArchivedException;
use App\Exceptions\Student\StudentHomeworkClosedException;
use App\Exceptions\Student\StudentHomeworkConflictException;
use App\Exceptions\Student\StudentHomeworkDeadlinePassedException;
use App\Exceptions\Student\StudentHomeworkNotActiveException;
use App\Models\AnswerFile;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\User;
use App\Support\Files\LearningMaterialFileInspector;
use App\Support\Files\LearningMaterialFileMetadata;
use App\Support\Files\PrivateFileStorage;
use App\Support\Files\StudentSubmissionUploadPolicy;
use App\Support\Student\StudentHomeworkAnswerIntegrity;
use App\Support\Student\StudentHomeworkAttemptAccess;
use App\Support\Student\StudentHomeworkAttemptAnswerMutationResult;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Throwable;

class SaveStudentHomeworkFileAnswer
{
    public function __construct(
        private readonly StudentHomeworkAttemptAccess $access,
        private readonly StudentHomeworkAnswerIntegrity $integrity,
        private readonly LearningMaterialFileInspector $fileInspector,
        private readonly StudentSubmissionUploadPolicy $uploadPolicy,
        private readonly PrivateFileStorage $storage,
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeDeadline,
    ) {}

    public function __invoke(User $student, string $attemptId, string $questionId, UploadedFile $upload): StudentHomeworkAttemptAnswerMutationResult
    {
        $preliminaryAttempt = $this->access->resolveAttempt($student, $attemptId);
        $this->resolveQuestion($student, $preliminaryAttempt->assessment_id, $questionId);
        $preliminaryAssessment = Assessment::query()
            ->select(['id', 'topic_id'])->where('institution_id', $student->institution_id)
            ->whereKey($preliminaryAttempt->assessment_id)->firstOrFail();
        $earlySetting = $this->institutionSetting($student);
        $observedSize = $upload->getSize();

        if (! is_int($observedSize) || $observedSize <= 0) {
            throw ValidationException::withMessages(['file' => ['The uploaded file is invalid.']]);
        }

        $earlyLimit = $this->uploadPolicy->maxSizeBytes($earlySetting);
        $this->uploadPolicy->ensureWithinLimit($observedSize, $earlyLimit);
        $metadata = $this->fileInspector->inspect($upload);

        if ($metadata->sizeBytes !== $observedSize) {
            throw ValidationException::withMessages(['file' => ['The uploaded file is invalid.']]);
        }

        $this->uploadPolicy->ensureWithinLimit($metadata->sizeBytes, $earlyLimit);
        $storageKey = "student-submissions/{$student->institution_id}/{$preliminaryAttempt->id}/{$questionId}/"
            .Str::uuid().'.'.$metadata->extension->value;
        $diskName = $this->storage->store($upload, $storageKey);
        $cleanupAttempted = false;
        $cleanupNewBlob = function () use ($diskName, $storageKey, &$cleanupAttempted): void {
            if (! $cleanupAttempted) {
                $cleanupAttempted = true;
                $this->storage->deleteBestEffort($diskName, $storageKey, 'student_submission_compensation');
            }
        };

        try {
            $result = DB::transaction(function () use ($student, $preliminaryAssessment, $preliminaryAttempt, $questionId, $metadata, $diskName, $storageKey, $cleanupNewBlob): ?StudentHomeworkAttemptAnswerMutationResult {
                DB::afterRollBack($cleanupNewBlob);
                ['topic' => $topic, 'assessment' => $assessment, 'homework' => $homework] = $this->access->shareHomeworkForAnswer($student, $preliminaryAssessment);
                $attempt = AssessmentAttempt::query()
                    ->where('institution_id', $student->institution_id)->where('student_id', $student->id)
                    ->whereKey($preliminaryAttempt->id)->lockForUpdate()->first();
                $question = $this->resolveQuestion($student, $assessment->id, $questionId, lock: true);
                $observedAt = now();

                if ($attempt === null) {
                    throw new LogicException('The authorized Homework Attempt changed its identity.');
                }

                match ($homework->status) {
                    HomeworkStatus::Closed => throw new StudentHomeworkClosedException,
                    HomeworkStatus::Archived => throw new StudentHomeworkArchivedException,
                    HomeworkStatus::Active => null,
                    default => throw new StudentHomeworkNotActiveException,
                };

                if ($topic->status !== TopicStatus::Active) {
                    throw new StudentHomeworkNotActiveException;
                }

                if ($homework->deadline_at !== null && $observedAt->gte($homework->deadline_at)) {
                    return null;
                }

                $this->access->assertValidAnswerAttempt($student, $assessment, $attempt);

                if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
                    throw new AttemptNotEditableException;
                }

                // The authorized Attempt scopes this read without hiding corrupt Answer ownership.
                $answer = AttemptAnswer::query()->where('attempt_id', $attempt->id)
                    ->where('question_id', $question->id)->lockForUpdate()->first();
                $file = null;

                if ($answer !== null) {
                    try {
                        $this->integrity->load(new Collection([$answer]), $student->institution_id, lockFile: true);
                        $this->integrity->canonical($answer, $attempt, $question);
                    } catch (LogicException) {
                        throw new StudentHomeworkConflictException;
                    }

                    $file = $answer->answerFile->file;
                }

                $setting = $this->institutionSetting($student, lock: true);
                $this->uploadPolicy->ensureWithinLimit($metadata->sizeBytes, $this->uploadPolicy->maxSizeBytes($setting));

                if ($file !== null && $this->isIdentical($file, $metadata)) {
                    $cleanupNewBlob();
                } else {
                    $savedAt = now();

                    if ($answer === null) {
                        $answer = new AttemptAnswer([
                            'institution_id' => $student->institution_id, 'attempt_id' => $attempt->id,
                            'question_id' => $question->id, 'checking_status' => AttemptAnswerCheckingStatus::Pending,
                            'awarded_points' => null, 'feedback' => null, 'checked_by_user_id' => null, 'checked_at' => null,
                        ]);
                        $answer->created_at = $savedAt;
                    }

                    $answer->updated_at = $savedAt;
                    $answer->save();

                    if ($file === null) {
                        $file = new File([
                            'institution_id' => $student->institution_id, 'uploaded_by_user_id' => $student->id,
                            'category' => FileCategory::StudentSubmission, 'removed_at' => null,
                        ]);
                        $file->created_at = $savedAt;
                    } else {
                        $oldDisk = $file->storage_disk;
                        $oldKey = $file->storage_key;
                        $fileId = $file->id;
                        DB::afterCommit(fn () => $this->storage->deleteBestEffort(
                            $oldDisk, $oldKey, 'student_submission_replace_old_blob_cleanup', $fileId,
                        ));
                    }

                    $file->fill([
                        'original_name' => $metadata->originalName, 'storage_disk' => $diskName,
                        'storage_key' => $storageKey, 'mime_type' => $metadata->mimeType,
                        'extension' => $metadata->extension, 'size_bytes' => $metadata->sizeBytes,
                        'checksum_sha256' => $metadata->checksumSha256,
                    ]);
                    $file->updated_at = $savedAt;
                    $file->save();

                    if (! $answer->relationLoaded('answerFile')) {
                        $answerFile = new AnswerFile([
                            'institution_id' => $student->institution_id, 'answer_id' => $answer->id, 'file_id' => $file->id,
                        ]);
                        $answerFile->created_at = $savedAt;
                        $answerFile->save();
                        $answer->setRelation('answerFile', $answerFile);
                    }

                    $answer->answerFile->setRelation('file', $file);
                }

                $this->integrity->load(new Collection([$answer]), $student->institution_id);
                $answer->setAttribute('student_answer_value', $this->integrity->canonical($answer, $attempt, $question));

                return new StudentHomeworkAttemptAnswerMutationResult($question, $answer);
            });

            if ($result === null) {
                $cleanupNewBlob();
                ($this->finalizeDeadline)($student->institution_id, $preliminaryAssessment->id);

                throw new StudentHomeworkDeadlinePassedException;
            }

            return $result;
        } catch (Throwable $exception) {
            $cleanupNewBlob();

            throw $exception;
        }
    }

    private function resolveQuestion(User $student, string $assessmentId, string $questionId, bool $lock = false): Question
    {
        if (! Str::isUuid($questionId)) {
            throw new NotFoundHttpException;
        }

        $query = Question::query()->select(['id', 'institution_id', 'assessment_id', 'type'])
            ->where('institution_id', $student->institution_id)->where('assessment_id', $assessmentId)->whereKey($questionId);
        $question = ($lock ? $query->sharedLock() : $query)->first();

        if ($question === null) {
            throw new NotFoundHttpException;
        }

        if ($question->type !== QuestionType::FileBased) {
            throw ValidationException::withMessages(['type' => ['The answer type does not match the Question type.']]);
        }

        return $question;
    }

    private function institutionSetting(User $student, bool $lock = false): InstitutionSetting
    {
        $query = InstitutionSetting::query()->whereKey($student->institution_id);
        $setting = ($lock ? $query->sharedLock() : $query)->first();

        if ($setting === null) {
            throw new LogicException('The Institution upload setting is missing.');
        }

        return $setting;
    }

    private function isIdentical(File $file, LearningMaterialFileMetadata $metadata): bool
    {
        return $file->checksum_sha256 === $metadata->checksumSha256 && $file->size_bytes === $metadata->sizeBytes
            && $file->extension === $metadata->extension && $file->mime_type === $metadata->mimeType
            && $file->original_name === $metadata->originalName;
    }
}
