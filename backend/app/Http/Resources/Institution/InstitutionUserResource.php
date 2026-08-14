<?php

namespace App\Http\Resources\Institution;

use App\Models\User;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class InstitutionUserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'role' => $this->role->value,
            'full_name' => $this->full_name,
            'login_name' => $this->login_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'is_active' => $this->is_active,
            'must_change_password' => $this->must_change_password,
            'last_login_at' => $this->timestamp($this->last_login_at),
            'deactivated_at' => $this->timestamp($this->deactivated_at),
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
