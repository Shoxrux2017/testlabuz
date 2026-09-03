<?php

namespace App\Support\Assessment;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Domain\Assessment\QuestionPositionSetValidator;
use App\Enums\FileExtension;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Question;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use LogicException;

final class QuestionConfigurationReader
{
    public function __construct(
        private readonly QuestionPositionSetValidator $positionSetValidator = new QuestionPositionSetValidator,
    ) {}

    /** @return array<string, mixed> */
    public function read(
        Question $question,
        ?QuestionType $type = null,
        ?QuestionCheckingMode $checkingMode = null,
    ): array {
        $type ??= $question->type;
        $checkingMode ??= $question->checking_mode;

        return match ($type) {
            QuestionType::SingleChoice,
            QuestionType::MultipleChoice => ['options' => $this->loaded($question, 'choiceOptions')->map(fn ($option): array => [
                'text' => $option->option_text,
                'is_correct' => $option->is_correct,
                'position' => $option->position,
            ])->values()->all()],
            QuestionType::TrueFalse => ['correct_value' => $this->trueFalseValue($question)],
            QuestionType::ShortWritten => $checkingMode === QuestionCheckingMode::Automatic
                ? ['accepted_answers' => $this->loaded($question, 'shortAcceptedAnswers')->pluck('accepted_text')->all()]
                : [],
            QuestionType::OpenWritten => [],
            QuestionType::FileBased => ['allowed_extensions' => FileExtension::values()],
            QuestionType::Matching => ['pairs' => $this->matchingPairs($question)],
            QuestionType::Ordering => ['items' => $this->loaded($question, 'orderingItems')->map(fn ($item): array => [
                'text' => $item->item_text,
                'correct_position' => $item->correct_position,
            ])->values()->all()],
            QuestionType::FillInBlank => ['blanks' => $this->fillBlanks($question)],
        };
    }

    public function assertNoIncompatibleTypedRows(
        Question $question,
        QuestionType $type,
        QuestionCheckingMode $checkingMode,
    ): void {
        $allowedRelations = match ($type) {
            QuestionType::SingleChoice,
            QuestionType::MultipleChoice => ['choiceOptions'],
            QuestionType::TrueFalse => ['trueFalseAnswer'],
            QuestionType::ShortWritten => $checkingMode === QuestionCheckingMode::Automatic
                ? ['shortAcceptedAnswers']
                : [],
            QuestionType::Matching => ['matchingItems'],
            QuestionType::Ordering => ['orderingItems'],
            QuestionType::FillInBlank => ['fillBlanks'],
            QuestionType::OpenWritten,
            QuestionType::FileBased => [],
        };

        foreach ([
            'choiceOptions',
            'trueFalseAnswer',
            'shortAcceptedAnswers',
            'matchingItems',
            'orderingItems',
            'fillBlanks',
        ] as $relation) {
            if (! in_array($relation, $allowedRelations, true)
                && ! $this->relationIsEmpty($question, $relation)) {
                throw new LogicException('Persisted Question has incompatible typed configuration rows.');
            }
        }
    }

    public function assertCanonicalInternalPositions(
        Question $question,
        QuestionType $type,
        QuestionCheckingMode $checkingMode,
    ): void {
        if ($type === QuestionType::ShortWritten && $checkingMode === QuestionCheckingMode::Automatic) {
            $this->positionSetValidator->validate(
                $this->loaded($question, 'shortAcceptedAnswers')->pluck('position')->all(),
                QuestionAuthoringLimits::MAX_SHORT_ACCEPTED_ANSWERS,
            );
        }

        if ($type === QuestionType::Matching) {
            $positions = [];

            foreach ($this->loaded($question, 'matchingItems')->groupBy('match_key') as $items) {
                $left = $items->firstWhere('side', QuestionMatchingSide::Left);
                $right = $items->firstWhere('side', QuestionMatchingSide::Right);

                if ($items->count() !== 2
                    || ! $left instanceof QuestionMatchingItem
                    || ! $right instanceof QuestionMatchingItem
                    || $left->position !== $right->position) {
                    throw new LogicException('Persisted Matching Question pair is invalid.');
                }

                $positions[] = $left->position;
            }

            $this->positionSetValidator->validate($positions, QuestionAuthoringLimits::MAX_MATCHING_PAIRS);
        }

        if ($type === QuestionType::FillInBlank) {
            foreach ($this->loaded($question, 'fillBlanks') as $blank) {
                if (! $blank instanceof QuestionFillBlank || ! $blank->relationLoaded('acceptedAnswers')) {
                    throw new LogicException('Persisted Fill Blank answers were not loaded.');
                }

                $this->positionSetValidator->validate(
                    $blank->acceptedAnswers->pluck('position')->all(),
                    QuestionAuthoringLimits::MAX_ACCEPTED_ANSWERS_PER_BLANK,
                );
            }
        }
    }

    private function trueFalseValue(Question $question): bool
    {
        if (! $question->relationLoaded('trueFalseAnswer') || $question->trueFalseAnswer === null) {
            throw new LogicException('Persisted true/false Question answer is missing.');
        }

        return $question->trueFalseAnswer->correct_value;
    }

    /** @return list<array{client_key: string, left: string, right: string}> */
    private function matchingPairs(Question $question): array
    {
        $pairs = [];

        foreach ($this->loaded($question, 'matchingItems')->groupBy('match_key') as $matchKey => $items) {
            $left = $items->firstWhere('side', QuestionMatchingSide::Left);
            $right = $items->firstWhere('side', QuestionMatchingSide::Right);

            if ($items->count() !== 2
                || ! $left instanceof QuestionMatchingItem
                || ! $right instanceof QuestionMatchingItem
                || $left->position !== $right->position) {
                throw new LogicException('Persisted Matching Question pair is invalid.');
            }

            $pairs[] = [
                'client_key' => (string) $matchKey,
                'left' => $left->item_text,
                'right' => $right->item_text,
            ];
        }

        return $pairs;
    }

    /** @return list<array{key: string, position: int, accepted_answers: list<string>}> */
    private function fillBlanks(Question $question): array
    {
        return $this->loaded($question, 'fillBlanks')->map(function (QuestionFillBlank $blank): array {
            if (! $blank->relationLoaded('acceptedAnswers')) {
                throw new LogicException('Persisted Fill Blank answers were not loaded.');
            }

            return [
                'key' => $blank->blank_key,
                'position' => $blank->position,
                'accepted_answers' => $blank->acceptedAnswers->pluck('accepted_text')->all(),
            ];
        })->values()->all();
    }

    private function relationIsEmpty(Question $question, string $relation): bool
    {
        $value = $this->loaded($question, $relation);

        return $value === null || (method_exists($value, 'isEmpty') && $value->isEmpty());
    }

    private function loaded(Question $question, string $relation): mixed
    {
        if (! $question->relationLoaded($relation)) {
            throw new LogicException("Persisted Question relation {$relation} was not loaded.");
        }

        return $question->getRelation($relation);
    }
}
