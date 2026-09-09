<?php

namespace App\Support\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\QuestionType;
use App\Models\AnswerBooleanValue;
use App\Models\AnswerFillBlankValue;
use App\Models\AnswerMatchingPair;
use App\Models\AnswerOrderingItem;
use App\Models\AnswerTextValue;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Question;
use Illuminate\Support\Carbon;
use LogicException;

final class StudentHomeworkAnswerWriter
{
    /** @param array<string, mixed>|null $value */
    public function replace(AssessmentAttempt $attempt, Question $question, ?AttemptAnswer $answer, ?array $value): ?AttemptAnswer
    {
        if ($answer !== null) {
            $this->deletePayload($question, $answer);

            if ($value === null) {
                $answer->delete();

                return null;
            }
        }

        if ($value === null) {
            return null;
        }

        $savedAt = now();
        $answer ??= new AttemptAnswer([
            'institution_id' => $attempt->institution_id,
            'attempt_id' => $attempt->id,
            'question_id' => $question->id,
            'checking_status' => AttemptAnswerCheckingStatus::Pending,
            'awarded_points' => null,
            'feedback' => null,
            'checked_by_user_id' => null,
            'checked_at' => null,
        ]);

        if (! $answer->exists) {
            $answer->created_at = $savedAt;
        }

        $answer->updated_at = $savedAt;
        $answer->save();
        $this->insertPayload($question, $answer, $value, $savedAt);

        return $answer;
    }

    private function deletePayload(Question $question, AttemptAnswer $answer): void
    {
        match ($question->type) {
            QuestionType::SingleChoice, QuestionType::MultipleChoice => $answer->selectedOptions()->detach(),
            QuestionType::TrueFalse => $answer->booleanValue()->delete(),
            QuestionType::ShortWritten, QuestionType::OpenWritten => $answer->textValue()->delete(),
            QuestionType::Matching => $answer->matchingPairs()->delete(),
            QuestionType::Ordering => $answer->orderingItems()->delete(),
            QuestionType::FillInBlank => $answer->fillBlankValues()->delete(),
            default => throw new LogicException('Unsupported Student answer mutation.'),
        };
    }

    private function insertPayload(Question $question, AttemptAnswer $answer, array $value, Carbon $savedAt): void
    {
        $identity = ['answer_id' => $answer->id, 'institution_id' => $answer->institution_id];

        if (in_array($question->type, [QuestionType::SingleChoice, QuestionType::MultipleChoice], true)) {
            $answer->selectedOptions()->attach(array_fill_keys($value['selected_option_ids'], [
                'institution_id' => $answer->institution_id, 'created_at' => $savedAt,
            ]));

            return;
        }

        $rows = match ($question->type) {
            QuestionType::TrueFalse => [new AnswerBooleanValue($identity + ['boolean_value' => $value['value']])],
            QuestionType::ShortWritten, QuestionType::OpenWritten => [new AnswerTextValue($identity + ['text_value' => $value['text']])],
            QuestionType::Matching => array_map(fn (array $pair) => new AnswerMatchingPair($identity + $pair), $value['pairs']),
            QuestionType::Ordering => array_map(fn (array $item) => new AnswerOrderingItem($identity + [
                'ordering_item_id' => $item['item_id'], 'submitted_position' => $item['position'],
            ]), $value['items']),
            QuestionType::FillInBlank => array_map(fn (array $blank) => new AnswerFillBlankValue($identity + [
                'blank_id' => $blank['blank_id'], 'text_value' => $blank['text'],
            ]), $value['values']),
            default => throw new LogicException('Unsupported Student answer mutation.'),
        };

        foreach ($rows as $row) {
            $row->created_at = $savedAt;

            if ($row->getUpdatedAtColumn() !== null) {
                $row->updated_at = $savedAt;
            }

            $row->save();
        }
    }
}
