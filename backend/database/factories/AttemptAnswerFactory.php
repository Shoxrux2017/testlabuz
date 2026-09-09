<?php

namespace Database\Factories;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\QuestionType;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Question;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<AttemptAnswer> */
class AttemptAnswerFactory extends Factory
{
    public function definition(): array
    {
        return [
            'attempt_id' => AssessmentAttempt::factory(),
            'institution_id' => fn (array $attributes) => $this->attemptFor($attributes)->institution_id,
            'question_id' => fn (array $attributes) => $this->questionForAttempt($attributes, Question::factory()),
            'checking_status' => AttemptAnswerCheckingStatus::Pending,
            'awarded_points' => null,
            'feedback' => null,
            'checked_by_user_id' => null,
            'checked_at' => null,
        ];
    }

    public function forQuestionType(QuestionType $type): static
    {
        $state = match ($type) {
            QuestionType::SingleChoice => 'singleChoice',
            QuestionType::MultipleChoice => 'multipleChoice',
            QuestionType::TrueFalse => 'trueFalse',
            QuestionType::ShortWritten => 'shortWrittenAutomatic',
            QuestionType::OpenWritten => 'openWritten',
            QuestionType::FileBased => 'fileBased',
            QuestionType::Matching => 'matching',
            QuestionType::Ordering => 'ordering',
            QuestionType::FillInBlank => 'fillInBlank',
        };

        return $this->state(fn (array $attributes) => [
            'question_id' => fn (array $attributes) => $this->questionForAttempt($attributes, Question::factory()->{$state}()),
        ]);
    }

    /** @param array<string, mixed> $attributes */
    private function questionForAttempt(array $attributes, QuestionFactory $factory): QuestionFactory
    {
        $attempt = $this->attemptFor($attributes);

        return $factory->state([
            'institution_id' => $attempt->institution_id,
            'assessment_id' => $attempt->assessment_id,
            'position' => Question::query()->where('assessment_id', $attempt->assessment_id)->max('position') + 1,
        ]);
    }

    /** @param array<string, mixed> $attributes */
    private function attemptFor(array $attributes): AssessmentAttempt
    {
        return AssessmentAttempt::query()->findOrFail($attributes['attempt_id']);
    }
}
