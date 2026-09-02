<?php

namespace Database\Factories;

use App\Models\QuestionFillBlank;
use App\Models\QuestionFillBlankAcceptedAnswer;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<QuestionFillBlankAcceptedAnswer> */
class QuestionFillBlankAcceptedAnswerFactory extends Factory
{
    public function definition(): array
    {
        return [
            'blank_id' => QuestionFillBlank::factory(),
            'institution_id' => fn (array $attributes) => $this->blankFor($attributes)->institution_id,
            'accepted_text' => fake()->word(),
            'position' => 1,
        ];
    }

    private function blankFor(array $attributes): QuestionFillBlank
    {
        return QuestionFillBlank::query()->findOrFail($attributes['blank_id']);
    }
}
