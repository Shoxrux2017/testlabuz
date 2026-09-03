<?php

namespace App\Http\Requests\Teacher;

use App\Domain\Assessment\QuestionAuthoringLimits;
use Illuminate\Validation\Validator;
use stdClass;

class TeacherQuestionReorderRequest extends TeacherQuestionMutationRequest
{
    /** @return list<string> */
    protected function acceptedInputKeys(): array
    {
        return ['question_ids'];
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return [
            'question_ids' => ['present', 'array', 'max:'.QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT],
            'question_ids.*' => ['required', 'string', 'uuid'],
        ];
    }

    /** @param array<string, mixed> $payload */
    protected function validateSpecific(Validator $validator, array $payload): void
    {
        $rawBody = json_decode($this->getContent());

        if (! $rawBody instanceof stdClass
            || ! property_exists($rawBody, 'question_ids')
            || ! is_array($rawBody->question_ids)) {
            if ($rawBody instanceof stdClass && property_exists($rawBody, 'question_ids')) {
                $validator->errors()->add('question_ids', 'The question_ids must be a JSON array.');
            }

            return;
        }

        $seen = [];

        foreach ($rawBody->question_ids as $questionId) {
            if (! is_string($questionId)) {
                continue;
            }

            $canonical = strtolower($questionId);

            if (isset($seen[$canonical])) {
                $validator->errors()->add('question_ids', 'The question_ids must not contain duplicates.');

                return;
            }

            $seen[$canonical] = true;
        }
    }

    /** @return list<string> */
    public function questionIds(): array
    {
        return array_map(strtolower(...), $this->validated('question_ids'));
    }
}
