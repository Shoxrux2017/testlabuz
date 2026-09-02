<?php

namespace App\Support\Assessment;

use App\Domain\Assessment\AssessmentPointMath;
use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Assessment;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionFillBlankAcceptedAnswer;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\QuestionShortAcceptedAnswer;
use App\Models\QuestionTrueFalseAnswer;
use Illuminate\Support\Str;
use LogicException;

final class QuestionConfigurationWriter
{
    public function __construct(
        private readonly QuestionConfigurationValidator $configurationValidator,
    ) {}

    /**
     * @param array{
     *     type: string,
     *     prompt: string,
     *     instructions: ?string,
     *     points: int|float|string,
     *     position: int,
     *     checking_mode: string,
     *     configuration: array<string, mixed>
     * } $attributes
     */
    public function create(Assessment $assessment, array $attributes): Question
    {
        $type = QuestionType::tryFrom($attributes['type']);
        $checkingMode = QuestionCheckingMode::tryFrom($attributes['checking_mode']);

        if (! $type instanceof QuestionType || ! $checkingMode instanceof QuestionCheckingMode) {
            throw new LogicException('Question type and checking mode must be validated before persistence.');
        }

        $this->configurationValidator->validate(
            $type,
            $checkingMode,
            $attributes['prompt'],
            $attributes['configuration'],
        );

        $question = Question::query()->create([
            'institution_id' => $assessment->institution_id,
            'assessment_id' => $assessment->id,
            'type' => $type,
            'prompt' => $attributes['prompt'],
            'instructions' => $attributes['instructions'],
            'points' => AssessmentPointMath::normalize($attributes['points']),
            'position' => $attributes['position'],
            'checking_mode' => $checkingMode,
        ]);

        $this->writeConfiguration($question, $type, $checkingMode, $attributes['configuration']);

        return $question;
    }

    /** @param array<string, mixed> $configuration */
    private function writeConfiguration(
        Question $question,
        QuestionType $type,
        QuestionCheckingMode $checkingMode,
        array $configuration,
    ): void {
        match ($type) {
            QuestionType::SingleChoice,
            QuestionType::MultipleChoice => $this->writeChoiceOptions($question, $configuration['options']),
            QuestionType::TrueFalse => $this->writeTrueFalseAnswer($question, $configuration['correct_value']),
            QuestionType::ShortWritten => $checkingMode === QuestionCheckingMode::Automatic
                ? $this->writeShortAnswers($question, $configuration['accepted_answers'])
                : null,
            QuestionType::Matching => $this->writeMatchingItems($question, $configuration['pairs']),
            QuestionType::Ordering => $this->writeOrderingItems($question, $configuration['items']),
            QuestionType::FillInBlank => $this->writeFillBlanks($question, $configuration['blanks']),
            QuestionType::OpenWritten,
            QuestionType::FileBased => null,
        };
    }

    /** @param list<array{text: string, is_correct: bool, position: int}> $options */
    private function writeChoiceOptions(Question $question, array $options): void
    {
        foreach ($options as $option) {
            QuestionChoiceOption::query()->create([
                'institution_id' => $question->institution_id,
                'question_id' => $question->id,
                'option_text' => $option['text'],
                'is_correct' => $option['is_correct'],
                'position' => $option['position'],
            ]);
        }
    }

    private function writeTrueFalseAnswer(Question $question, bool $correctValue): void
    {
        QuestionTrueFalseAnswer::query()->create([
            'institution_id' => $question->institution_id,
            'question_id' => $question->id,
            'correct_value' => $correctValue,
        ]);
    }

    /** @param list<string> $answers */
    private function writeShortAnswers(Question $question, array $answers): void
    {
        foreach ($answers as $index => $answer) {
            QuestionShortAcceptedAnswer::query()->create([
                'institution_id' => $question->institution_id,
                'question_id' => $question->id,
                'accepted_text' => $answer,
                'position' => $index + 1,
            ]);
        }
    }

    /** @param list<array{client_key: string, left: string, right: string}> $pairs */
    private function writeMatchingItems(Question $question, array $pairs): void
    {
        foreach ($pairs as $index => $pair) {
            $matchKey = Str::uuid()->toString();
            $position = $index + 1;

            foreach ([
                [QuestionMatchingSide::Left, $pair['left']],
                [QuestionMatchingSide::Right, $pair['right']],
            ] as [$side, $text]) {
                QuestionMatchingItem::query()->create([
                    'institution_id' => $question->institution_id,
                    'question_id' => $question->id,
                    'side' => $side,
                    'match_key' => $matchKey,
                    'item_text' => $text,
                    'position' => $position,
                ]);
            }
        }
    }

    /** @param list<array{text: string, correct_position: int}> $items */
    private function writeOrderingItems(Question $question, array $items): void
    {
        foreach ($items as $item) {
            QuestionOrderingItem::query()->create([
                'institution_id' => $question->institution_id,
                'question_id' => $question->id,
                'item_text' => $item['text'],
                'correct_position' => $item['correct_position'],
            ]);
        }
    }

    /** @param list<array{key: string, position: int, accepted_answers: list<string>}> $blanks */
    private function writeFillBlanks(Question $question, array $blanks): void
    {
        foreach ($blanks as $blankConfiguration) {
            $blank = QuestionFillBlank::query()->create([
                'institution_id' => $question->institution_id,
                'question_id' => $question->id,
                'blank_key' => $blankConfiguration['key'],
                'position' => $blankConfiguration['position'],
            ]);

            foreach ($blankConfiguration['accepted_answers'] as $index => $answer) {
                QuestionFillBlankAcceptedAnswer::query()->create([
                    'institution_id' => $question->institution_id,
                    'blank_id' => $blank->id,
                    'accepted_text' => $answer,
                    'position' => $index + 1,
                ]);
            }
        }
    }
}
