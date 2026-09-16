<?php

namespace App\Http\Requests\Teacher;

class TeacherBlitzScheduleRequest extends TeacherBlitzMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return ['scheduled_at'];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'scheduled_at' => ['required', 'string', $this->scheduledAtSyntaxRule()],
        ];
    }

    /** @return array{scheduled_at: string} */
    public function scheduledAttributes(): array
    {
        return ['scheduled_at' => $this->validated('scheduled_at')];
    }
}
