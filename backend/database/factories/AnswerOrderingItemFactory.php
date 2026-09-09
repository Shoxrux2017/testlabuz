<?php

namespace Database\Factories;

use App\Enums\QuestionType;
use App\Models\AnswerOrderingItem;
use App\Models\AttemptAnswer;
use App\Models\QuestionOrderingItem;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<AnswerOrderingItem> */
class AnswerOrderingItemFactory extends Factory
{
    public function definition(): array
    {
        return [
            'answer_id' => AttemptAnswer::factory()->forQuestionType(QuestionType::Ordering),
            'institution_id' => fn (array $attributes) => $this->answerFor($attributes)->institution_id,
            'ordering_item_id' => fn (array $attributes) => QuestionOrderingItem::factory()->state([
                'question_id' => $this->answerFor($attributes)->question_id,
                'institution_id' => $attributes['institution_id'],
            ]),
            'submitted_position' => 0,
        ];
    }

    /** @param array<string, mixed> $attributes */
    private function answerFor(array $attributes): AttemptAnswer
    {
        return AttemptAnswer::query()->findOrFail($attributes['answer_id']);
    }
}
