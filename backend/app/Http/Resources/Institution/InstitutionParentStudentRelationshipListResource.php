<?php

namespace App\Http\Resources\Institution;

use App\Models\ParentStudentRelationship;
use Carbon\CarbonImmutable;
use DateTimeInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ParentStudentRelationship */
class InstitutionParentStudentRelationshipListResource extends JsonResource
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
            'related_user' => [
                'id' => $this->getAttribute('related_user_id'),
                'full_name' => $this->getAttribute('related_user_full_name'),
                'login_name' => $this->getAttribute('related_user_login_name'),
                'email' => $this->getAttribute('related_user_email'),
                'phone' => $this->getAttribute('related_user_phone'),
                'is_active' => (bool) $this->getAttribute('related_user_is_active'),
            ],
        ];
    }

    private function timestamp(DateTimeInterface|string $timestamp): string
    {
        return CarbonImmutable::parse($timestamp)
            ->utc()
            ->format('Y-m-d\TH:i:s\Z');
    }
}
