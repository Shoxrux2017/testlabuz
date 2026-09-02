<?php

namespace App\Http\Resources\Teacher;

use App\Models\Assessment;
use App\Models\HomeworkAssignment;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Assessment */
class TeacherHomeworkListResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $homework = $this->relationLoaded('homeworkAssignment')
            ? $this->getRelation('homeworkAssignment')
            : null;
        $timezone = $this->getAttribute('institution_timezone');

        if (! $homework instanceof HomeworkAssignment || ! is_string($timezone)) {
            throw new LogicException('Teacher Homework list resources require the complete list projection.');
        }

        return [
            'id' => $this->id,
            'topic_id' => $this->topic_id,
            'title' => $this->title,
            'assignment_mode' => $this->assignment_mode->value,
            'total_possible_points' => (float) $this->total_possible_points,
            'question_count' => (int) $this->questions_count,
            'deadline_at' => $this->timestamp($homework->deadline_at),
            'institution_timezone' => $timezone,
            'status' => $homework->status->value,
            'created_at' => $this->timestamp($this->created_at),
            'updated_at' => $this->timestamp($this->updated_at),
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
