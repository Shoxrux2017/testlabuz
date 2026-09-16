<?php

namespace App\Http\Requests\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Support\Assessment\TeacherAssessmentQuestionPayloadValidator;
use App\Support\Teacher\InstitutionBlitzScheduledAt;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

abstract class TeacherBlitzMutationRequest extends FormRequest
{
    protected const COMMON_INPUT_KEYS = [
        'title',
        'description',
        'student_instructions',
        'assignment_mode',
        'student_ids',
        'duration_seconds',
    ];

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
        $rawBody = $this->rawJsonObject();

        if (! $this->hasApplicationJsonContentType() || ! $rawBody instanceof stdClass) {
            return [];
        }

        /** @var array<string, mixed> $payload */
        $payload = json_decode($this->getContent(), true, flags: JSON_THROW_ON_ERROR);

        foreach (['title', 'student_instructions'] as $field) {
            if (isset($payload[$field]) && is_string($payload[$field])) {
                $payload[$field] = trim($payload[$field]);
            }
        }

        if (isset($payload['questions']) && is_array($payload['questions'])) {
            foreach ($payload['questions'] as $index => $question) {
                if (is_array($question) && isset($question['prompt']) && is_string($question['prompt'])) {
                    $payload['questions'][$index]['prompt'] = trim($question['prompt']);
                }
            }
        }

        return $payload;
    }

    public function withValidator(Validator $validator): void
    {
        $requestKeys = array_keys($this->validationData());
        $acceptedInputKeys = $this->acceptedInputKeys();
        $unknownJsonKeys = array_values(array_diff($requestKeys, $acceptedInputKeys));
        $acceptedJsonKeys = array_values(array_intersect($requestKeys, $acceptedInputKeys));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($unknownJsonKeys, $acceptedJsonKeys, $queryKeys): void {
            if (! $this->hasJsonObjectBody()) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            }

            if ($this->requiresAtLeastOneField() && $this->hasJsonObjectBody() && $acceptedJsonKeys === []) {
                $validator->errors()->add('body', 'At least one Blitz field is required.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownJsonKeys as $unknownJsonKey) {
                $validator->errors()->add((string) $unknownJsonKey, 'This field is not allowed.');
            }

            $this->validateRawArrayFields($validator);
            $this->validateStudentIdSet($validator);
            $this->validateQuestions($validator);
            $this->validateCreateAssignmentRules($validator);
        });
    }

    protected function commonRules(bool $required): array
    {
        $presence = $required ? ['required'] : ['sometimes', 'required'];

        return [
            'title' => [...$presence, 'string', 'min:1', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:10000'],
            'student_instructions' => [...$presence, 'string', 'min:1', 'max:10000'],
            'assignment_mode' => [...$presence, 'string', Rule::in(AssessmentAssignmentMode::values())],
            'student_ids' => [$required ? 'present' : 'sometimes', 'array'],
            'student_ids.*' => ['required', 'string', 'uuid'],
            'duration_seconds' => [...$presence, 'integer', 'min:1', 'max:2147483647'],
        ];
    }

    protected function requiresAtLeastOneField(): bool
    {
        return false;
    }

    protected function validatesQuestions(): bool
    {
        return false;
    }

    protected function validatesCreateAssignmentRules(): bool
    {
        return false;
    }

    /** @return array<string, mixed> */
    protected function validatedCommonAttributes(): array
    {
        $validated = $this->validated();
        $attributes = [];

        foreach (self::COMMON_INPUT_KEYS as $field) {
            if (array_key_exists($field, $validated)) {
                $attributes[$field] = $validated[$field];
            }
        }

        return $attributes;
    }

    protected function scheduledAtSyntaxRule(): Closure
    {
        return static function (string $attribute, mixed $value, Closure $fail): void {
            if (is_string($value) && ! InstitutionBlitzScheduledAt::hasValidSyntax($value)) {
                $fail('The scheduled_at must be an RFC 3339 date-time with an explicit numeric offset.');
            }
        };
    }

    private function validateStudentIdSet(Validator $validator): void
    {
        $studentIds = $this->validationData()['student_ids'] ?? null;

        if (! is_array($studentIds) || ! array_is_list($studentIds)) {
            return;
        }

        $normalized = [];

        foreach ($studentIds as $studentId) {
            if (! is_string($studentId)) {
                return;
            }

            $canonical = strtolower($studentId);

            if (isset($normalized[$canonical])) {
                $validator->errors()->add('student_ids', 'The student_ids must not contain duplicates.');

                return;
            }

            $normalized[$canonical] = true;
        }
    }

    private function validateRawArrayFields(Validator $validator): void
    {
        $rawBody = $this->rawJsonObject();

        if (! $rawBody instanceof stdClass) {
            return;
        }

        if (property_exists($rawBody, 'duration_seconds') && ! is_int($rawBody->duration_seconds)) {
            $validator->errors()->add('duration_seconds', 'The duration_seconds must be a JSON integer.');
        }

        if (property_exists($rawBody, 'student_ids') && ! is_array($rawBody->student_ids)) {
            $validator->errors()->add('student_ids', 'The student_ids must be a JSON array.');
        }

        if ($this->validatesQuestions()
            && property_exists($rawBody, 'questions')
            && ! is_array($rawBody->questions)) {
            $validator->errors()->add('questions', 'The questions must be a JSON array.');
        }
    }

    private function validateCreateAssignmentRules(Validator $validator): void
    {
        if (! $this->validatesCreateAssignmentRules()) {
            return;
        }

        $payload = $this->validationData();
        $mode = $payload['assignment_mode'] ?? null;
        $studentIds = $payload['student_ids'] ?? null;

        if ($mode === AssessmentAssignmentMode::Group->value && $studentIds !== []) {
            $validator->errors()->add('student_ids', 'Group Blitz requires an empty student_ids array.');
        }

        if ($mode === AssessmentAssignmentMode::SelectedStudents->value
            && (! is_array($studentIds) || $studentIds === [])) {
            $validator->errors()->add('student_ids', 'Selected-student Blitz requires at least one student ID.');
        }
    }

    private function validateQuestions(Validator $validator): void
    {
        if ($this->validatesQuestions()) {
            (new TeacherAssessmentQuestionPayloadValidator)->validate($this->rawJsonObject(), $validator);
        }
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
