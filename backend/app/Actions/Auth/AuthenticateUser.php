<?php

namespace App\Actions\Auth;

use App\Enums\InstitutionStatus;
use App\Enums\UserRole;
use App\Exceptions\Auth\InstitutionInactiveException;
use App\Exceptions\Auth\InvalidCredentialsException;
use App\Exceptions\Auth\UserInactiveException;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

final class AuthenticateUser
{
    private const DUMMY_PASSWORD_HASH = '$2y$12$mHGaqff9idEvuMbVf2z.L.C3s.EvN7LluytQp/9TxKxftil2ImP2y';

    private const TOKEN_NAME = 'flutter-client';

    public function __invoke(string $login, string $password): AuthenticatedSession
    {
        return DB::transaction(function () use ($login, $password): AuthenticatedSession {
            $user = User::query()
                ->where('login_name', $login)
                ->with('institution')
                ->first();

            if (! $user instanceof User) {
                $this->runDummyPasswordCheck($password);

                throw new InvalidCredentialsException;
            }

            if (! Hash::check($password, $user->password)) {
                throw new InvalidCredentialsException;
            }

            if (! $user->is_active) {
                throw new UserInactiveException;
            }

            if ($this->institutionUserHasInactiveInstitution($user)) {
                throw new InstitutionInactiveException;
            }

            $newAccessToken = $user->createToken(self::TOKEN_NAME);

            $user->forceFill([
                'last_login_at' => now(),
            ])->save();

            return new AuthenticatedSession($user->refresh(), $newAccessToken->plainTextToken);
        });
    }

    private function runDummyPasswordCheck(string $password): void
    {
        Hash::check($password, self::DUMMY_PASSWORD_HASH);
    }

    private function institutionUserHasInactiveInstitution(User $user): bool
    {
        if ($user->role === UserRole::PlatformOwner) {
            return false;
        }

        return $user->institution?->status !== InstitutionStatus::Active;
    }
}
