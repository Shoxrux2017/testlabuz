<?php

namespace App\Actions\Institution;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class CreateInstitutionUser
{
    public function __invoke(
        User $actor,
        UserRole $role,
        string $fullName,
        string $loginName,
        ?string $email,
        ?string $phone,
        string $password,
    ): User {
        try {
            return DB::transaction(function () use ($actor, $role, $fullName, $loginName, $email, $phone, $password): User {
                $user = User::query()->create([
                    'institution_id' => $actor->institution_id,
                    'role' => $role,
                    'full_name' => $fullName,
                    'login_name' => $loginName,
                    'email' => $email,
                    'phone' => $phone,
                    'password' => Hash::make($password),
                    'is_active' => true,
                    'must_change_password' => true,
                    'last_login_at' => null,
                    'deactivated_at' => null,
                    'created_by_user_id' => $actor->getKey(),
                ]);

                return $user->refresh();
            });
        } catch (QueryException $exception) {
            if ($this->isLoginNameUniqueViolation($exception)) {
                throw ValidationException::withMessages([
                    'login_name' => ['The login name has already been taken.'],
                ]);
            }

            throw $exception;
        }
    }

    private function isLoginNameUniqueViolation(QueryException $exception): bool
    {
        $sqlState = (string) ($exception->errorInfo[0] ?? $exception->getCode());
        $driverMessage = (string) ($exception->errorInfo[2] ?? $exception->getMessage());

        return $sqlState === '23505' && str_contains($driverMessage, 'users_login_name_unique');
    }
}
