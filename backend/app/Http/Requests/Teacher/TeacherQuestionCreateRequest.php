<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;
use InvalidArgumentException;

class TeacherQuestionCreateRequest extends TeacherQuestionMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return ['type', 'prompt', 'instructions', 'points', 'position', 'checking_mode', 'configuration'];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'type' => ['required', 'string', Rule::in(QuestionType::values())],
            'prompt' => ['required', 'string', 'min:1', 'max:'.QuestionAuthoringLimits::MAX_PROMPT_LENGTH],
            'instructions' => ['sometimes', 'nullable', 'string', 'max:'.QuestionAuthoringLimits::MAX_INSTRUCTIONS_LENGTH],
            'points' => ['required'],
            'position' => ['required'],
            'checking_mode' => ['required', 'string', Rule::in(QuestionCheckingMode::values())],
            'configuration' => ['present', 'array'],
        ];
    }

    /** @param array<string, mixed> $payload */
    protected function validateSpecific(Validator $validator, array $payload): void
    {
        $type = isset($payload['type']) && is_string($payload['type'])
            ? QuestionType::tryFrom($payload['type'])
            : null;
        $checkingMode = isset($payload['checking_mode']) && is_string($payload['checking_mode'])
            ? QuestionCheckingMode::tryFrom($payload['checking_mode'])
            : null;
        $prompt = $payload['prompt'] ?? null;
        $configuration = $payload['configuration'] ?? null;

        if (! $type instanceof QuestionType
            || ! $checkingMode instanceof QuestionCheckingMode
            || ! is_string($prompt)
            || ! is_array($configuration)) {
            return;
        }

        try {
            (new QuestionConfigurationValidator)->validate($type, $checkingMode, $prompt, $configuration);
        } catch (InvalidArgumentException) {
            $validator->errors()->add('configuration', 'The Question configuration is invalid.');
        }
    }

    /** @return array<string, mixed> */
    public function questionAttributes(): array
    {
        $attributes = $this->validatedQuestionAttributes();
        $attributes['instructions'] ??= null;

        return $attributes;
    }
}
