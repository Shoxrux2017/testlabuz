<?php

namespace App\Support\Assessment;

use App\Domain\Assessment\AssessmentPointMath;
use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Domain\Assessment\QuestionPositionSetValidator;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use Illuminate\Validation\Validator;
use InvalidArgumentException;
use stdClass;

final class TeacherAssessmentQuestionPayloadValidator
{
    public function validate(mixed $rawBody, Validator $validator): void
    {
        if (! $rawBody instanceof stdClass || ! property_exists($rawBody, 'questions')) {
            return;
        }

        if (! is_array($rawBody->questions)) {
            return;
        }

        $positions = [];
        $clientKeys = [];
        $configurationValidator = new QuestionConfigurationValidator;

        foreach ($rawBody->questions as $index => $rawQuestion) {
            $path = 'questions.'.$index;

            if (! $rawQuestion instanceof stdClass || ! $this->hasValidQuestionKeys($rawQuestion)) {
                $validator->errors()->add($path, 'Each Question must be an object with exactly the allowed fields.');

                continue;
            }

            if (! is_string($rawQuestion->client_key)
                || preg_match('/\A[A-Za-z][A-Za-z0-9_-]{0,79}\z/D', $rawQuestion->client_key) !== 1
                || isset($clientKeys[$rawQuestion->client_key])) {
                $validator->errors()->add($path.'.client_key', 'The client_key is invalid or duplicated.');
            } else {
                $clientKeys[$rawQuestion->client_key] = true;
            }

            $type = is_string($rawQuestion->type) ? QuestionType::tryFrom($rawQuestion->type) : null;
            $checkingMode = is_string($rawQuestion->checking_mode)
                ? QuestionCheckingMode::tryFrom($rawQuestion->checking_mode)
                : null;
            $prompt = is_string($rawQuestion->prompt) ? trim($rawQuestion->prompt) : null;

            if (! $type instanceof QuestionType) {
                $validator->errors()->add($path.'.type', 'The Question type is invalid.');
            }

            if (! $checkingMode instanceof QuestionCheckingMode) {
                $validator->errors()->add($path.'.checking_mode', 'The Question checking_mode is invalid.');
            }

            if (! is_string($prompt) || $prompt === '' || mb_strlen($prompt) > QuestionAuthoringLimits::MAX_PROMPT_LENGTH) {
                $validator->errors()->add($path.'.prompt', 'The Question prompt is invalid.');
            }

            $instructions = property_exists($rawQuestion, 'instructions') ? $rawQuestion->instructions : null;

            if ($instructions !== null
                && (! is_string($instructions)
                    || trim($instructions) === ''
                    || mb_strlen($instructions) > QuestionAuthoringLimits::MAX_INSTRUCTIONS_LENGTH)) {
                $validator->errors()->add($path.'.instructions', 'The Question instructions are invalid.');
            }

            if ((! is_int($rawQuestion->points) && ! is_float($rawQuestion->points))
                || ! $this->hasValidPointScale($rawQuestion->points)) {
                $validator->errors()->add($path.'.points', 'The Question points must be a valid JSON number with at most six fractional digits.');
            }

            if (! is_int($rawQuestion->position)) {
                $validator->errors()->add($path.'.position', 'The Question position must be a JSON integer.');
            } else {
                $positions[] = $rawQuestion->position;
            }

            if (! $rawQuestion->configuration instanceof stdClass) {
                $validator->errors()->add($path.'.configuration', 'The Question configuration must be a JSON object.');

                continue;
            }

            if ($this->containsArrayLikeJsonObject($rawQuestion->configuration)) {
                $validator->errors()->add($path.'.configuration', 'JSON arrays and objects must use their required distinct shapes.');

                continue;
            }

            if ($type instanceof QuestionType && $checkingMode instanceof QuestionCheckingMode && is_string($prompt)) {
                /** @var array<string, mixed> $configuration */
                $configuration = json_decode(json_encode($rawQuestion->configuration, JSON_THROW_ON_ERROR), true, flags: JSON_THROW_ON_ERROR);

                try {
                    $configurationValidator->validate($type, $checkingMode, $prompt, $configuration);
                } catch (InvalidArgumentException) {
                    $validator->errors()->add($path.'.configuration', 'The Question configuration is invalid.');
                }
            }
        }

        try {
            (new QuestionPositionSetValidator)->validate(
                $positions,
                QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT,
                allowEmpty: true,
            );
        } catch (InvalidArgumentException) {
            $validator->errors()->add('questions', 'Question positions must be the exact contiguous set 1..N.');
        }
    }

    private function hasValidPointScale(int|float $points): bool
    {
        try {
            AssessmentPointMath::normalize($points);

            return true;
        } catch (InvalidArgumentException) {
            return false;
        }
    }

    private function hasValidQuestionKeys(stdClass $question): bool
    {
        $actualKeys = array_keys(get_object_vars($question));
        $requiredKeys = ['client_key', 'type', 'prompt', 'points', 'position', 'checking_mode', 'configuration'];
        $allowedKeys = [...$requiredKeys, 'instructions'];
        sort($actualKeys);
        sort($allowedKeys);

        return array_diff($actualKeys, $allowedKeys) === []
            && array_diff($requiredKeys, $actualKeys) === [];
    }

    private function containsArrayLikeJsonObject(mixed $value): bool
    {
        if (is_array($value)) {
            foreach ($value as $item) {
                if ($this->containsArrayLikeJsonObject($item)) {
                    return true;
                }
            }

            return false;
        }

        if (! $value instanceof stdClass) {
            return false;
        }

        $properties = get_object_vars($value);
        $keys = array_keys($properties);

        if ($keys !== [] && array_filter($keys, static fn (string|int $key): bool => ! ctype_digit((string) $key)) === []) {
            return true;
        }

        foreach ($properties as $property) {
            if ($this->containsArrayLikeJsonObject($property)) {
                return true;
            }
        }

        return false;
    }
}
