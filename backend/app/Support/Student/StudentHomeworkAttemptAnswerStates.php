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
     * @return SupportCollection<int, StudentAttemptAnswerMutationResult>
     */
    public function __invoke(string $institutionId, AssessmentAttempt $attempt, Collection $questions): SupportCollection
    {
        return $this->project($institutionId, $attempt, $questions, $this->answerIntegrity->canonical(...));
    }

    /**
     * @param  Collection<int, Question>  $questions
     * @return SupportCollection<int, StudentAttemptAnswerMutationResult>
     */
    public function historicalRead(string $institutionId, AssessmentAttempt $attempt, Collection $questions): SupportCollection
    {
        return $this->project($institutionId, $attempt, $questions, $this->answerIntegrity->canonicalForHistoricalRead(...));
    }

    /**
     * @param  Collection<int, Question>  $questions
     * @return SupportCollection<int, StudentAttemptAnswerMutationResult>
     */
    private function project(string $institutionId, AssessmentAttempt $attempt, Collection $questions, \Closure $canonicalize): SupportCollection
    {
        $this->answerValues->loadQuestions($questions, $institutionId);
        // Scope by the authorized Attempt, but do not hide corrupt Answer ownership or Question IDs.
        $answers = $attempt->answers()->get();
        $this->answerIntegrity->load($answers, $institutionId);
        $questionsById = $questions->keyBy('id');

        foreach ($answers as $answer) {
            $question = $questionsById->get($answer->question_id);

            if (! $question instanceof Question) {
                throw new LogicException('Persisted Student answer does not belong to the authorized Question set.');
            }

            $answer->setAttribute('student_answer_value', $canonicalize($answer, $attempt, $question));
        }

        $answersByQuestion = $answers->keyBy('question_id');

        return $questions
            ->filter(fn (Question $question): bool => $answersByQuestion->has($question->id))
            ->map(fn (Question $question): StudentAttemptAnswerMutationResult => new StudentAttemptAnswerMutationResult(
                $question, $answersByQuestion->get($question->id),
            ))->values();
    }
}
