<?php

namespace App\Actions\Student;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Student\AttemptNotEditableException;
use App\Exceptions\Student\StudentHomeworkArchivedException;
use App\Exceptions\Student\StudentHomeworkClosedException;
use App\Exceptions\Student\StudentHomeworkConflictException;
use App\Exceptions\Student\StudentHomeworkDeadlinePassedException;
use App\Exceptions\Student\StudentHomeworkNotActiveException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Question;
use App\Models\User;
use App\Support\Student\StudentHomeworkAnswerIntegrity;
use App\Support\Student\StudentHomeworkAnswerValue;
use App\Support\Student\StudentHomeworkAnswerWriter;
use App\Support\Student\StudentHomeworkAttemptAccess;
use App\Support\Student\StudentHomeworkAttemptAnswerMutationResult;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class SaveStudentHomeworkAttemptAnswer
{
    public function __construct(
        private readonly StudentHomeworkAttemptAccess $access,
        private readonly StudentHomeworkAnswerValue $values,
        private readonly StudentHomeworkAnswerIntegrity $integrity,
        private readonly StudentHomeworkAnswerWriter $writer,
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeDeadline,
    ) {}

    /** @param array<string, mixed> $payload */
    public function __invoke(User $student, string $attemptId, string $questionId, array $payload): StudentHomeworkAttemptAnswerMutationResult
    {
        $preliminaryAttempt = $this->access->resolveAttempt($student, $attemptId);

        if (! Str::isUuid($questionId) || ! Question::query()
            ->where('institution_id', $student->institution_id)
            ->where('assessment_id', $preliminaryAttempt->assessment_id)
            ->whereKey($questionId)->exists()) {
            throw new NotFoundHttpException;
        }

        $preliminaryAssessment = Assessment::query()
            ->select(['id', 'topic_id'])
            ->where('institution_id', $student->institution_id)
            ->whereKey($preliminaryAttempt->assessment_id)->firstOrFail();

        $result = DB::transaction(function () use ($student, $preliminaryAssessment, $preliminaryAttempt, $questionId, $payload): ?StudentHomeworkAttemptAnswerMutationResult {
            ['topic' => $topic, 'assessment' => $assessment, 'homework' => $homework] = $this->access->shareHomeworkForAnswer($student, $preliminaryAssessment);
            $attempt = AssessmentAttempt::query()
                ->where('institution_id', $student->institution_id)
                ->where('student_id', $student->id)
                ->whereKey($preliminaryAttempt->id)->lockForUpdate()->first();
            $question = Question::query()
                ->select(['id', 'institution_id', 'assessment_id', 'type'])
                ->where('institution_id', $student->institution_id)
                ->where('assessment_id', $assessment->id)
                ->whereKey($questionId)->sharedLock()->first();

            if ($attempt === null || $question === null) {
                throw new NotFoundHttpException;
            }

            // The authorized Attempt scopes this read; retain any corrupt parent identity for validation.
            $answer = AttemptAnswer::query()
                ->where('attempt_id', $attempt->id)->where('question_id', $question->id)
                ->lockForUpdate()->first();
            $observedAt = now();

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

            if ($payload['type'] !== $question->type->value) {
                throw ValidationException::withMessages(['type' => ['The answer type does not match the Question type.']]);
            }

            $this->values->loadQuestions(new Collection([$question]), $student->institution_id);
            $existingValue = null;

            if ($answer !== null) {
                $this->integrity->load(new Collection([$answer]), institutionId: $student->institution_id);

                try {
                    $existingValue = $this->integrity->canonical($answer, $attempt, $question);
                } catch (LogicException) {
                    throw new StudentHomeworkConflictException;
                }
            }

            $value = $this->values->resolve($question, $payload);

            if ($existingValue !== $value) {
                $answer = $this->writer->replace($attempt, $question, $answer, $value);
            }

            $answer?->setAttribute('student_answer_value', $value);

            return new StudentHomeworkAttemptAnswerMutationResult($question, $answer);
        });

        if ($result === null) {
            // Reconcile only after releasing our shared parents and own Attempt lock.
            ($this->finalizeDeadline)($student->institution_id, $preliminaryAssessment->id);

            throw new StudentHomeworkDeadlinePassedException;
        }

        return $result;
    }
}
