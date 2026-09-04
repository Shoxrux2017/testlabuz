<?php

namespace App\Http\Resources\Teacher;

use App\Models\TopicResultPair;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin TopicResultPair */
class TeacherTopicResultPairResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'topic_id' => $this->topic_id,
            'homework_assessment_id' => $this->homework_assessment_id,
            'blitz_assessment_id' => $this->blitz_assessment_id,
            'cohort_snapshotted_at' => $this->timestamp($this->cohort_snapshotted_at),
            'locked_at' => $this->timestamp($this->locked_at),
            'designated_at' => $this->timestamp($this->designated_at),
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
