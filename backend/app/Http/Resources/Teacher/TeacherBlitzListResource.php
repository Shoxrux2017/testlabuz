<?php

namespace App\Http\Resources\Teacher;

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
class TeacherBlitzListResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $blitz = $this->relationLoaded('blitzTask') ? $this->getRelation('blitzTask') : null;
        $topic = $this->relationLoaded('topic') ? $this->getRelation('topic') : null;
        $timezone = $this->getAttribute('institution_timezone');

        if (! $blitz instanceof BlitzTask || ! $topic instanceof Topic || ! is_string($timezone)) {
            throw new LogicException('Teacher Blitz list resources require the complete list projection.');
        }

        return [
            'id' => $this->id,
            'topic_id' => $this->topic_id,
            'group_id' => $topic->group_id,
            'title' => $this->title,
            'assignment_mode' => $this->assignment_mode->value,
            'total_possible_points' => (float) $this->total_possible_points,
            'question_count' => (int) $this->questions_count,
            'duration_seconds' => $blitz->duration_seconds,
            'scheduled_at' => InstitutionBlitzScheduledAt::serialize($blitz->scheduled_at),
            'institution_timezone' => $timezone,
            'status' => $blitz->status->value,
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
