<?php

namespace App\Http\Requests\Teacher;

use App\Enums\BlitzAttemptExceptionReasonType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use JsonException;
use stdClass;

final class TeacherBlitzAttemptExceptionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function validationData(): array
    {
        $body = $this->jsonObjectBody();

        return [
            'idempotency_key' => $this->header('Idempotency-Key'),
            'reason_type' => $body->reason_type ?? null,
            'reason' => is_string($body->reason ?? null) ? trim($body->reason) : ($body->reason ?? null),
        ];
    }

    public function rules(): array
    {
        return [
            'idempotency_key' => ['required', 'string', 'uuid'],
            'reason_type' => ['required', 'string', Rule::enum(BlitzAttemptExceptionReasonType::class)],
            'reason' => ['required', 'string', 'max:4000'],
        ];
    }

    public function idempotencyKey(): string
    {
        return strtolower($this->validated('idempotency_key'));
    }

    public function reasonAttributes(): array
    {
        return $this->safe()->only(['reason_type', 'reason']);
    }

    public function withValidator(Validator $validator): void
    {
        $body = $this->jsonObjectBody();
        $validator->after(function (Validator $validator) use ($body): void {
            if ($body === null) {
                $validator->errors()->add('body', 'The request body must be an application/json object.');
            } else {
                foreach (array_diff(array_keys(get_object_vars($body)), ['reason_type', 'reason']) as $key) {
                    $validator->errors()->add($key, 'This field is not allowed.');
                }
            }
            foreach (array_keys($this->query->all()) as $key) {
                $validator->errors()->add((string) $key, 'Query parameters are not allowed for this endpoint.');
            }
        });
    }

    private function jsonObjectBody(): ?stdClass
    {
        if (trim(explode(';', strtolower((string) $this->header('Content-Type')), 2)[0]) !== 'application/json') {
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
