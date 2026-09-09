<?php

namespace App\Http\Resources\Student;

use App\Support\Student\StudentHomeworkAttemptAnswerMutationResult;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin StudentHomeworkAttemptAnswerMutationResult */
class StudentAttemptAnswerStateResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $answer = $this->attemptAnswer;

        if ($answer !== null && ! is_array($answer->getAttribute('student_answer_value'))) {
            throw new LogicException('Student answer resources require a validated canonical projection.');
        }

        return [
            'question_id' => $this->question->id,
            'type' => $this->question->type->value,
            'answer' => $answer?->getAttribute('student_answer_value'),
            'updated_at' => $answer?->updated_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
