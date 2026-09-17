<?php

namespace App\Actions\Student;

use App\Exceptions\Student\StudentBlitzConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Question;
use App\Models\User;
use App\Support\Student\StudentAttemptAnswerMutationResult;
use App\Support\Student\StudentBlitzAttemptAccess;
use App\Support\Student\StudentHomeworkAnswerIntegrity;
use App\Support\Student\StudentHomeworkAnswerValue;
use App\Support\Student\StudentHomeworkAnswerWriter;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class SaveStudentBlitzAttemptAnswer
{
    public function __construct(
        private readonly StudentBlitzAttemptAccess $access,
        private readonly StudentHomeworkAnswerValue $values,
        private readonly StudentHomeworkAnswerIntegrity $integrity,
        private readonly StudentHomeworkAnswerWriter $writer,
    ) {}

    /** @param array<string, mixed> $payload */
    public function __invoke(User $student, string $attemptId, string $questionId, array $payload): StudentAttemptAnswerMutationResult
    {
        $preliminaryAttempt = $this->access->resolveAttempt($student, $attemptId);

        if (! Str::isUuid($questionId) || ! Question::query()
            ->where('institution_id', $student->institution_id)
            ->where('assessment_id', $preliminaryAttempt->assessment_id)
            ->whereKey($questionId)->exists()) {
            throw new NotFoundHttpException;
        }

        $preliminaryAssessment = Assessment::query()->select(['id', 'topic_id'])
            ->where('institution_id', $student->institution_id)
            ->whereKey($preliminaryAttempt->assessment_id)->firstOrFail();

        return DB::transaction(function () use ($student, $preliminaryAssessment, $preliminaryAttempt, $questionId, $payload): StudentAttemptAnswerMutationResult {
            ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] = $this->access->shareBlitzForAnswer($student, $preliminaryAssessment);
            $attempt = AssessmentAttempt::query()->where('institution_id', $student->institution_id)
                ->where('student_id', $student->id)->whereKey($preliminaryAttempt->id)->lockForUpdate()->first();
            $question = Question::query()->select(['id', 'institution_id', 'assessment_id', 'type'])
                ->where('institution_id', $student->institution_id)->where('assessment_id', $assessment->id)
                ->whereKey($questionId)->sharedLock()->first();

            if ($attempt === null || $question === null) {
                throw new NotFoundHttpException;
            }

            // The authorized Attempt scopes this read without hiding corrupt Answer ownership.
            $answer = AttemptAnswer::query()->where('attempt_id', $attempt->id)
                ->where('question_id', $question->id)->lockForUpdate()->first();
            $this->access->assertAnswerEditable($student, $topic, $assessment, $blitz, $attempt);

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
                    throw new StudentBlitzConflictException;
                }
            }

            $value = $this->values->resolve($question, $payload);

            if ($existingValue !== $value) {
                $answer = $this->writer->replace($attempt, $question, $answer, $value);
            }

            $answer?->setAttribute('student_answer_value', $value);

            return new StudentAttemptAnswerMutationResult($question, $answer);
        });
    }
}
