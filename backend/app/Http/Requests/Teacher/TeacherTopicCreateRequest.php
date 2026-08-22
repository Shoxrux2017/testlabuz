<?php

namespace App\Http\Requests\Teacher;

use App\Support\Teacher\InstitutionLessonAt;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class TeacherTopicCreateRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = [
        'group_id',
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
            'group_id' => ['required', 'string', 'uuid'],
            'title' => ['required', 'string', 'min:1', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'subject' => ['required', 'string', 'min:1', 'max:160'],
            'student_instructions' => ['required', 'string', 'min:1'],
            'lesson_at' => ['sometimes', 'nullable', 'string', $this->lessonAtSyntaxRule()],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownJsonKeys = array_values(array_diff(array_keys($this->validationData()), self::ACCEPTED_INPUT_KEYS));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($unknownJsonKeys, $queryKeys): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
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
     * @return array{
     *     group_id: string,
     *     title: string,
     *     description: ?string,
     *     subject: string,
     *     student_instructions: string,
     *     lesson_at: ?string
     * }
     */
    public function topicAttributes(): array
    {
        return [
            'group_id' => (string) $this->validated('group_id'),
            'title' => (string) $this->validated('title'),
            'description' => $this->nullableString('description'),
            'subject' => (string) $this->validated('subject'),
            'student_instructions' => (string) $this->validated('student_instructions'),
            'lesson_at' => $this->nullableString('lesson_at'),
        ];
    }

    private function nullableString(string $field): ?string
    {
        $value = $this->validated($field);

        return is_string($value) ? $value : null;
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
