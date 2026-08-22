<?php

namespace App\Http\Resources\Teacher;

use App\Models\Group;
use App\Models\Topic;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Topic */
class TeacherTopicResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $group = $this->relationLoaded('group') ? $this->getRelation('group') : null;

        if (! $group instanceof Group) {
            throw new LogicException('Teacher Topic resources require a preloaded Group projection.');
        }

        return [
            'id' => $this->id,
            'group' => [
                'id' => $group->id,
                'name' => $group->name,
                'level' => $group->level,
                'subject_direction' => $group->subject_direction,
                'status' => $group->status->value,
            ],
            'title' => $this->title,
            'description' => $this->description,
            'subject' => $this->subject,
            'student_instructions' => $this->student_instructions,
            'lesson_at' => $this->timestamp($this->lesson_at),
            'status' => $this->status->value,
            'activated_at' => $this->timestamp($this->activated_at),
            'closed_at' => $this->timestamp($this->closed_at),
            'archived_at' => $this->timestamp($this->archived_at),
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
