<?php

namespace App\Actions\Student;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Student\AttemptNotEditableException;
use App\Exceptions\Student\StudentHomeworkArchivedException;
use App\Exceptions\Student\StudentHomeworkClosedException;
use App\Exceptions\Student\StudentHomeworkDeadlinePassedException;
use App\Exceptions\Student\StudentHomeworkNotActiveException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\User;
use App\Support\Files\LearningMaterialFileMetadata;
use App\Support\Student\StudentAttemptAnswerMutationResult;
use App\Support\Student\StudentHomeworkAttemptAccess;
use App\Support\Student\StudentSubmissionAnswerFiles;
use Closure;
use Illuminate\Http\UploadedFile;
use LogicException;

class SaveStudentHomeworkFileAnswer
{
    public function __construct(
        private readonly StudentHomeworkAttemptAccess $access,
        private readonly StudentSubmissionAnswerFiles $files,
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeDeadline,
    ) {}

    public function __invoke(User $student, string $attemptId, string $questionId, UploadedFile $upload): StudentAttemptAnswerMutationResult
    {
        $preliminaryAttempt = $this->access->resolveAttempt($student, $attemptId);
        $this->files->resolveQuestion($student, $preliminaryAttempt->assessment_id, $questionId);
        $preliminaryAssessment = Assessment::query()
            ->select(['id', 'topic_id'])->where('institution_id', $student->institution_id)
            ->whereKey($preliminaryAttempt->assessment_id)->firstOrFail();
        $result = $this->files->withStagedUpload($student, $preliminaryAttempt, $questionId, $upload,
            function (LearningMaterialFileMetadata $metadata, string $diskName, string $storageKey, Closure $cleanupNewBlob) use ($student, $preliminaryAssessment, $preliminaryAttempt, $questionId): ?StudentAttemptAnswerMutationResult {
                ['topic' => $topic, 'assessment' => $assessment, 'homework' => $homework] = $this->access->shareHomeworkForAnswer($student, $preliminaryAssessment);
                $attempt = AssessmentAttempt::query()
                    ->where('institution_id', $student->institution_id)->where('student_id', $student->id)
                    ->whereKey($preliminaryAttempt->id)->lockForUpdate()->first();
                $question = $this->files->resolveQuestion($student, $assessment->id, $questionId, lock: true);
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

                return $this->files->save($student, $attempt, $question, $answer, $metadata, $diskName, $storageKey, $cleanupNewBlob);
            });

        if ($result === null) {
            ($this->finalizeDeadline)($student->institution_id, $preliminaryAssessment->id);

            throw new StudentHomeworkDeadlinePassedException;
        }

        return $result;
    }
}
