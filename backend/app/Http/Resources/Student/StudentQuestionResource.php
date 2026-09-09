<?php

namespace App\Http\Resources\Student;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

class StudentQuestionResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $answerUi = $this->getAttribute('student_answer_ui');

        if (! is_array($answerUi) && ! is_object($answerUi)) {
            throw new LogicException('Student Question resources require a resolved answer surface.');
        }

        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'prompt' => $this->prompt,
            'instructions' => $this->instructions,
            'points' => (float) $this->points,
            'position' => $this->position,
            'answer_ui' => $answerUi,
        ];
    }
}
