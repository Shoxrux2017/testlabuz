<?php

namespace App\Http\Requests\Student;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

class StudentBlitzAttemptStartRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        $body = $this->jsonObjectBody();

        return [
            'idempotency_key' => $this->header('Idempotency-Key'),
            'intent' => $body->intent ?? null,
            'attempt_id' => $body->attempt_id ?? null,
        ];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'idempotency_key' => ['required', 'string', 'uuid'],
            'intent' => ['required', 'string', Rule::in(['start_normal', 'resume'])],
            'attempt_id' => ['required_if:intent,resume', 'nullable', 'string', 'uuid', 'regex:/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i'],
        ];
    }

    public function idempotencyKey(): string
    {
        return strtolower($this->validated('idempotency_key'));
    }

    public function intent(): string
    {
        return $this->validated('intent');
    }

    public function attemptId(): ?string
    {
        $attemptId = $this->validated('attempt_id');

        return $attemptId === null ? null : strtolower($attemptId);
    }

    public function withValidator(Validator $validator): void
    {
        $body = $this->jsonObjectBody();

        $validator->after(function (Validator $validator) use ($body): void {
            if ($body === null) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            } else {
                $allowedKeys = ($body->intent ?? null) === 'resume' ? ['intent', 'attempt_id'] : ['intent'];

                foreach (array_diff(array_keys(get_object_vars($body)), $allowedKeys) as $key) {
                    $validator->errors()->add($key, 'This field is not allowed for the requested intent.');
                }
            }

            foreach (array_keys($this->query->all()) as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }
        });
    }

    private function jsonObjectBody(): ?stdClass
    {
        $contentType = strtolower(trim((string) $this->headers->get('CONTENT_TYPE')));

        if (trim(explode(';', $contentType, 2)[0]) !== 'application/json') {
            return null;
        }

        try {
            $body = json_decode($this->getContent(), associative: false, flags: JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return null;
        }

        return $body instanceof stdClass ? $body : null;
    }
}
