<?php

namespace App\Http\Requests\Platform;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class PlatformInstitutionAdminCreateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = [
        'full_name',
        'login_name',
        'email',
        'phone',
        'password',
    ];

    private const FULL_NAME_MAX_LENGTH = 200;

    private const LOGIN_NAME_MAX_LENGTH = 191;

    private const EMAIL_MAX_LENGTH = 254;

    private const PHONE_MAX_LENGTH = 50;

    private const PASSWORD_MIN_LENGTH = 8;

    private const PASSWORD_MAX_LENGTH = 255;

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if (! $this->hasJsonObjectBody()) {
            return;
        }

        foreach (['full_name', 'login_name', 'phone'] as $field) {
            $value = $this->json($field);

            if (is_string($value)) {
                $this->json()->set($field, trim($value));
            }
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
            'full_name' => ['required', 'string', 'min:1', 'max:'.self::FULL_NAME_MAX_LENGTH],
            'login_name' => [
                'required',
                'string',
                'min:1',
                'max:'.self::LOGIN_NAME_MAX_LENGTH,
                Rule::unique('users', 'login_name'),
            ],
            'email' => ['sometimes', 'nullable', 'string', 'email', 'max:'.self::EMAIL_MAX_LENGTH],
            'phone' => ['sometimes', 'nullable', 'string', 'min:1', 'max:'.self::PHONE_MAX_LENGTH],
            'password' => ['required', 'string', 'min:'.self::PASSWORD_MIN_LENGTH, 'max:'.self::PASSWORD_MAX_LENGTH],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownJsonKeys = array_values(array_diff(array_keys($this->validationData()), self::ACCEPTED_INPUT_KEYS));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($unknownJsonKeys, $queryKeys): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be a JSON object.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
            }

            if ($this->rawPhoneIsEmptyString()) {
                $validator->errors()->add('phone', 'The phone field must not be empty when present.');
            }
        });
    }

    public function fullName(): string
    {
        return (string) $this->validated('full_name');
    }

    public function loginName(): string
    {
        return (string) $this->validated('login_name');
    }

    public function email(): ?string
    {
        return $this->nullableString('email');
    }

    public function phone(): ?string
    {
        return $this->nullableString('phone');
    }

    public function password(): string
    {
        return (string) $this->validated('password');
    }

    private function nullableString(string $field): ?string
    {
        $value = $this->validated($field);

        return is_string($value) ? $value : null;
    }

    private function hasJsonObjectBody(): bool
    {
        return $this->rawJsonObject() instanceof stdClass;
    }

    private function rawPhoneIsEmptyString(): bool
    {
        $rawJson = $this->rawJsonObject();

        return $rawJson instanceof stdClass
            && property_exists($rawJson, 'phone')
            && is_string($rawJson->phone)
            && trim($rawJson->phone) === '';
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
