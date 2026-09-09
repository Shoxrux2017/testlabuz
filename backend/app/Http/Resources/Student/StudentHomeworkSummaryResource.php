<?php

namespace App\Http\Resources\Student;

use App\Models\Assessment;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Assessment */
class StudentHomeworkSummaryResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $topic = $this->relationLoaded('topic') ? $this->getRelation('topic') : null;
        $homework = $this->relationLoaded('homeworkAssignment') ? $this->getRelation('homeworkAssignment') : null;
        $summary = $this->getAttribute('student_attempt_summary');

        if (! $topic instanceof Topic || ! $homework instanceof HomeworkAssignment || ! is_array($summary)) {
            throw new LogicException('Student Homework resources require preloaded read projections.');
        }

        return [
            'id' => $this->id,
            'topic' => ['id' => $topic->id, 'title' => $topic->title],
            'title' => $this->title,
            'status' => $homework->status->value,
            'deadline_at' => $homework->deadline_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'attempts' => $summary['attempts'],
            'my_status' => $summary['my_status'],
            'score_visible' => false,
        ];
    }
}
