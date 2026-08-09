<?php

namespace App\Actions\Auth;

use App\Exceptions\Auth\CurrentPasswordInvalidException;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

final class ChangePassword
{
    public function __invoke(User $user, string $currentPassword, string $newPassword): void
    {
        DB::transaction(function () use ($user, $currentPassword, $newPassword): void {
            /** @var User $lockedUser */
            $lockedUser = User::query()
                ->whereKey($user->getKey())
                ->lockForUpdate()
                ->sole();

            if (! Hash::check($currentPassword, $lockedUser->password)) {
                throw new CurrentPasswordInvalidException;
            }

            $lockedUser->forceFill([
                'password' => Hash::make($newPassword),
                'must_change_password' => false,
            ])->save();
        });
    }
}
