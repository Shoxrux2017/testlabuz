<?php

namespace App\Http\Resources\Institution;

use App\Models\User;
use Carbon\CarbonImmutable;
use DateTimeInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin User */
class InstitutionGroupStudentMembershipResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'full_name' => $this->full_name,
            'login_name' => $this->login_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'is_active' => (bool) $this->is_active,
            'started_at' => $this->timestamp($this->getAttribute('started_at')),
        ];
    }

    private function timestamp(DateTimeInterface|string $timestamp): string
    {
        return CarbonImmutable::parse($timestamp)
            ->utc()
            ->format('Y-m-d\TH:i:s\Z');
    }
}
