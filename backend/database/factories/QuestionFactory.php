<?php

namespace Database\Factories;

use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use App\Models\Assessment;
use App\Models\Question;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Question> */
class QuestionFactory extends Factory
{
    public function definition(): array
    {
        return [
            'assessment_id' => Assessment::factory(),
            'institution_id' => fn (array $attributes) => $this->assessmentFor($attributes)->institution_id,
            'type' => QuestionType::SingleChoice,
            'prompt' => fake()->sentence().'?',
            'instructions' => fake()->optional()->sentence(),
            'points' => '1.000000',
            'position' => 1,
            'checking_mode' => QuestionCheckingMode::Automatic,
        ];
    }

    public function singleChoice(): static
    {
        return $this->typeAndMode(QuestionType::SingleChoice, QuestionCheckingMode::Automatic);
    }

    public function multipleChoice(): static
    {
        return $this->typeAndMode(QuestionType::MultipleChoice, QuestionCheckingMode::Automatic);
    }

    public function trueFalse(): static
    {
        return $this->typeAndMode(QuestionType::TrueFalse, QuestionCheckingMode::Automatic);
    }

    public function shortWrittenAutomatic(): static
    {
        return $this->typeAndMode(QuestionType::ShortWritten, QuestionCheckingMode::Automatic);
    }

    public function shortWrittenManual(): static
    {
        return $this->typeAndMode(QuestionType::ShortWritten, QuestionCheckingMode::Manual);
    }

    public function openWritten(): static
    {
        return $this->typeAndMode(QuestionType::OpenWritten, QuestionCheckingMode::Manual);
    }

    public function fileBased(): static
    {
        return $this->typeAndMode(QuestionType::FileBased, QuestionCheckingMode::Manual);
    }

    public function matching(): static
    {
        return $this->typeAndMode(QuestionType::Matching, QuestionCheckingMode::Automatic);
    }

    public function ordering(): static
    {
        return $this->typeAndMode(QuestionType::Ordering, QuestionCheckingMode::Automatic);
    }

    public function fillInBlank(): static
    {
        return $this->typeAndMode(QuestionType::FillInBlank, QuestionCheckingMode::Automatic);
    }

    private function typeAndMode(QuestionType $type, QuestionCheckingMode $mode): static
    {
        return $this->state(fn (array $attributes) => ['type' => $type, 'checking_mode' => $mode]);
    }

    /** @param array<string, mixed> $attributes */
    private function assessmentFor(array $attributes): Assessment
    {
        return Assessment::query()->findOrFail($attributes['assessment_id']);
    }
}
