<?php

namespace App\Http\Resources\Student;

use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\Topic;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/**
 * One finished Blitz of the Student with the counting Attempt's result (docs/09 §20.6).
 *
 * @mixin Assessment
 */
class StudentFinishedBlitzResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $topic = $this->relationLoaded('topic') ? $this->getRelation('topic') : null;
        $task = $this->relationLoaded('blitzTask') ? $this->getRelation('blitzTask') : null;

        if (! $topic instanceof Topic || ! $task instanceof BlitzTask
            || ! array_key_exists('student_finished_result', $this->getAttributes())) {
            throw new LogicException('Student finished Blitz resources require the finished read projection.');
        }

        return [
            'id' => $this->id,
            'topic' => ['id' => $topic->id, 'title' => $topic->title],
            'title' => $this->title,
            'status' => $task->status->value,
            'closed_at' => $task->closed_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'attempt_exception' => (bool) $this->getAttribute('student_attempt_exception'),
            'result' => $this->getAttribute('student_finished_result'),
        ];
    }
}
