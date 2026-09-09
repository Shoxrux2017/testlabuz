<?php

namespace Database\Factories;

use App\Enums\QuestionType;
use App\Models\AnswerFillBlankValue;
use App\Models\AttemptAnswer;
use App\Models\QuestionFillBlank;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<AnswerFillBlankValue> */
class AnswerFillBlankValueFactory extends Factory
{
    public function definition(): array
    {
        return [
            'answer_id' => AttemptAnswer::factory()->forQuestionType(QuestionType::FillInBlank),
            'institution_id' => fn (array $attributes) => $this->answerFor($attributes)->institution_id,
            'blank_id' => fn (array $attributes) => QuestionFillBlank::factory()->state([
                'question_id' => $this->answerFor($attributes)->question_id,
                'institution_id' => $attributes['institution_id'],
            ]),
            'text_value' => fake()->word(),
        ];
    }

    /** @param array<string, mixed> $attributes */
    private function answerFor(array $attributes): AttemptAnswer
    {
        return AttemptAnswer::query()->findOrFail($attributes['answer_id']);
    }
}
