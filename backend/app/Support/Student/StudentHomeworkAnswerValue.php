<?php

namespace App\Support\Student;

use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Exceptions\Student\SelectionLimitExceededException;
use App\Exceptions\Student\StudentHomeworkConflictException;
use App\Models\Question;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Validation\ValidationException;
use LogicException;

final class StudentHomeworkAnswerValue
{
    /** @param Collection<int, Question> $questions */
    public function loadQuestions(Collection $questions, string $institutionId): void
    {
        foreach ($questions->groupBy(fn (Question $question): string => $question->type->value) as $type => $group) {
            $relation = match ($type) {
                'single_choice', 'multiple_choice' => 'choiceOptions',
                'matching' => 'matchingItems',
                'ordering' => 'orderingItems',
                'fill_in_blank' => 'fillBlanks',
                default => null,
            };

            if ($relation === null) {
                continue;
            }

            $columns = match ($type) {
                'single_choice' => ['position'],
                'multiple_choice' => ['position', 'is_correct'],
                'matching' => ['side'],
                'fill_in_blank' => ['position'],
                default => [],
            };

            $group->load([$relation => fn ($query) => $query
                ->select(['id', 'institution_id', 'question_id', ...$columns])
                ->where('institution_id', $institutionId)]);
        }
    }

    /**
     * Resolve a shape-validated request against current Question configuration.
     *
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>|null
     */
    public function resolve(Question $question, array $payload): ?array
    {
        return match ($question->type) {
            QuestionType::SingleChoice, QuestionType::MultipleChoice => $this->choices($question, $payload['selected_option_ids']),
            QuestionType::TrueFalse => ['value' => $payload['value']],
            QuestionType::ShortWritten, QuestionType::OpenWritten => StudentAnswerText::isEmpty($payload['text']) ? null : ['text' => $payload['text']],
            QuestionType::Matching => $this->matching($question, $payload['pairs']),
            QuestionType::Ordering => $this->ordering($question, $payload['items']),
            QuestionType::FillInBlank => $this->fill($question, $payload['values']),
            default => throw new LogicException('Unsupported Student answer state.'),
        };
    }

    private function choices(Question $question, array $ids): ?array
    {
        $options = $question->getRelation('choiceOptions')->sortBy([['position', 'asc'], ['id', 'asc']]);
        $ids = array_map(strtolower(...), $ids);
        $this->requireValid(array_diff($ids, $options->modelKeys()) === [] && count(array_unique($ids)) === count($ids), 'selected_option_ids');

        if ($question->type === QuestionType::SingleChoice) {
            $this->requireValid(count($ids) === 1, 'selected_option_ids');
        } else {
            $limit = $options->where('is_correct', true)->count();

            if ($limit < 1) {
                throw new StudentHomeworkConflictException;
            }

            if (count($ids) > $limit) {
                throw new SelectionLimitExceededException;
            }
        }

        return $ids === [] ? null : ['selected_option_ids' => $options->whereIn('id', $ids)->values()->modelKeys()];
    }

    private function matching(Question $question, array $pairs): ?array
    {
        $items = $question->getRelation('matchingItems');
        $leftIds = $items->where('side', QuestionMatchingSide::Left)->modelKeys();
        $rightIds = $items->where('side', QuestionMatchingSide::Right)->modelKeys();
        $pairs = array_map(fn (array $pair): array => [
            'left_item_id' => strtolower($pair['left_item_id']),
            'right_item_id' => strtolower($pair['right_item_id']),
        ], $pairs);
        $left = array_column($pairs, 'left_item_id');
        $right = array_column($pairs, 'right_item_id');
        $this->requireValid(array_diff($left, $leftIds) === [] && array_diff($right, $rightIds) === []
            && count(array_unique($left)) === count($pairs) && count(array_unique($right)) === count($pairs), 'pairs');

        usort($pairs, fn (array $left, array $right): int => [$left['left_item_id'], $left['right_item_id']] <=> [$right['left_item_id'], $right['right_item_id']]);

        return $pairs === [] ? null : ['pairs' => $pairs];
    }

    private function ordering(Question $question, array $items): ?array
    {
        $questionIds = $question->getRelation('orderingItems')->modelKeys();
        $items = array_map(fn (array $item): array => ['item_id' => strtolower($item['item_id']), 'position' => $item['position']], $items);
        $ids = array_column($items, 'item_id');
        $positions = array_column($items, 'position');
        $this->requireValid(array_diff($ids, $questionIds) === [] && count(array_unique($ids)) === count($items)
            && count(array_unique($positions)) === count($items), 'items');

        foreach ($positions as $position) {
            $this->requireValid(is_int($position) && $position >= 1 && $position <= count($questionIds), 'items');
        }

        usort($items, fn (array $left, array $right): int => [$left['position'], $left['item_id']] <=> [$right['position'], $right['item_id']]);

        return $items === [] ? null : ['items' => $items];
    }

    private function fill(Question $question, array $values): ?array
    {
        $blanks = $question->getRelation('fillBlanks')->sortBy([['position', 'asc'], ['id', 'asc']]);
        $values = array_map(fn (array $value): array => ['blank_id' => strtolower($value['blank_id']), 'text' => $value['text']], $values);
        $ids = array_column($values, 'blank_id');
        $this->requireValid(array_diff($ids, $blanks->modelKeys()) === [] && count(array_unique($ids)) === count($values), 'values');

        foreach ($values as $value) {
            $this->requireValid(! StudentAnswerText::isEmpty($value['text']), 'values');
        }

        $byId = array_column($values, null, 'blank_id');

        return $values === [] ? null : ['values' => $blanks->whereIn('id', $ids)
            ->map(fn ($blank): array => $byId[$blank->id])->values()->all()];
    }

    private function requireValid(bool $valid, string $field): void
    {
        if (! $valid) {
            throw ValidationException::withMessages([$field => ['The answer contains invalid values for this Question.']]);
        }
    }
}
