<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Domain\Assessment\QuestionAuthoringLimits;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use InvalidArgumentException;
use JsonException;
use stdClass;

abstract class TeacherQuestionMutationRequest extends FormRequest
{
    private bool $rawBodyDecoded = false;

    private mixed $rawBody = null;

    public function authorize(): bool
    {
        return true;
    }

    /** @return list<string> */
    abstract protected function acceptedInputKeys(): array;

    /** @return array<string, list<mixed>> */
    abstract public function rules(): array;

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        if (! $this->hasApplicationJsonContentType() || ! $this->rawJsonObject() instanceof stdClass) {
            return [];
        }

        /** @var array<string, mixed> $payload */
        $payload = json_decode($this->getContent(), true, flags: JSON_THROW_ON_ERROR);

        if (isset($payload['prompt']) && is_string($payload['prompt'])) {
            $payload['prompt'] = trim($payload['prompt']);
        }

        return $payload;
    }

    public function withValidator(Validator $validator): void
    {
        $payload = $this->validationData();
        $requestKeys = array_keys($payload);
        $acceptedInputKeys = $this->acceptedInputKeys();
        $unknownJsonKeys = array_values(array_diff($requestKeys, $acceptedInputKeys));
        $acceptedJsonKeys = array_values(array_intersect($requestKeys, $acceptedInputKeys));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use (
            $payload,
            $unknownJsonKeys,
            $acceptedJsonKeys,
            $queryKeys,
        ): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            if ($this->requiresAtLeastOneField() && $this->hasJsonObjectBody() && $acceptedJsonKeys === []) {
                $validator->errors()->add('body', 'At least one Question field is required.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
            }

            $this->validateStrictJsonTypes($validator);
            $this->validateSpecific($validator, $payload);
        });
    }

    protected function requiresAtLeastOneField(): bool
    {
        return false;
    }

    /** @param array<string, mixed> $payload */
    protected function validateSpecific(Validator $validator, array $payload): void {}

    /** @return array<string, mixed> */
    protected function validatedQuestionAttributes(): array
    {
        $validated = $this->validated();
        $attributes = [];

        foreach ($this->acceptedInputKeys() as $field) {
            if (array_key_exists($field, $validated)) {
                $attributes[$field] = $validated[$field];
            }
        }

        return $attributes;
    }

    private function validateStrictJsonTypes(Validator $validator): void
    {
        $rawBody = $this->rawJsonObject();

        if (! $rawBody instanceof stdClass) {
            return;
        }

        if (property_exists($rawBody, 'configuration')) {
            if (! $rawBody->configuration instanceof stdClass) {
                $validator->errors()->add('configuration', 'The Question configuration must be a JSON object.');
            } elseif ($this->containsArrayLikeJsonObject($rawBody->configuration)) {
                $validator->errors()->add('configuration', 'JSON arrays and objects must use their required distinct shapes.');
            }
        }

        if (property_exists($rawBody, 'points')
            && ((! is_int($rawBody->points) && ! is_float($rawBody->points))
                || ! $this->hasValidPointScale($rawBody->points))) {
            $validator->errors()->add(
                'points',
                'The Question points must be a valid JSON number with at most six fractional digits.',
            );
        }

        if (property_exists($rawBody, 'position') && ! is_int($rawBody->position)) {
            $validator->errors()->add('position', 'The Question position must be a JSON integer.');
        }

        if (property_exists($rawBody, 'instructions')
            && $rawBody->instructions !== null
            && (! is_string($rawBody->instructions)
                || trim($rawBody->instructions) === ''
                || mb_strlen($rawBody->instructions) > QuestionAuthoringLimits::MAX_INSTRUCTIONS_LENGTH)) {
            $validator->errors()->add('instructions', 'The Question instructions are invalid.');
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

        if ($keys !== [] && array_filter($keys, static fn (string $key): bool => ! ctype_digit($key)) === []) {
            return true;
        }

        foreach ($properties as $property) {
            if ($this->containsArrayLikeJsonObject($property)) {
                return true;
            }
        }

        return false;
    }

    private function hasJsonObjectBody(): bool
    {
        return $this->hasApplicationJsonContentType() && $this->rawJsonObject() instanceof stdClass;
    }

    private function hasApplicationJsonContentType(): bool
    {
        $contentType = strtolower(trim((string) $this->headers->get('CONTENT_TYPE')));
        $mediaType = trim(explode(';', $contentType, 2)[0]);

        return $mediaType === 'application/json';
    }

    private function rawJsonObject(): mixed
    {
        if ($this->rawBodyDecoded) {
            return $this->rawBody;
        }

        $this->rawBodyDecoded = true;
        $content = trim($this->getContent());

        if ($content === '') {
            return null;
        }

        try {
            return $this->rawBody = json_decode($content, associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return null;
        }
    }
}
