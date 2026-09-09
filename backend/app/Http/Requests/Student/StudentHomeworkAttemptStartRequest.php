<?php

namespace App\Http\Requests\Student;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class StudentHomeworkAttemptStartRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return ['idempotency_key' => $this->header('Idempotency-Key')];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return ['idempotency_key' => ['required', 'string', 'uuid']];
    }

    public function idempotencyKey(): string
    {
        return strtolower($this->validated('idempotency_key'));
    }

    public function withValidator(Validator $validator): void
    {
        $hasValidBody = $this->getContent() === '' || $this->hasEmptyJsonObjectBody();
        $queryKeys = array_keys($this->query->all());

        $validator->after(function (Validator $validator) use ($hasValidBody, $queryKeys): void {
            if (! $hasValidBody) {
                $validator->errors()->add('body', 'The request body must be empty or an empty application/json object.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }
        });
    }

    private function hasEmptyJsonObjectBody(): bool
    {
        $contentType = strtolower(trim((string) $this->headers->get('CONTENT_TYPE')));

        if (trim(explode(';', $contentType, 2)[0]) !== 'application/json') {
            return false;
        }

        try {
            $decoded = json_decode($this->getContent(), associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return false;
        }

        return $decoded instanceof stdClass && get_object_vars($decoded) === [];
    }
}
