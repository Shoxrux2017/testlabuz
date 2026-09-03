<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Domain\Assessment\AssessmentPointMath;
use App\Models\Assessment;
use App\Models\Question;
use App\Support\Assessment\QuestionConfigurationWriter;
use stdClass;

trait BuildsTeacherQuestionMutationContext
{
    use BuildsTeacherHomeworkContext;

    /** @param array<string, mixed> $overrides */
    protected function questionPayload(array $overrides = []): array
    {
        return array_merge([
            'type' => 'true_false',
            'prompt' => 'Is this statement true?',
            'instructions' => null,
            'points' => 1,
            'position' => 1,
            'checking_mode' => 'automatic',
            'configuration' => ['correct_value' => true],
        ], $overrides);
    }

    /** @param array<string, mixed> $overrides */
    protected function persistedQuestion(Assessment $assessment, array $overrides = []): Question
    {
        return app(QuestionConfigurationWriter::class)->create(
            $assessment,
            $this->questionPayload($overrides),
        );
    }

    protected function synchronizeQuestionTotal(Assessment $assessment): void
    {
        $total = app(AssessmentPointMath::class)->sum(
            Question::query()
                ->where('assessment_id', $assessment->id)
                ->orderBy('position')
                ->pluck('points')
                ->all(),
        );
        $assessment->forceFill(['total_possible_points' => $total])->save();
    }

    /** @return list<array<string, mixed>> */
    protected function allDedicatedQuestionPayloads(): array
    {
        return [
            $this->questionPayload([
                'type' => 'single_choice',
                'prompt' => 'Choose one.',
                'configuration' => ['options' => [
                    ['text' => 'A', 'is_correct' => true, 'position' => 1],
                    ['text' => 'B', 'is_correct' => false, 'position' => 2],
                ]],
            ]),
            $this->questionPayload([
                'type' => 'multiple_choice',
                'prompt' => 'Choose all.',
                'configuration' => ['options' => [
                    ['text' => 'A', 'is_correct' => true, 'position' => 1],
                    ['text' => 'B', 'is_correct' => true, 'position' => 2],
                ]],
            ]),
            $this->questionPayload([
                'type' => 'true_false',
                'prompt' => 'True?',
                'configuration' => ['correct_value' => false],
            ]),
            $this->questionPayload([
                'type' => 'short_written',
                'prompt' => 'Name it.',
                'configuration' => ['accepted_answers' => ['DNS']],
            ]),
            $this->questionPayload([
                'type' => 'open_written',
                'prompt' => 'Explain.',
                'checking_mode' => 'manual',
                'configuration' => new stdClass,
            ]),
            $this->questionPayload([
                'type' => 'file_based',
                'prompt' => 'Upload.',
                'checking_mode' => 'manual',
                'configuration' => ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx']],
            ]),
            $this->questionPayload([
                'type' => 'matching',
                'prompt' => 'Match.',
                'configuration' => ['pairs' => [
                    ['client_key' => 'request-pair', 'left' => 'DNS', 'right' => 'Domain Name System'],
                ]],
            ]),
            $this->questionPayload([
                'type' => 'ordering',
                'prompt' => 'Order.',
                'configuration' => ['items' => [
                    ['text' => 'First', 'correct_position' => 1],
                    ['text' => 'Second', 'correct_position' => 2],
                ]],
            ]),
            $this->questionPayload([
                'type' => 'fill_in_blank',
                'prompt' => 'DNS maps {{host}}.',
                'configuration' => ['blanks' => [
                    ['key' => 'host', 'position' => 1, 'accepted_answers' => ['domain name']],
                ]],
            ]),
        ];
    }
}
