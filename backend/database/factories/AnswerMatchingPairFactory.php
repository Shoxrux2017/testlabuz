<?php

namespace Database\Factories;

use App\Enums\QuestionType;
use App\Models\AnswerMatchingPair;
use App\Models\AttemptAnswer;
use App\Models\QuestionMatchingItem;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<AnswerMatchingPair> */
class AnswerMatchingPairFactory extends Factory
{
    public function definition(): array
    {
        return [
            'answer_id' => AttemptAnswer::factory()->forQuestionType(QuestionType::Matching),
            'institution_id' => fn (array $attributes) => $this->answerFor($attributes)->institution_id,
            'left_item_id' => fn (array $attributes) => QuestionMatchingItem::factory()->left()->state([
                'question_id' => $this->answerFor($attributes)->question_id,
                'institution_id' => $attributes['institution_id'],
            ]),
            'right_item_id' => fn (array $attributes) => QuestionMatchingItem::factory()->right()->state([
                'question_id' => $this->answerFor($attributes)->question_id,
                'institution_id' => $attributes['institution_id'],
                'match_key' => QuestionMatchingItem::query()->findOrFail($attributes['left_item_id'])->match_key,
            ]),
        ];
    }

    /** @param array<string, mixed> $attributes */
    private function answerFor(array $attributes): AttemptAnswer
    {
        return AttemptAnswer::query()->findOrFail($attributes['answer_id']);
    }
}
