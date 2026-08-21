<?php

namespace App\Http\Resources\Institution;

use App\Models\Group;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Group
 */
class InstitutionGroupResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'level' => $this->level,
            'subject_direction' => $this->subject_direction,
            'description' => $this->description,
            'status' => $this->status->value,
            'teachers_count' => (int) $this->teachers_count,
            'students_count' => (int) $this->students_count,
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
