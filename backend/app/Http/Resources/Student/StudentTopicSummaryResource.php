<?php

namespace App\Http\Resources\Student;

use App\Models\Group;
use App\Models\Topic;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Topic */
class StudentTopicSummaryResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $group = $this->relationLoaded('group') ? $this->getRelation('group') : null;

        if (! $group instanceof Group) {
            throw new LogicException('Student Topic summary resources require a preloaded Group projection.');
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
            'subject' => $this->subject,
            'lesson_at' => $this->timestamp($this->lesson_at),
            'status' => $this->status->value,
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
