<?php

namespace App\Http\Resources\Student;

use App\Enums\TopicResultStatus;
use App\Models\Group;
use App\Models\Topic;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use LogicException;

/** @mixin Topic */
class StudentTopicResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $group = $this->relationLoaded('group') ? $this->getRelation('group') : null;
        $materials = $this->relationLoaded('learningMaterials') ? $this->getRelation('learningMaterials') : null;

        if (! $group instanceof Group || ! $materials instanceof Collection) {
            throw new LogicException('Student Topic resources require preloaded Group and Learning Material projections.');
        }

        if (! array_key_exists('student_result_status', $this->resource->getAttributes())) {
            throw new LogicException('Student Topic resources require the Student\'s Topic result status.');
        }

        $resultStatus = $this->getAttribute('student_result_status');

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
            'materials' => StudentLearningMaterialResource::collection($materials),
            'homework' => [],
            'blitz_status' => 'not_available',
            // The Student's Topic result status, or null without a result (docs/09 §29.3).
            'result_status' => $resultStatus instanceof TopicResultStatus ? $resultStatus->value : null,
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
