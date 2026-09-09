<?php

namespace Database\Factories;

use App\Enums\QuestionType;
use App\Models\AnswerBooleanValue;
use App\Models\AttemptAnswer;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<AnswerBooleanValue> */
class AnswerBooleanValueFactory extends Factory
{
    public function definition(): array
    {
        return [
            'answer_id' => AttemptAnswer::factory()->forQuestionType(QuestionType::TrueFalse),
            'institution_id' => fn (array $attributes) => $this->answerFor($attributes)->institution_id,
            'boolean_value' => true,
        ];
    }

    /** @param array<string, mixed> $attributes */
    private function answerFor(array $attributes): AttemptAnswer
    {
        return AttemptAnswer::query()->findOrFail($attributes['answer_id']);
    }
}
