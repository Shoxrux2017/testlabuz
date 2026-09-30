<?php

namespace App\Http\Resources\Teacher;

use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Question;
use App\Support\Teacher\TeacherSubmissionQuestion;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use LogicException;
use stdClass;

/** A submission with every Question and the Student's answer (docs/09 §21.2). */
class TeacherSubmissionDetailResource extends TeacherSubmissionResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $questions = $this->getAttribute('submission_questions');

        if (! is_array($questions)) {
            throw new LogicException('Teacher submission details require their Questions.');
        }

        return [
            ...parent::toArray($request),
            'submitted_at' => self::timestamp($this->submitted_at),
            'questions' => array_map(fn (TeacherSubmissionQuestion $item): array => [
                'question' => $this->question($item, $request),
                'answer' => $this->answer($item),
            ], $questions),
        ];
    }

    /** @return array<string, mixed> */
    private function question(TeacherSubmissionQuestion $item, Request $request): array
    {
        $question = $item->question;
        // The Teacher Question resource validates the stored configuration and owns its shape.
        $configuration = (new TeacherQuestionResource($question))->toArray($request)['configuration'];

        return [
            'id' => $question->id,
            'type' => $question->type->value,
            'position' => $question->position,
            'prompt' => $question->prompt,
            'points' => (float) $question->points,
            'checking_mode' => $question->checking_mode->value,
            'configuration' => $this->withRowIds($question, $configuration),
        ];
    }

    /**
     * Adds the ids that the Student answer value refers to (selected options, matched items,
     * ordered items, blanks), matched on each row's unique configuration value.
     *
     * @param  array<string, mixed>|stdClass  $configuration
     * @return array<string, mixed>|stdClass
     */
    private function withRowIds(Question $question, array|stdClass $configuration): array|stdClass
    {
        if (! is_array($configuration)) {
            return $configuration;
        }

        return match ($question->type) {
            QuestionType::SingleChoice, QuestionType::MultipleChoice => ['options' => $this->rowsWithIds(
                $configuration['options'], $question->getRelation('choiceOptions')->keyBy('position'), 'position')],
            QuestionType::Ordering => ['items' => $this->rowsWithIds(
                $configuration['items'], $question->getRelation('orderingItems')->keyBy('correct_position'), 'correct_position')],
            QuestionType::FillInBlank => ['blanks' => $this->rowsWithIds(
                $configuration['blanks'], $question->getRelation('fillBlanks')->keyBy('blank_key'), 'key')],
            QuestionType::Matching => ['pairs' => array_map(function (array $pair) use ($question): array {
                $items = $question->getRelation('matchingItems')->where('match_key', $pair['client_key']);

                return $pair + [
                    'left_item_id' => $items->firstWhere('side', QuestionMatchingSide::Left)?->id
                        ?? throw new LogicException('A matching pair has no persisted left item.'),
                    'right_item_id' => $items->firstWhere('side', QuestionMatchingSide::Right)?->id
                        ?? throw new LogicException('A matching pair has no persisted right item.'),
                ];
            }, $configuration['pairs'])],
            default => $configuration,
        };
    }

    /**
     * @param  list<array<string, mixed>>  $rows
     * @return list<array<string, mixed>>
     */
    private function rowsWithIds(array $rows, Collection $models, string $key): array
    {
        return array_map(fn (array $row): array => ['id' => $models->get($row[$key])?->id
            ?? throw new LogicException('A configuration row has no persisted row.')] + $row, $rows);
    }

    /** @return array<string, mixed>|null */
    private function answer(TeacherSubmissionQuestion $item): ?array
    {
        $answer = $item->answer;

        if ($answer === null) {
            return null;
        }

        if (! is_array($answer->getAttribute('student_answer_value'))) {
            throw new LogicException('Teacher submission answers require a validated canonical projection.');
        }

        return [
            'id' => $answer->id,
            'value' => $answer->getAttribute('student_answer_value'),
            'checking_status' => $answer->checking_status->value,
            'awarded_points' => $answer->awarded_points === null ? null : (float) $answer->awarded_points,
            'feedback' => $answer->feedback,
            'checked_by' => $item->reviewer === null ? null
                : ['id' => $item->reviewer->id, 'full_name' => $item->reviewer->full_name],
            'checked_at' => self::timestamp($answer->checked_at),
        ];
    }
}
