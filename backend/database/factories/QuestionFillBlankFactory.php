<?php

namespace Database\Factories;

use App\Models\Question;
use App\Models\QuestionFillBlank;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<QuestionFillBlank> */
class QuestionFillBlankFactory extends Factory
{
    public function definition(): array
    {
        return [
            'question_id' => Question::factory()->fillInBlank(),
            'institution_id' => fn (array $attributes) => $this->questionFor($attributes)->institution_id,
            'blank_key' => fake()->unique()->lexify('blank_????'),
            'position' => 1,
        ];
    }

    private function questionFor(array $attributes): Question
    {
        return Question::query()->findOrFail($attributes['question_id']);
    }
}
