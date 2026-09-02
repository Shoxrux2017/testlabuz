<?php

namespace Database\Factories;

use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<QuestionTrueFalseAnswer> */
class QuestionTrueFalseAnswerFactory extends Factory
{
    public function definition(): array
    {
        return [
            'question_id' => Question::factory()->trueFalse(),
            'institution_id' => fn (array $attributes) => $this->questionFor($attributes)->institution_id,
            'correct_value' => true,
        ];
    }

    private function questionFor(array $attributes): Question
    {
        return Question::query()->findOrFail($attributes['question_id']);
    }
}
