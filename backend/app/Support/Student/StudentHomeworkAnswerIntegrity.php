<?php

namespace App\Support\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\QuestionType;
use App\Exceptions\Student\SelectionLimitExceededException;
use App\Exceptions\Student\StudentHomeworkConflictException;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Question;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Validation\ValidationException;
use LogicException;

final class StudentHomeworkAnswerIntegrity
{
    public function __construct(private readonly StudentHomeworkAnswerValue $values) {}

    /** @param Collection<int, AttemptAnswer> $answers */
    public function load(Collection $answers): void
    {
        // Load every family: filtering out incompatible rows would hide corruption.
        $answers->load([
            'selectedOptions' => fn ($query) => $query->select([
                'question_choice_options.id', 'question_choice_options.institution_id', 'question_choice_options.question_id',
            ]),
            'booleanValue:answer_id,institution_id,boolean_value',
            'textValue:answer_id,institution_id,text_value',
            'matchingPairs:id,answer_id,institution_id,left_item_id,right_item_id',
            'orderingItems:id,answer_id,institution_id,ordering_item_id,submitted_position',
            'fillBlankValues:id,answer_id,institution_id,blank_id,text_value',
            'answerFile:answer_id,institution_id',
        ]);
    }

    /** @return array<string, mixed> */
    public function canonical(AttemptAnswer $answer, AssessmentAttempt $attempt, Question $question): array
    {
        $this->requireValid($answer->institution_id === $attempt->institution_id
            && $answer->attempt_id === $attempt->id && $answer->question_id === $question->id
            && $question->assessment_id === $attempt->assessment_id
            && $answer->checking_status === AttemptAnswerCheckingStatus::Pending
            && $answer->awarded_points === null && $answer->feedback === null
            && $answer->checked_by_user_id === null && $answer->checked_at === null);

        $family = match ($question->type) {
            QuestionType::SingleChoice, QuestionType::MultipleChoice => 'selectedOptions',
            QuestionType::TrueFalse => 'booleanValue',
            QuestionType::ShortWritten, QuestionType::OpenWritten => 'textValue',
            QuestionType::Matching => 'matchingPairs',
            QuestionType::Ordering => 'orderingItems',
            QuestionType::FillInBlank => 'fillBlankValues',
            default => throw new LogicException('Unsupported persisted Student answer state.'),
        };

        foreach (['selectedOptions', 'booleanValue', 'textValue', 'matchingPairs', 'orderingItems', 'fillBlankValues', 'answerFile'] as $relation) {
            $this->requireValid($answer->relationLoaded($relation));
            $related = $answer->getRelation($relation);
            $rows = $related instanceof Collection ? $related : new Collection($related === null ? [] : [$related]);
            $this->requireValid($relation === $family ? $rows->isNotEmpty() : $rows->isEmpty());

            foreach ($rows as $row) {
                $this->requireValid($row->institution_id === $attempt->institution_id);

                if ($relation === 'selectedOptions') {
                    $this->requireValid($row->question_id === $question->id
                        && $row->pivot->institution_id === $attempt->institution_id
                        && $row->pivot->answer_id === $answer->id);
                } else {
                    $this->requireValid($row->answer_id === $answer->id);
                }
            }
        }

        $rows = $answer->getRelation($family);
        $payload = match ($family) {
            'selectedOptions' => ['selected_option_ids' => $rows->modelKeys()],
            'booleanValue' => ['value' => $rows->boolean_value],
            'textValue' => ['text' => $rows->text_value],
            'matchingPairs' => ['pairs' => $rows->map(fn ($row): array => [
                'left_item_id' => $row->left_item_id, 'right_item_id' => $row->right_item_id,
            ])->all()],
            'orderingItems' => ['items' => $rows->map(fn ($row): array => [
                'item_id' => $row->ordering_item_id, 'position' => $row->submitted_position,
            ])->all()],
            'fillBlankValues' => ['values' => $rows->map(fn ($row): array => [
                'blank_id' => $row->blank_id, 'text' => $row->text_value,
            ])->all()],
        };

        try {
            $canonical = $this->values->resolve($question, $payload);
        } catch (ValidationException|SelectionLimitExceededException|StudentHomeworkConflictException $exception) {
            throw new LogicException('Persisted Student answer integrity failed.', previous: $exception);
        }

        $this->requireValid($canonical !== null);

        return $canonical;
    }

    private function requireValid(bool $valid): void
    {
        if (! $valid) {
            throw new LogicException('Persisted Student answer integrity failed.');
        }
    }
}
