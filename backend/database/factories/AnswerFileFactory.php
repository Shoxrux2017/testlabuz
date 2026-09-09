<?php

namespace Database\Factories;

use App\Enums\QuestionType;
use App\Models\AnswerFile;
use App\Models\AttemptAnswer;
use App\Models\File;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<AnswerFile> */
class AnswerFileFactory extends Factory
{
    public function definition(): array
    {
        return [
            'answer_id' => AttemptAnswer::factory()->forQuestionType(QuestionType::FileBased),
            'institution_id' => fn (array $attributes) => $this->answerFor($attributes)->institution_id,
            'file_id' => fn (array $attributes) => File::factory()->studentSubmission()->state([
                'institution_id' => $attributes['institution_id'],
                'uploaded_by_user_id' => $this->answerFor($attributes)->attempt->student_id,
                'removed_at' => null,
            ]),
        ];
    }

    /** @param array<string, mixed> $attributes */
    private function answerFor(array $attributes): AttemptAnswer
    {
        return AttemptAnswer::query()->findOrFail($attributes['answer_id']);
    }
}
