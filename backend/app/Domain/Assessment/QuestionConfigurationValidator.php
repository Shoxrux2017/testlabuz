<?php

namespace App\Domain\Assessment;

use App\Enums\FileExtension;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use InvalidArgumentException;

final class QuestionConfigurationValidator
{
    public function __construct(
        private readonly QuestionPositionSetValidator $positionSetValidator = new QuestionPositionSetValidator,
    ) {}

    /** @param array<string, mixed> $configuration */
    public function validate(
        QuestionType $type,
        QuestionCheckingMode $checkingMode,
        string $prompt,
        array $configuration,
    ): void {
        if (trim($prompt) === '' || mb_strlen($prompt) > QuestionAuthoringLimits::MAX_PROMPT_LENGTH) {
            throw $this->invalidConfiguration();
        }

        $this->validateCheckingMode($type, $checkingMode);

        match ($type) {
            QuestionType::SingleChoice => $this->validateChoice($configuration, true),
            QuestionType::MultipleChoice => $this->validateChoice($configuration, false),
            QuestionType::TrueFalse => $this->validateTrueFalse($configuration),
            QuestionType::ShortWritten => $this->validateShortWritten($checkingMode, $configuration),
            QuestionType::OpenWritten => $this->validateEmpty($configuration),
            QuestionType::FileBased => $this->validateFileBased($configuration),
            QuestionType::Matching => $this->validateMatching($configuration),
            QuestionType::Ordering => $this->validateOrdering($configuration),
            QuestionType::FillInBlank => $this->validateFillInBlank($prompt, $configuration),
        };
    }

    private function validateCheckingMode(QuestionType $type, QuestionCheckingMode $mode): void
    {
        $allowed = match ($type) {
            QuestionType::ShortWritten => [QuestionCheckingMode::Automatic, QuestionCheckingMode::Manual],
            QuestionType::OpenWritten, QuestionType::FileBased => [QuestionCheckingMode::Manual],
            default => [QuestionCheckingMode::Automatic],
        };

        if (! in_array($mode, $allowed, true)) {
            throw $this->invalidConfiguration();
        }
    }

    /** @param array<string, mixed> $configuration */
    private function validateChoice(array $configuration, bool $singleCorrect): void
    {
        if (! $this->hasExactKeys($configuration, ['options'])
            || ! $this->isList($configuration['options'])) {
            throw $this->invalidConfiguration();
        }

        $options = $configuration['options'];

        if (count($options) < 2 || count($options) > QuestionAuthoringLimits::MAX_CHOICE_OPTIONS) {
            throw $this->invalidConfiguration();
        }

        $positions = [];
        $correctCount = 0;

        foreach ($options as $option) {
            if (! is_array($option)
                || ! $this->hasExactKeys($option, ['text', 'is_correct', 'position'])
                || ! $this->validText($option['text'], QuestionAuthoringLimits::MAX_OPTION_TEXT_LENGTH)
                || ! is_bool($option['is_correct'])
                || ! is_int($option['position'])) {
                throw $this->invalidConfiguration();
            }

            $positions[] = $option['position'];
            $correctCount += $option['is_correct'] ? 1 : 0;
        }

        $this->validatePositions($positions, QuestionAuthoringLimits::MAX_CHOICE_OPTIONS);

        if (($singleCorrect && $correctCount !== 1) || (! $singleCorrect && $correctCount < 1)) {
            throw $this->invalidConfiguration();
        }
    }

    /** @param array<string, mixed> $configuration */
    private function validateTrueFalse(array $configuration): void
    {
        if (! $this->hasExactKeys($configuration, ['correct_value'])
            || ! is_bool($configuration['correct_value'])) {
            throw $this->invalidConfiguration();
        }
    }

    /** @param array<string, mixed> $configuration */
    private function validateShortWritten(QuestionCheckingMode $mode, array $configuration): void
    {
        if ($mode === QuestionCheckingMode::Manual) {
            $this->validateEmpty($configuration);

            return;
        }

        if (! $this->hasExactKeys($configuration, ['accepted_answers'])
            || ! $this->isList($configuration['accepted_answers'])) {
            throw $this->invalidConfiguration();
        }

        $answers = $configuration['accepted_answers'];

        if ($answers === [] || count($answers) > QuestionAuthoringLimits::MAX_SHORT_ACCEPTED_ANSWERS) {
            throw $this->invalidConfiguration();
        }

        $seen = [];

        foreach ($answers as $answer) {
            if (! $this->validText($answer, QuestionAuthoringLimits::MAX_ACCEPTED_ANSWER_LENGTH)
                || isset($seen[$answer])) {
                throw $this->invalidConfiguration();
            }

            $seen[$answer] = true;
        }
    }

    /** @param array<string, mixed> $configuration */
    private function validateEmpty(array $configuration): void
    {
        if ($configuration !== []) {
            throw $this->invalidConfiguration();
        }
    }

    /** @param array<string, mixed> $configuration */
    private function validateFileBased(array $configuration): void
    {
        if (! $this->hasExactKeys($configuration, ['allowed_extensions'])
            || $configuration['allowed_extensions'] !== FileExtension::values()) {
            throw $this->invalidConfiguration();
        }
    }

    /** @param array<string, mixed> $configuration */
    private function validateMatching(array $configuration): void
    {
        if (! $this->hasExactKeys($configuration, ['pairs']) || ! $this->isList($configuration['pairs'])) {
            throw $this->invalidConfiguration();
        }

        $pairs = $configuration['pairs'];

        if ($pairs === [] || count($pairs) > QuestionAuthoringLimits::MAX_MATCHING_PAIRS) {
            throw $this->invalidConfiguration();
        }

        $clientKeys = [];

        foreach ($pairs as $pair) {
            if (! is_array($pair)
                || ! $this->hasExactKeys($pair, ['client_key', 'left', 'right'])
                || ! $this->validText($pair['client_key'], QuestionAuthoringLimits::MAX_CLIENT_KEY_LENGTH)
                || ! $this->validText($pair['left'], QuestionAuthoringLimits::MAX_MATCHING_ITEM_TEXT_LENGTH)
                || ! $this->validText($pair['right'], QuestionAuthoringLimits::MAX_MATCHING_ITEM_TEXT_LENGTH)
                || isset($clientKeys[$pair['client_key']])) {
                throw $this->invalidConfiguration();
            }

            $clientKeys[$pair['client_key']] = true;
        }
    }

    /** @param array<string, mixed> $configuration */
    private function validateOrdering(array $configuration): void
    {
        if (! $this->hasExactKeys($configuration, ['items']) || ! $this->isList($configuration['items'])) {
            throw $this->invalidConfiguration();
        }

        $items = $configuration['items'];

        if (count($items) < 2 || count($items) > QuestionAuthoringLimits::MAX_ORDERING_ITEMS) {
            throw $this->invalidConfiguration();
        }

        $positions = [];

        foreach ($items as $item) {
            if (! is_array($item)
                || ! $this->hasExactKeys($item, ['text', 'correct_position'])
                || ! $this->validText($item['text'], QuestionAuthoringLimits::MAX_ORDERING_ITEM_TEXT_LENGTH)
                || ! is_int($item['correct_position'])) {
                throw $this->invalidConfiguration();
            }

            $positions[] = $item['correct_position'];
        }

        $this->validatePositions($positions, QuestionAuthoringLimits::MAX_ORDERING_ITEMS);
    }

    /** @param array<string, mixed> $configuration */
    private function validateFillInBlank(string $prompt, array $configuration): void
    {
        if (! $this->hasExactKeys($configuration, ['blanks']) || ! $this->isList($configuration['blanks'])) {
            throw $this->invalidConfiguration();
        }

        $blanks = $configuration['blanks'];

        if ($blanks === [] || count($blanks) > QuestionAuthoringLimits::MAX_FILL_BLANKS) {
            throw $this->invalidConfiguration();
        }

        $positions = [];
        $keys = [];

        foreach ($blanks as $blank) {
            if (! is_array($blank)
                || ! $this->hasExactKeys($blank, ['key', 'position', 'accepted_answers'])
                || ! is_string($blank['key'])
                || preg_match('/^[A-Za-z][A-Za-z0-9_-]{0,79}$/D', $blank['key']) !== 1
                || isset($keys[$blank['key']])
                || ! is_int($blank['position'])
                || ! $this->isList($blank['accepted_answers'])) {
                throw $this->invalidConfiguration();
            }

            $answers = $blank['accepted_answers'];

            if ($answers === [] || count($answers) > QuestionAuthoringLimits::MAX_ACCEPTED_ANSWERS_PER_BLANK) {
                throw $this->invalidConfiguration();
            }

            $seenAnswers = [];

            foreach ($answers as $answer) {
                if (! $this->validText($answer, QuestionAuthoringLimits::MAX_ACCEPTED_ANSWER_LENGTH)
                    || isset($seenAnswers[$answer])) {
                    throw $this->invalidConfiguration();
                }

                $seenAnswers[$answer] = true;
            }

            $keys[$blank['key']] = true;
            $positions[] = $blank['position'];
        }

        $this->validatePositions($positions, QuestionAuthoringLimits::MAX_FILL_BLANKS);
        preg_match_all('/\{\{([A-Za-z][A-Za-z0-9_-]{0,79})\}\}/', $prompt, $placeholderMatches);
        $placeholderKeys = $placeholderMatches[1];

        if (count($placeholderKeys) !== count($keys)
            || count(array_unique($placeholderKeys)) !== count($placeholderKeys)
            || array_diff($placeholderKeys, array_keys($keys)) !== []
            || array_diff(array_keys($keys), $placeholderKeys) !== []) {
            throw $this->invalidConfiguration();
        }
    }

    /** @param array<array-key, mixed> $value */
    private function isList(mixed $value): bool
    {
        return is_array($value) && array_is_list($value);
    }

    /**
     * @param  array<array-key, mixed>  $value
     * @param  list<string>  $expectedKeys
     */
    private function hasExactKeys(array $value, array $expectedKeys): bool
    {
        $actualKeys = array_keys($value);
        sort($actualKeys);
        sort($expectedKeys);

        return $actualKeys === $expectedKeys;
    }

    private function validText(mixed $value, int $maximumLength): bool
    {
        return is_string($value) && trim($value) !== '' && mb_strlen($value) <= $maximumLength;
    }

    /** @param list<int> $positions */
    private function validatePositions(array $positions, int $maximumCount): void
    {
        try {
            $this->positionSetValidator->validate($positions, $maximumCount);
        } catch (InvalidArgumentException) {
            throw $this->invalidConfiguration();
        }
    }

    private function invalidConfiguration(): InvalidArgumentException
    {
        return new InvalidArgumentException('Invalid question configuration.');
    }
}
