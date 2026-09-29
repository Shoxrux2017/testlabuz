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

    /**
     * @param  array<string, bool>  $options  option id => is correct
     * @param  list<string>  $selectedOptionIds
     */
    public function singleChoice(string $points, array $options, array $selectedOptionIds): string
    {
        $correct = $this->correctOptionIds($options);
        $selected = $this->selectedOptionIds($options, $selectedOptionIds);

        if (count($correct) !== 1 || count($selected) !== 1) {
            throw new LogicException('A single-choice Question has one correct option and one selected option.');
        }

        return $this->allOrNothing($points, $selected[0] === $correct[0]);
    }

    /**
     * BR-Q-009: a wrong selection earns and deducts nothing.
     *
     * @param  array<string, bool>  $options  option id => is correct
     * @param  list<string>  $selectedOptionIds
     */
    public function multipleChoice(string $points, array $options, array $selectedOptionIds): string
    {
        $correct = $this->correctOptionIds($options);
        $selected = $this->selectedOptionIds($options, $selectedOptionIds);

        if ($correct === []) {
            throw new LogicException('A multiple-choice Question needs at least one correct option.');
        }

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

        foreach ($positions as $correctPosition) {
            if (! is_int($correctPosition)) {
                throw new LogicException('An ordering item needs an integer correct position.');
            }
        }

        foreach ($items as $item) {
            $itemId = strtolower($item['item_id']);
            $position = $item['position'];

            if (! is_int($position) || ! array_key_exists($itemId, $positions) || isset($usedItems[$itemId])
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

        foreach ($blanks as $acceptedAnswers) {
            if ($acceptedAnswers === []) {
                throw new LogicException('Every blank needs at least one accepted answer.');
            }
        }

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
     * @param  array<string, bool>  $options
     * @return list<string>
     */
    private function correctOptionIds(array $options): array
    {
        $correct = array_filter($this->byLowerId($options, 'option'), fn (bool $isCorrect): bool => $isCorrect);

        // Array keys that look numeric come back as integers.
        return array_map(strval(...), array_keys($correct));
    }

    /**
     * @param  array<string, bool>  $options
     * @param  list<string>  $selectedOptionIds
     * @return list<string>
     */
    private function selectedOptionIds(array $options, array $selectedOptionIds): array
    {
        $known = $this->byLowerId($options, 'option');
        $selected = array_map(strtolower(...), array_values($selectedOptionIds));

        if ($selected === [] || count(array_unique($selected)) !== count($selected)
            || array_diff($selected, array_keys($known)) !== []) {
            throw new LogicException('The selected options are empty, repeated or not options of the Question.');
        }

        return $selected;
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
