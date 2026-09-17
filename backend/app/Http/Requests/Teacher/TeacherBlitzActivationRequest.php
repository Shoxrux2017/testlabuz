<?php

namespace App\Http\Requests\Teacher;

final class TeacherBlitzActivationRequest extends TeacherTopicLifecycleRequest
{
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
}
