<?php

namespace App\Http\Requests\Platform;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class PlatformInstitutionCreateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = [
        'name',
        'type',
        'contact_email',
        'contact_phone',
        'address',
        'description',
        'status',
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
            'name' => ['required', 'string', 'max:'.self::NAME_MAX_LENGTH],
            'type' => ['required', 'string', Rule::in(InstitutionType::values())],
            'contact_email' => ['sometimes', 'nullable', 'string', 'email', 'max:'.self::CONTACT_EMAIL_MAX_LENGTH],
            'contact_phone' => ['sometimes', 'nullable', 'string', 'max:'.self::CONTACT_PHONE_MAX_LENGTH],
            'address' => ['sometimes', 'nullable', 'string'],
            'description' => ['sometimes', 'nullable', 'string'],
            'status' => ['required', 'string', Rule::in(InstitutionStatus::values())],
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
        });
    }

    public function name(): string
    {
        return (string) $this->validated('name');
    }

    public function type(): InstitutionType
    {
        return InstitutionType::from((string) $this->validated('type'));
    }

    public function status(): InstitutionStatus
    {
        return InstitutionStatus::from((string) $this->validated('status'));
    }

    public function contactEmail(): ?string
    {
        return $this->nullableString('contact_email');
    }

    public function contactPhone(): ?string
    {
        return $this->nullableString('contact_phone');
    }

    public function address(): ?string
    {
        return $this->nullableString('address');
    }

    public function description(): ?string
    {
        return $this->nullableString('description');
    }

    private function nullableString(string $field): ?string
    {
        $value = $this->validated($field);

        return is_string($value) ? $value : null;
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
