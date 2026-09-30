<?php

namespace App\Support\Checking;

use App\Domain\Assessment\Checking\AutomaticAnswerChecker;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Question;
use App\Models\QuestionFillBlank;
use App\Models\QuestionTrueFalseAnswer;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

/**
 * Maps persisted Question keys and canonical Student answers onto the S09-BE-001
 * automatic checker.
 */
final class CheckingAnswerKeys
{
    public function __construct(private readonly AutomaticAnswerChecker $checker) {}

    /**
     * Loads every key relation; the columns also satisfy the Student answer canonicalization.
     *
     * @param  Collection<int, Question>  $questions
     */
    public function load(Collection $questions, string $institutionId): void
    {
        $scoped = fn (string ...$columns): \Closure => fn ($query) => $query
            ->select($columns)->where('institution_id', $institutionId);

        $questions->load([
            'choiceOptions' => $scoped('id', 'institution_id', 'question_id', 'position', 'is_correct'),
            'trueFalseAnswer' => $scoped('question_id', 'institution_id', 'correct_value'),
            'shortAcceptedAnswers' => $scoped('id', 'institution_id', 'question_id', 'accepted_text'),
            'matchingItems' => $scoped('id', 'institution_id', 'question_id', 'side', 'match_key'),
            'orderingItems' => $scoped('id', 'institution_id', 'question_id', 'correct_position'),
            'fillBlanks' => $scoped('id', 'institution_id', 'question_id', 'position'),
            'fillBlanks.acceptedAnswers' => $scoped('id', 'institution_id', 'blank_id', 'accepted_text'),
        ]);
    }

    /** @param array<string, mixed> $canonical  The answer's canonical payload */
    public function awardedPoints(Question $question, array $canonical): string
    {
        $points = (string) $question->points;

        return match ($question->type) {
            QuestionType::SingleChoice => $this->checker->singleChoice($points, $this->options($question), $canonical['selected_option_ids']),
            QuestionType::MultipleChoice => $this->checker->multipleChoice($points, $this->options($question), $canonical['selected_option_ids']),
            QuestionType::TrueFalse => $this->checker->trueFalse($points, $this->correctValue($question), $canonical['value']),
            QuestionType::ShortWritten => $this->checker->shortWritten(
                $points,
                $question->getRelation('shortAcceptedAnswers')->pluck('accepted_text')->all(),
                $canonical['text'],
            ),
            QuestionType::Matching => $this->checker->matching(
                $points,
                $this->matchKeys($question, QuestionMatchingSide::Left),
                $this->matchKeys($question, QuestionMatchingSide::Right),
                $canonical['pairs'],
            ),
            QuestionType::Ordering => $this->checker->ordering(
                $points,
                $question->getRelation('orderingItems')->mapWithKeys(fn ($item): array => [$item->id => $item->correct_position])->all(),
                $canonical['items'],
            ),
            QuestionType::FillInBlank => $this->checker->fillInBlank(
                $points,
                $question->getRelation('fillBlanks')->mapWithKeys(fn (QuestionFillBlank $blank): array => [
                    $blank->id => $blank->getRelation('acceptedAnswers')->pluck('accepted_text')->all(),
                ])->all(),
                $canonical['values'],
            ),
            default => throw new LogicException('Only automatic Question types have answer keys.'),
        };
    }

    /** @return array<string, bool> */
    private function options(Question $question): array
    {
        return $question->getRelation('choiceOptions')
            ->mapWithKeys(fn ($option): array => [$option->id => $option->is_correct])->all();
    }

    private function correctValue(Question $question): bool
    {
        $answer = $question->getRelation('trueFalseAnswer');

        if (! $answer instanceof QuestionTrueFalseAnswer) {
            throw new LogicException('A true/false Question has no correct value.');
        }

        return $answer->correct_value;
    }

    /** @return array<string, string> */
    private function matchKeys(Question $question, QuestionMatchingSide $side): array
    {
        return $question->getRelation('matchingItems')
            ->filter(fn ($item): bool => $item->side === $side)
            ->mapWithKeys(fn ($item): array => [$item->id => $item->match_key])->all();
    }
}
