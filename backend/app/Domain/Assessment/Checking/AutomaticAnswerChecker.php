<?php

namespace App\Domain\Assessment\Checking;

use LogicException;

/**
 * Awards points to one answered automatic Question. Ids compare case-insensitively.
 * An answer that breaks the saved-answer integrity rules throws instead of being scored.
 */
final class AutomaticAnswerChecker
{
    public function __construct(
        private readonly AnswerTextNormalizer $normalizer = new AnswerTextNormalizer,
        private readonly CheckingScoreMath $math = new CheckingScoreMath,
    ) {}

    /** @param list<string> $selectedOptionIds */
    public function singleChoice(string $points, string $correctOptionId, array $selectedOptionIds): string
    {
        $selected = $this->uniqueIds($selectedOptionIds, 'selected option');

        if (count($selected) !== 1) {
            throw new LogicException('A single-choice answer must select exactly one option.');
        }

        return $this->allOrNothing($points, $selected[0] === strtolower($correctOptionId));
    }

    /**
     * BR-Q-009: a wrong selection earns and deducts nothing.
     *
     * @param  list<string>  $correctOptionIds
     * @param  list<string>  $selectedOptionIds
     */
    public function multipleChoice(string $points, array $correctOptionIds, array $selectedOptionIds): string
    {
        $correct = $this->uniqueIds($correctOptionIds, 'correct option');
        $selected = $this->uniqueIds($selectedOptionIds, 'selected option');

        return $this->math->partialPoints(
            $points,
            count(array_intersect($selected, $correct)),
            count($correct),
        );
    }

    public function trueFalse(string $points, bool $correctValue, bool $answer): string
    {
        return $this->allOrNothing($points, $answer === $correctValue);
    }

    /** @param list<string> $acceptedAnswers */
    public function shortWritten(string $points, array $acceptedAnswers, string $text): string
    {
        return $this->allOrNothing($points, $this->matchesAnyAccepted($text, $acceptedAnswers));
    }

    /**
     * @param  array<string, string>  $leftMatchKeys  left item id => match key
     * @param  array<string, string>  $rightMatchKeys  right item id => match key
     * @param  list<array{left_item_id: string, right_item_id: string}>  $pairs
     */
    public function matching(string $points, array $leftMatchKeys, array $rightMatchKeys, array $pairs): string
    {
        $left = $this->byLowerId($leftMatchKeys, 'left item');
        $right = $this->byLowerId($rightMatchKeys, 'right item');
        $this->requireAnswered($pairs);
        $usedLeft = [];
        $usedRight = [];
        $correct = 0;

        foreach ($pairs as $pair) {
            $leftId = strtolower($pair['left_item_id']);
            $rightId = strtolower($pair['right_item_id']);

            if (! array_key_exists($leftId, $left) || ! array_key_exists($rightId, $right)
                || isset($usedLeft[$leftId]) || isset($usedRight[$rightId])) {
                throw new LogicException('A matching answer names an unknown or repeated item.');
            }

            $usedLeft[$leftId] = true;
            $usedRight[$rightId] = true;

            if (strtolower($left[$leftId]) === strtolower($right[$rightId])) {
                $correct++;
            }
        }

        return $this->math->partialPoints($points, $correct, count($left));
    }

    /**
     * @param  array<string, int>  $correctPositions  item id => 1-based correct position
     * @param  list<array{item_id: string, position: int}>  $items
     */
    public function ordering(string $points, array $correctPositions, array $items): string
    {
        $positions = $this->byLowerId($correctPositions, 'ordering item');
        $this->requireAnswered($items);
        $usedItems = [];
        $usedPositions = [];
        $correct = 0;

        foreach ($items as $item) {
            $itemId = strtolower($item['item_id']);
            $position = $item['position'];

            if (! array_key_exists($itemId, $positions) || isset($usedItems[$itemId])
                || isset($usedPositions[$position]) || $position < 1 || $position > count($positions)) {
                throw new LogicException('An ordering answer names an unknown or repeated item or position.');
            }

            $usedItems[$itemId] = true;
            $usedPositions[$position] = true;

            if ($positions[$itemId] === $position) {
                $correct++;
            }
        }

        return $this->math->partialPoints($points, $correct, count($positions));
    }

    /**
     * Unfilled blanks count as wrong.
     *
     * @param  array<string, list<string>>  $acceptedAnswersByBlank  blank id => accepted answers
     * @param  list<array{blank_id: string, text: string}>  $values
     */
    public function fillInBlank(string $points, array $acceptedAnswersByBlank, array $values): string
    {
        $blanks = $this->byLowerId($acceptedAnswersByBlank, 'blank');
        $this->requireAnswered($values);
        $filled = [];
        $correct = 0;

        foreach ($values as $value) {
            $blankId = strtolower($value['blank_id']);

            if (! array_key_exists($blankId, $blanks) || isset($filled[$blankId])) {
                throw new LogicException('A fill-in-the-blank answer names an unknown or repeated blank.');
            }

            $filled[$blankId] = true;

            if ($this->matchesAnyAccepted($value['text'], $blanks[$blankId])) {
                $correct++;
            }
        }

        return $this->math->partialPoints($points, $correct, count($blanks));
    }

    private function allOrNothing(string $points, bool $correct): string
    {
        return $this->math->partialPoints($points, $correct ? 1 : 0, 1);
    }

    /** @param list<string> $acceptedAnswers */
    private function matchesAnyAccepted(string $text, array $acceptedAnswers): bool
    {
        if ($acceptedAnswers === []) {
            throw new LogicException('A text answer needs at least one accepted answer.');
        }

        $answer = $this->normalizer->normalize($text);

        foreach ($acceptedAnswers as $accepted) {
            if ($this->normalizer->normalize($accepted) === $answer) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param  list<string>  $ids
     * @return list<string>
     */
    private function uniqueIds(array $ids, string $name): array
    {
        $lower = array_map(strtolower(...), array_values($ids));

        if ($lower === [] || count(array_unique($lower)) !== count($lower)) {
            throw new LogicException("The {$name} ids are empty or repeated.");
        }

        return $lower;
    }

    /**
     * @template T
     *
     * @param  array<array-key, T>  $values
     * @return array<string, T>
     */
    private function byLowerId(array $values, string $name): array
    {
        $byId = [];

        foreach ($values as $id => $value) {
            $byId[strtolower((string) $id)] = $value;
        }

        if ($byId === [] || count($byId) !== count($values)) {
            throw new LogicException("The {$name} set is empty or has repeated ids.");
        }

        return $byId;
    }

    /** @param array<mixed> $answer */
    private function requireAnswered(array $answer): void
    {
        if ($answer === []) {
            throw new LogicException('A saved answer is never empty.');
        }
    }
}
