<?php

namespace App\Support\Student;

use App\Enums\FileExtension;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use LogicException;

class StudentQuestionAnswerUi
{
    /** @return array<string, mixed>|object */
    public function project(Question $question, int $maxFileSizeBytes): array|object
    {
        return match ($question->type) {
            QuestionType::SingleChoice => $this->choices($question, multiple: false),
            QuestionType::MultipleChoice => $this->choices($question, multiple: true),
            QuestionType::TrueFalse, QuestionType::ShortWritten, QuestionType::OpenWritten => (object) [],
            QuestionType::FileBased => [
                'allowed_extensions' => FileExtension::values(),
                'max_size_bytes' => $maxFileSizeBytes,
            ],
            QuestionType::Matching => $this->matching($question),
            QuestionType::Ordering => [
                'items' => $this->displayItems(
                    $this->requiredRows($question, 'orderingItems', QuestionOrderingItem::class, ['item_text']),
                    'ordering',
                    $question->id,
                ),
            ],
            QuestionType::FillInBlank => [
                'blanks' => $this->requiredRows($question, 'fillBlanks', QuestionFillBlank::class, ['blank_key', 'position'])
                    ->sortBy([['position', 'asc'], ['id', 'asc']])
                    ->map(fn (QuestionFillBlank $blank): array => [
                        'id' => $blank->id,
                        'key' => $blank->blank_key,
                        'position' => $blank->position,
                    ])->values()->all(),
            ],
        };
    }

    /** @return array<string, mixed> */
    private function choices(Question $question, bool $multiple): array
    {
        $columns = ['option_text', 'position'];

        if ($multiple) {
            $columns[] = 'is_correct';
        }

        $options = $this->requiredRows($question, 'choiceOptions', QuestionChoiceOption::class, $columns);
        $answerUi = [
            'options' => $options->sortBy([['position', 'asc'], ['id', 'asc']])
                ->map(fn (QuestionChoiceOption $option): array => [
                    'id' => $option->id,
                    'text' => $option->option_text,
                ])->values()->all(),
        ];

        if ($multiple) {
            $maxSelections = $options->filter(fn (QuestionChoiceOption $option): bool => $option->is_correct)->count();

            if ($maxSelections < 1) {
                throw new LogicException('Student Multiple Choice projection requires a valid selection limit.');
            }

            $answerUi['max_selections'] = $maxSelections;
        }

        return $answerUi;
    }

    /** @return array<string, mixed> */
    private function matching(Question $question): array
    {
        $items = $this->requiredRows($question, 'matchingItems', QuestionMatchingItem::class, ['side', 'item_text']);
        $left = $items->filter(fn (QuestionMatchingItem $item): bool => $item->side === QuestionMatchingSide::Left);
        $right = $items->filter(fn (QuestionMatchingItem $item): bool => $item->side === QuestionMatchingSide::Right);

        if ($left->isEmpty() || $right->isEmpty() || $left->count() + $right->count() !== $items->count()) {
            throw new LogicException('Student Matching projection requires both item sides.');
        }

        return [
            'left_items' => $this->displayItems($left, 'matching-left', $question->id),
            'right_items' => $this->displayItems($right, 'matching-right', $question->id),
        ];
    }

    /** @return list<array{id: string, text: string}> */
    private function displayItems(Collection $items, string $prefix, string $questionId): array
    {
        return $items->sort(function (Model $left, Model $right) use ($prefix, $questionId): int {
            $comparison = strcmp(
                hash('sha256', $prefix.'|'.$questionId.'|'.$left->id),
                hash('sha256', $prefix.'|'.$questionId.'|'.$right->id),
            );

            return $comparison !== 0 ? $comparison : strcmp($left->id, $right->id);
        })->map(fn (Model $item): array => ['id' => $item->id, 'text' => $item->item_text])->values()->all();
    }

    /**
     * @param  class-string<Model>  $modelClass
     * @param  list<string>  $columns
     */
    private function requiredRows(Question $question, string $relation, string $modelClass, array $columns): Collection
    {
        $rows = $question->relationLoaded($relation) ? $question->getRelation($relation) : null;

        if (! $rows instanceof Collection || $rows->isEmpty()) {
            throw new LogicException('Student Question projection requires preloaded answer surface rows.');
        }

        foreach ($rows as $row) {
            if (! $row instanceof $modelClass
                || ! array_key_exists('question_id', $row->getAttributes())
                || $row->getAttribute('question_id') !== $question->id) {
                throw new LogicException('Student Question answer surface identity is inconsistent.');
            }

            foreach (['id', ...$columns] as $column) {
                if (! array_key_exists($column, $row->getAttributes()) || $row->getAttribute($column) === null) {
                    throw new LogicException('Student Question projection requires complete answer surface fields.');
                }
            }
        }

        return $rows;
    }
}
