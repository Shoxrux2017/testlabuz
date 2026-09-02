<?php

namespace Database\Factories;

use App\Models\Question;
use App\Models\QuestionOrderingItem;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<QuestionOrderingItem> */
class QuestionOrderingItemFactory extends Factory
{
    public function definition(): array
    {
        return [
            'question_id' => Question::factory()->ordering(),
            'institution_id' => fn (array $attributes) => $this->questionFor($attributes)->institution_id,
            'item_text' => fake()->sentence(),
            'correct_position' => 1,
        ];
    }

    private function questionFor(array $attributes): Question
    {
        return Question::query()->findOrFail($attributes['question_id']);
    }
}
