<?php

namespace App\Http\Resources\Student;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection as SupportCollection;
use LogicException;

/** @mixin AssessmentAttempt */
class StudentBlitzAttemptResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $assessment = $this->relationLoaded('assessment') ? $this->getRelation('assessment') : null;
        $questions = $assessment instanceof Assessment && $assessment->relationLoaded('questions')
            ? $assessment->getRelation('questions') : null;
        $timing = $this->getAttribute('student_blitz_timing');
        $answerStates = $this->getAttribute('student_answer_states');

        if (! $questions instanceof Collection || ! is_array($timing) || ! $answerStates instanceof SupportCollection) {
            throw new LogicException('Student Blitz Attempt resources require preloaded Questions, timing and Answer states.');
        }

        return [
            'id' => $this->id,
            'assessment_id' => $this->assessment_id,
            'attempt_number' => $this->attempt_number,
            'status' => $this->status->value,
            'started_at' => $this->started_at->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'deadline_at' => $timing['deadline_at'],
            'submitted_at' => $this->submitted_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'finalized_at' => $this->finalized_at?->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'finalization_reason' => $this->finalization_reason?->value,
            'timing' => [
                'server_now' => $timing['server_now'],
                'mode' => $timing['mode'],
                'remaining_seconds' => $timing['remaining_seconds'],
            ],
            'questions' => StudentQuestionResource::collection($questions),
            'answers' => StudentAttemptAnswerStateResource::collection($answerStates),
        ];
    }
}
