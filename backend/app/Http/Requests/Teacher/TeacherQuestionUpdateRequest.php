<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use Illuminate\Validation\Rule;

class TeacherQuestionUpdateRequest extends TeacherQuestionMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return ['type', 'prompt', 'instructions', 'points', 'checking_mode', 'configuration'];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'type' => ['sometimes', 'string', Rule::in(QuestionType::values())],
            'prompt' => ['sometimes', 'string', 'min:1', 'max:'.QuestionAuthoringLimits::MAX_PROMPT_LENGTH],
            'instructions' => ['sometimes', 'nullable', 'string', 'max:'.QuestionAuthoringLimits::MAX_INSTRUCTIONS_LENGTH],
            'points' => ['sometimes'],
            'checking_mode' => ['sometimes', 'string', Rule::in(QuestionCheckingMode::values())],
            'configuration' => ['sometimes', 'array'],
        ];
    }

    protected function requiresAtLeastOneField(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function questionAttributes(): array
    {
        return $this->validatedQuestionAttributes();
    }
}
