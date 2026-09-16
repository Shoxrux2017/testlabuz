<?php

namespace App\Http\Resources\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\Topic;
use App\Support\Teacher\InstitutionBlitzScheduledAt;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Assessment */
class TeacherBlitzResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $blitz = $this->relationLoaded('blitzTask') ? $this->getRelation('blitzTask') : null;
        $topic = $this->relationLoaded('topic') ? $this->getRelation('topic') : null;
        $timezone = $this->getAttribute('institution_timezone');

        if (! $blitz instanceof BlitzTask
            || ! $topic instanceof Topic
            || ! is_string($timezone)
            || ! $this->relationLoaded('recipients')
            || ! $this->relationLoaded('questions')) {
            throw new LogicException('Teacher Blitz resources require the complete authoring projection.');
        }

        $studentIds = $this->assignment_mode === AssessmentAssignmentMode::SelectedStudents
            ? $this->recipients->where('assignment_source', AssessmentAssignmentSource::Direct)
                ->pluck('student_id')->map(strtolower(...))->sort()->values()->all()
            : [];

        return [
            'id' => $this->id,
            'topic_id' => $this->topic_id,
            'group_id' => $topic->group_id,
            'title' => $this->title,
            'description' => $this->description,
            'student_instructions' => $this->student_instructions,
            'assignment_mode' => $this->assignment_mode->value,
            'student_ids' => $studentIds,
            'total_possible_points' => (float) $this->total_possible_points,
            'duration_seconds' => $blitz->duration_seconds,
            'scheduled_at' => InstitutionBlitzScheduledAt::serialize($blitz->scheduled_at),
            'institution_timezone' => $timezone,
            'status' => $blitz->status->value,
            'timer_start_mode_snapshot' => $blitz->timer_start_mode_snapshot?->value,
            'attempt_policy' => [
                'normal_attempts' => 1,
                'max_additional_exception_attempts' => 1,
            ],
            'activated_at' => $this->timestamp($blitz->activated_at),
            'synchronized_ends_at' => $this->timestamp($blitz->synchronized_ends_at),
            'closed_at' => $this->timestamp($blitz->closed_at),
            'archived_at' => $this->timestamp($blitz->archived_at),
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
