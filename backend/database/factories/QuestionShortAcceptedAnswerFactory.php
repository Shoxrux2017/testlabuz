<?php

namespace Database\Factories;

use App\Models\Question;
use App\Models\QuestionShortAcceptedAnswer;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<QuestionShortAcceptedAnswer> */
class QuestionShortAcceptedAnswerFactory extends Factory
{
    public function definition(): array
    {
        return [
            'question_id' => Question::factory()->shortWrittenAutomatic(),
            'institution_id' => fn (array $attributes) => $this->questionFor($attributes)->institution_id,
            'accepted_text' => fake()->word(),
            'position' => 1,
        ];
    }

    private function questionFor(array $attributes): Question
    {
        return Question::query()->findOrFail($attributes['question_id']);
    }
}
