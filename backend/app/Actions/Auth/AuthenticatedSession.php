<?php

namespace App\Actions\Auth;

use App\Models\User;

final readonly class AuthenticatedSession
{
    public function __construct(
        public User $user,
        public string $plainTextToken,
    ) {}
}
