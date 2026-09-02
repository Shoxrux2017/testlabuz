<?php

namespace Database\Factories;

use App\Models\Question;
use App\Models\QuestionChoiceOption;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<QuestionChoiceOption> */
class QuestionChoiceOptionFactory extends Factory
{
    public function definition(): array
    {
        return [
            'question_id' => Question::factory()->singleChoice(),
            'institution_id' => fn (array $attributes) => $this->questionFor($attributes)->institution_id,
            'option_text' => fake()->sentence(),
            'is_correct' => false,
            'position' => 1,
        ];
    }

    private function questionFor(array $attributes): Question
    {
        return Question::query()->findOrFail($attributes['question_id']);
    }
}
