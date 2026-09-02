<?php

namespace App\Http\Resources\Teacher;

use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Enums\FileExtension;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Question;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use InvalidArgumentException;
use LogicException;
use stdClass;

/** @mixin Question */
class TeacherQuestionResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $configuration = $this->configuration();

        try {
            (new QuestionConfigurationValidator)->validate(
                $this->type,
                $this->checking_mode,
                $this->prompt,
                $configuration,
            );
        } catch (InvalidArgumentException $exception) {
            throw new LogicException('Persisted Question configuration is invalid.', previous: $exception);
        }

        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'prompt' => $this->prompt,
            'instructions' => $this->instructions,
            'points' => (float) $this->points,
            'position' => $this->position,
            'checking_mode' => $this->checking_mode->value,
            'configuration' => $configuration === [] ? new stdClass : $configuration,
        ];
    }

    /** @return array<string, mixed> */
    private function configuration(): array
    {
        return match ($this->type) {
            QuestionType::SingleChoice,
            QuestionType::MultipleChoice => ['options' => $this->loaded('choiceOptions')->map(fn ($option): array => [
                'text' => $option->option_text,
                'is_correct' => $option->is_correct,
                'position' => $option->position,
            ])->values()->all()],
            QuestionType::TrueFalse => ['correct_value' => $this->trueFalseValue()],
            QuestionType::ShortWritten => $this->checking_mode === QuestionCheckingMode::Automatic
                ? ['accepted_answers' => $this->loaded('shortAcceptedAnswers')->pluck('accepted_text')->all()]
                : [],
            QuestionType::OpenWritten => [],
            QuestionType::FileBased => ['allowed_extensions' => FileExtension::values()],
            QuestionType::Matching => ['pairs' => $this->matchingPairs()],
            QuestionType::Ordering => ['items' => $this->loaded('orderingItems')->map(fn ($item): array => [
                'text' => $item->item_text,
                'correct_position' => $item->correct_position,
            ])->values()->all()],
            QuestionType::FillInBlank => ['blanks' => $this->fillBlanks()],
        };
    }

    private function trueFalseValue(): bool
    {
        if (! $this->relationLoaded('trueFalseAnswer') || $this->trueFalseAnswer === null) {
            throw new LogicException('Persisted true/false Question answer is missing.');
        }

        return $this->trueFalseAnswer->correct_value;
    }

    /** @return list<array{client_key: string, left: string, right: string}> */
    private function matchingPairs(): array
    {
        $pairs = [];

        foreach ($this->loaded('matchingItems')->groupBy('match_key') as $matchKey => $items) {
            $left = $items->firstWhere('side', QuestionMatchingSide::Left);
            $right = $items->firstWhere('side', QuestionMatchingSide::Right);

            if ($items->count() !== 2
                || ! $left instanceof QuestionMatchingItem
                || ! $right instanceof QuestionMatchingItem
                || $left->position !== $right->position) {
                throw new LogicException('Persisted Matching Question pair is invalid.');
            }

            $pairs[] = [
                'client_key' => (string) $matchKey,
                'left' => $left->item_text,
                'right' => $right->item_text,
            ];
        }

        return $pairs;
    }

    /** @return list<array{key: string, position: int, accepted_answers: list<string>}> */
    private function fillBlanks(): array
    {
        return $this->loaded('fillBlanks')->map(function (QuestionFillBlank $blank): array {
            if (! $blank->relationLoaded('acceptedAnswers')) {
                throw new LogicException('Persisted Fill Blank answers were not loaded.');
            }

            return [
                'key' => $blank->blank_key,
                'position' => $blank->position,
                'accepted_answers' => $blank->acceptedAnswers->pluck('accepted_text')->all(),
            ];
        })->values()->all();
    }

    private function loaded(string $relation): mixed
    {
        if (! $this->relationLoaded($relation)) {
            throw new LogicException("Persisted Question relation {$relation} was not loaded.");
        }

        return $this->getRelation($relation);
    }
}
