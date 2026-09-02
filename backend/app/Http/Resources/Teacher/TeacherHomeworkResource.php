<?php

namespace App\Http\Resources\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Models\Assessment;
use App\Models\HomeworkAssignment;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Assessment */
class TeacherHomeworkResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $homework = $this->relationLoaded('homeworkAssignment')
            ? $this->getRelation('homeworkAssignment')
            : null;
        $timezone = $this->getAttribute('institution_timezone');

        if (! $homework instanceof HomeworkAssignment
            || ! is_string($timezone)
            || ! $this->relationLoaded('recipients')
            || ! $this->relationLoaded('questions')) {
            throw new LogicException('Teacher Homework resources require the complete authoring projection.');
        }

        $studentIds = $this->assignment_mode === AssessmentAssignmentMode::SelectedStudents
            ? $this->recipients->pluck('student_id')->map(strtolower(...))->sort()->values()->all()
            : [];

        return [
            'id' => $this->id,
            'topic_id' => $this->topic_id,
            'title' => $this->title,
            'description' => $this->description,
            'student_instructions' => $this->student_instructions,
            'assignment_mode' => $this->assignment_mode->value,
            'student_ids' => $studentIds,
            'total_possible_points' => (float) $this->total_possible_points,
            'deadline_at' => $this->timestamp($homework->deadline_at),
            'institution_timezone' => $timezone,
            'status' => $homework->status->value,
            'attempt_policy' => [
                'normal_attempts' => 3,
                'official_score_policy' => 'highest_valid_completed',
            ],
            'activated_at' => $this->timestamp($homework->activated_at),
            'closed_at' => $this->timestamp($homework->closed_at),
            'archived_at' => $this->timestamp($homework->archived_at),
            'created_at' => $this->timestamp($this->created_at),
            'updated_at' => $this->timestamp($this->updated_at),
            'questions' => TeacherQuestionResource::collection($this->questions),
        ];
    }

    private function timestamp(?DateTimeInterface $timestamp): ?string
    {
        if ($timestamp === null) {
            return null;
        }

        return (new DateTimeImmutable('@'.$timestamp->getTimestamp()))
            ->setTimezone(new DateTimeZone('UTC'))
            ->format('Y-m-d\TH:i:s\Z');
    }
}
