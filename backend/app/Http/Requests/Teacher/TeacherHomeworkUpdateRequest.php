<?php

namespace App\Http\Requests\Teacher;

class TeacherHomeworkUpdateRequest extends TeacherHomeworkMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return self::COMMON_INPUT_KEYS;
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return $this->commonRules(required: false);
    }

    protected function requiresAtLeastOneField(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function homeworkAttributes(): array
    {
        $attributes = $this->validatedCommonAttributes();

        if (isset($attributes['student_ids']) && is_array($attributes['student_ids'])) {
            $attributes['student_ids'] = array_map(strtolower(...), $attributes['student_ids']);
        }

        return $attributes;
    }
}
