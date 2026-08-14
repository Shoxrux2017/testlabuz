<?php

namespace App\Http\Requests\Institution;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class InstitutionUserUpdateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = [
        'full_name',
        'email',
        'phone',
    ];

    private const FULL_NAME_MAX_LENGTH = 200;

    private const EMAIL_MAX_LENGTH = 254;

    private const PHONE_MAX_LENGTH = 50;

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $rawJson = $this->rawJsonObject();

        if (! $this->hasApplicationJsonContentType() || ! $rawJson instanceof stdClass) {
            return;
        }

        foreach (['full_name', 'phone'] as $field) {
            if (! property_exists($rawJson, $field)) {
                continue;
            }

            $value = $rawJson->{$field};

            if (is_string($value)) {
                $this->json()->set($field, trim($value));
            }
        }

        if (property_exists($rawJson, 'email')) {
            $this->json()->set('email', $rawJson->email);
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function validationData(): array
    {
        if (! $this->hasJsonObjectBody()) {
            return [];
        }

        return $this->json()->all();
    }

    /**
     * @return array<string, list<mixed>>
     */
    public function rules(): array
    {
        return [
            'full_name' => ['sometimes', 'required', 'string', 'min:1', 'max:'.self::FULL_NAME_MAX_LENGTH],
            'email' => ['sometimes', 'nullable', 'string', 'email', 'max:'.self::EMAIL_MAX_LENGTH],
            'phone' => ['sometimes', 'nullable', 'string', 'min:1', 'max:'.self::PHONE_MAX_LENGTH],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $requestKeys = array_keys($this->validationData());
        $unknownJsonKeys = array_values(array_diff($requestKeys, self::ACCEPTED_INPUT_KEYS));
        $acceptedJsonKeys = array_values(array_intersect($requestKeys, self::ACCEPTED_INPUT_KEYS));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($unknownJsonKeys, $acceptedJsonKeys, $queryKeys): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            if ($this->hasJsonObjectBody() && $acceptedJsonKeys === []) {
                $validator->errors()->add('body', 'At least one institution user profile field is required.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
            }

            foreach (['email', 'phone'] as $field) {
                if ($this->rawNullableStringIsEmpty($field)) {
                    $validator->errors()->add($field, "The {$field} field must not be empty when present.");
                }
            }
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function profileAttributes(): array
    {
        $validated = $this->validated();
        $attributes = [];

        foreach (self::ACCEPTED_INPUT_KEYS as $field) {
            if (array_key_exists($field, $validated)) {
                $attributes[$field] = $validated[$field];
            }
        }

        return $attributes;
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

    private function rawNullableStringIsEmpty(string $field): bool
    {
        $rawJson = $this->rawJsonObject();

        return $rawJson instanceof stdClass
            && property_exists($rawJson, $field)
            && is_string($rawJson->{$field})
            && trim($rawJson->{$field}) === '';
    }

    private function rawJsonObject(): ?stdClass
    {
        $content = trim($this->getContent());

        if ($content === '') {
            return null;
        }

        try {
            $decoded = json_decode($content, associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return null;
        }

        return $decoded instanceof stdClass ? $decoded : null;
    }
}
