<?php

namespace App\Http\Requests\Teacher;

use App\Support\Teacher\InstitutionLessonAt;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class TeacherTopicUpdateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = [
        'title',
        'description',
        'subject',
        'student_instructions',
        'lesson_at',
    ];

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

        foreach (['title', 'subject', 'student_instructions'] as $field) {
            if (property_exists($rawJson, $field) && is_string($rawJson->{$field})) {
                $this->json()->set($field, trim($rawJson->{$field}));
            }
        }
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return $this->hasJsonObjectBody() ? $this->json()->all() : [];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'title' => ['sometimes', 'required', 'string', 'min:1', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'subject' => ['sometimes', 'required', 'string', 'min:1', 'max:160'],
            'student_instructions' => ['sometimes', 'required', 'string', 'min:1'],
            'lesson_at' => ['sometimes', 'nullable', 'string', $this->lessonAtSyntaxRule()],
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
                $validator->errors()->add('body', 'At least one topic field is required.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
            }
        });
    }

    /** @return array<string, string|null> */
    public function topicAttributes(): array
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

    private function lessonAtSyntaxRule(): Closure
    {
        return static function (string $attribute, mixed $value, Closure $fail): void {
            if (is_string($value) && ! InstitutionLessonAt::hasValidSyntax($value)) {
                $fail('The lesson_at must be an RFC 3339 date-time with an explicit numeric offset.');
            }
        };
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
