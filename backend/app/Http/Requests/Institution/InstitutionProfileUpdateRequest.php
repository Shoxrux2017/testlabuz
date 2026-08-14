<?php

namespace App\Http\Requests\Institution;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class InstitutionProfileUpdateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = [
        'name',
        'contact_email',
        'contact_phone',
        'address',
        'description',
    ];

    private const NAME_MAX_LENGTH = 200;

    private const CONTACT_EMAIL_MAX_LENGTH = 254;

    private const CONTACT_PHONE_MAX_LENGTH = 50;

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if (! $this->hasJsonObjectBody()) {
            return;
        }

        $name = $this->json('name');

        if (is_string($name)) {
            $this->json()->set('name', trim($name));
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
            'name' => ['sometimes', 'required', 'string', 'max:'.self::NAME_MAX_LENGTH],
            'contact_email' => ['sometimes', 'nullable', 'string', 'email', 'max:'.self::CONTACT_EMAIL_MAX_LENGTH],
            'contact_phone' => ['sometimes', 'nullable', 'string', 'max:'.self::CONTACT_PHONE_MAX_LENGTH],
            'address' => ['sometimes', 'nullable', 'string'],
            'description' => ['sometimes', 'nullable', 'string'],
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
                $validator->errors()->add('body', 'The request body must be a JSON object.');
            }

            if ($this->hasJsonObjectBody() && $acceptedJsonKeys === []) {
                $validator->errors()->add('body', 'At least one institution profile field is required.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
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

        foreach (self::ACCEPTED_INPUT_KEYS as $attribute) {
            if (array_key_exists($attribute, $validated)) {
                $attributes[$attribute] = $validated[$attribute];
            }
        }

        return $attributes;
    }

    private function hasJsonObjectBody(): bool
    {
        $content = trim($this->getContent());

        if ($content === '') {
            return false;
        }

        try {
            $decoded = json_decode($content, associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return false;
        }

        return $decoded instanceof stdClass;
    }
}
