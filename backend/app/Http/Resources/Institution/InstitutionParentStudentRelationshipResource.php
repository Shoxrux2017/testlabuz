<?php

namespace App\Http\Resources\Institution;

use App\Models\ParentStudentRelationship;
use Carbon\CarbonImmutable;
use DateTimeInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ParentStudentRelationship */
class InstitutionParentStudentRelationshipResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'parent_id' => $this->parent_id,
            'student_id' => $this->student_id,
            'started_at' => $this->timestamp($this->started_at),
            'ended_at' => $this->ended_at === null ? null : $this->timestamp($this->ended_at),
        ];
    }

    private function timestamp(DateTimeInterface|string $timestamp): string
    {
        return CarbonImmutable::parse($timestamp)
            ->utc()
            ->format('Y-m-d\TH:i:s\Z');
    }
}
