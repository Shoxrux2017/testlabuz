<?php

namespace App\Http\Resources\Student;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\HomeworkAssignment;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin AssessmentAttempt */
class StudentHomeworkAttemptResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $assessment = $this->relationLoaded('assessment') ? $this->getRelation('assessment') : null;

        if (! $assessment instanceof Assessment
            || ! $assessment->relationLoaded('homeworkAssignment')
            || ! $assessment->relationLoaded('questions')) {
            throw new LogicException('Student Attempt resources require a preloaded Homework projection.');
        }

        $homework = $assessment->getRelation('homeworkAssignment');
        $questions = $assessment->getRelation('questions');

        if (! $homework instanceof HomeworkAssignment || ! $questions instanceof Collection) {
            throw new LogicException('Student Attempt resources require preloaded Homework and Questions.');
        }

        return [
            'id' => $this->id,
            'assessment_id' => $this->assessment_id,
            'attempt_number' => $this->attempt_number,
            'status' => $this->status->value,
            'started_at' => $this->started_at->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'submitted_at' => $this->submitted_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'finalized_at' => $this->finalized_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'finalization_reason' => $this->finalization_reason?->value,
            'deadline_at' => $homework->deadline_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'questions' => StudentQuestionResource::collection($questions),
        ];
    }
}
