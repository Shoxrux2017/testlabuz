<?php

namespace App\Http\Resources\Auth;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class CurrentUserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'institution_id' => $this->institution_id,
            'role' => $this->role->value,
            'full_name' => $this->full_name,
            'login_name' => $this->login_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'is_active' => $this->is_active,
            'must_change_password' => $this->must_change_password,
            'institution' => $this->when(
                $this->role !== UserRole::PlatformOwner,
                fn (): array => [
                    'id' => $this->institution->id,
                    'name' => $this->institution->name,
                    'status' => $this->institution->status->value,
                    'timezone' => $this->institution->setting->timezone,
                ],
                null,
            ),
        ];
    }
}
