<?php

namespace App\Http\Requests\Institution;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class InstitutionParentStudentRelationshipConnectRequest extends FormRequest
{
    private const ACCEPTED_BODY_KEYS = ['parent_id', 'student_id'];

    public function authorize(): bool
    {
        return true;
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
            'parent_id' => ['required', 'string', 'uuid'],
            'student_id' => ['required', 'string', 'uuid'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $hasJsonObjectBody = $this->hasJsonObjectBody();
        $validationData = $this->validationData();
        $unknownBodyKeys = array_values(array_diff(array_keys($validationData), self::ACCEPTED_BODY_KEYS));
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($hasJsonObjectBody, $unknownBodyKeys, $queryKeys): void {
            if (! $hasJsonObjectBody) {
                $validator->errors()->add('body', 'A valid application/json object body is required.');
            }

            foreach ($unknownBodyKeys as $unknownBodyKey) {
                $validator->errors()->add((string) $unknownBodyKey, 'This field is not allowed.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }
        });
    }

    public function parentId(): string
    {
        return (string) $this->validated('parent_id');
    }

    public function studentId(): string
    {
        return (string) $this->validated('student_id');
    }

    private function hasJsonObjectBody(): bool
    {
        if (! $this->hasApplicationJsonContentType()) {
            return false;
        }

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

    private function hasApplicationJsonContentType(): bool
    {
        $contentType = strtolower(trim((string) $this->headers->get('CONTENT_TYPE')));
        $mediaType = trim(explode(';', $contentType, 2)[0]);

        return $mediaType === 'application/json';
    }
}
