<?php

namespace App\Support\Student;

use App\Models\AssessmentAttempt;
use App\Models\Question;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Collection as SupportCollection;
use LogicException;

final class StudentHomeworkAttemptAnswerStates
{
    public function __construct(
        private readonly StudentHomeworkAnswerValue $answerValues,
        private readonly StudentHomeworkAnswerIntegrity $answerIntegrity,
    ) {}

    /**
     * @param  Collection<int, Question>  $questions  Authorized current Assessment Questions ordered by position, then ID.
     * @return SupportCollection<int, StudentHomeworkAttemptAnswerMutationResult>
     */
    public function __invoke(string $institutionId, AssessmentAttempt $attempt, Collection $questions): SupportCollection
    {
        $this->answerValues->loadQuestions($questions, $institutionId);
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

        return $questions
            ->filter(fn (Question $question): bool => $answersByQuestion->has($question->id))
            ->map(fn (Question $question): StudentHomeworkAttemptAnswerMutationResult => new StudentHomeworkAttemptAnswerMutationResult(
                $question, $answersByQuestion->get($question->id),
            ))->values();
    }
}
