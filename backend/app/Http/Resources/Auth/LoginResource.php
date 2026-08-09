<?php

namespace App\Http\Resources\Auth;

use App\Actions\Auth\AuthenticatedSession;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin AuthenticatedSession
 */
class LoginResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'token' => $this->plainTextToken,
            'token_type' => 'Bearer',
            'user' => new LoginUserResource($this->user),
        ];
    }
}
