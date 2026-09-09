<?php

namespace App\Actions\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\Question;
use App\Models\User;
use App\Support\Student\StudentHomeworkAnswerIntegrity;
use App\Support\Student\StudentHomeworkAnswerValue;
use App\Support\Student\StudentHomeworkAttemptAccess;
use App\Support\Student\StudentHomeworkAttemptAnswerMutationResult;
use Illuminate\Database\Eloquent\Collection;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ShowStudentHomeworkAttempt
{
    public function __construct(
        private readonly StudentHomeworkAttemptAccess $access,
        private readonly ShowStudentHomework $showHomework,
        private readonly StudentHomeworkAnswerValue $answerValues,
        private readonly StudentHomeworkAnswerIntegrity $answerIntegrity,
    ) {}

    public function __invoke(User $student, string $attemptId): AssessmentAttempt
    {
        $authorizedAttempt = $this->access->resolveAttempt($student, $attemptId);

        try {
            $homework = ($this->showHomework)($student, $authorizedAttempt->assessment_id);
        } catch (NotFoundHttpException $exception) {
            throw new LogicException('Authorized Homework Attempt lost its Homework projection.', previous: $exception);
        }

        $attempts = $homework->relationLoaded('attempts') ? $homework->getRelation('attempts') : null;

        if (! $attempts instanceof Collection) {
            throw new LogicException('Authorized Homework Attempt requires a fresh Attempt history.');
        }

        $expectedNumber = 1;

        foreach ($attempts as $historicalAttempt) {
            if ($historicalAttempt->attempt_number !== $expectedNumber || $expectedNumber > 3
                || ! array_key_exists('deadline_at', $historicalAttempt->getAttributes())
                || $historicalAttempt->deadline_at !== null
                || ($historicalAttempt->status === AssessmentAttemptStatus::InProgress
                    && ($historicalAttempt->submitted_at !== null || $historicalAttempt->finalized_at !== null
                        || $historicalAttempt->locked_at !== null || $historicalAttempt->finalization_reason !== null))) {
                throw new LogicException('Authorized Homework Attempt history contains an invalid Homework state.');
            }

            $expectedNumber++;
        }

        $attempt = $attempts->firstWhere('id', $authorizedAttempt->id);

        if (! $attempt instanceof AssessmentAttempt
            || $attempt->institution_id !== $student->institution_id
            || $attempt->student_id !== $student->id
            || $attempt->assessment_id !== $authorizedAttempt->assessment_id
            || $attempt->assessment_student_id !== $authorizedAttempt->assessment_student_id
            || $attempt->assessment_student_id !== $homework->getAttribute('student_recipient_id')) {
            throw new LogicException('Authorized Homework Attempt does not match the fresh recipient projection.');
        }

        $attempt->setRelation('assessment', $homework);
        $questions = $homework->getRelation('questions');
        $this->answerValues->loadQuestions($questions, $student->institution_id);
        // Scope by the authorized Attempt, but do not hide corrupt Answer ownership or Question IDs.
        $answers = $attempt->answers()->get();
        $this->answerIntegrity->load($answers);
        $questionsById = $questions->keyBy('id');

        foreach ($answers as $answer) {
            $question = $questionsById->get($answer->question_id);

            if (! $question instanceof Question) {
                throw new LogicException('Persisted Student answer does not belong to the authorized Question set.');
            }

            $answer->setAttribute('student_answer_value', $this->answerIntegrity->canonical($answer, $attempt, $question));
        }

        $answersByQuestion = $answers->keyBy('question_id');
        $attempt->setAttribute('student_answer_states', $questions
            ->filter(fn (Question $question): bool => $answersByQuestion->has($question->id))
            ->map(fn (Question $question): StudentHomeworkAttemptAnswerMutationResult => new StudentHomeworkAttemptAnswerMutationResult(
                $question, $answersByQuestion->get($question->id),
            ))->values());

        return $attempt;
    }
}
