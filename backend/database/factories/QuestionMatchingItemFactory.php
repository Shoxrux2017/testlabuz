<?php

namespace Database\Factories;

use App\Enums\QuestionMatchingSide;
use App\Models\Question;
use App\Models\QuestionMatchingItem;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<QuestionMatchingItem> */
class QuestionMatchingItemFactory extends Factory
{
    public function definition(): array
    {
        return [
            'question_id' => Question::factory()->matching(),
            'institution_id' => fn (array $attributes) => $this->questionFor($attributes)->institution_id,
            'side' => QuestionMatchingSide::Left,
            'match_key' => Str::uuid()->toString(),
            'item_text' => fake()->sentence(),
            'position' => 1,
        ];
    }

    public function left(): static
    {
        return $this->state(fn (array $attributes) => ['side' => QuestionMatchingSide::Left]);
    }

    public function right(): static
    {
        return $this->state(fn (array $attributes) => ['side' => QuestionMatchingSide::Right]);
    }

    private function questionFor(array $attributes): Question
    {
        return Question::query()->findOrFail($attributes['question_id']);
    }
}
