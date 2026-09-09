<?php

namespace Database\Factories;

use App\Enums\QuestionType;
use App\Models\AnswerTextValue;
use App\Models\AttemptAnswer;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<AnswerTextValue> */
class AnswerTextValueFactory extends Factory
{
    public function definition(): array
    {
        return [
            'answer_id' => AttemptAnswer::factory()->forQuestionType(QuestionType::ShortWritten),
            'institution_id' => fn (array $attributes) => $this->answerFor($attributes)->institution_id,
            'text_value' => fake()->sentence(),
        ];
    }

    /** @param array<string, mixed> $attributes */
    private function answerFor(array $attributes): AttemptAnswer
    {
        return AttemptAnswer::query()->findOrFail($attributes['answer_id']);
    }
}
