<?php

namespace App\Actions\Institution;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ChangeInstitutionUserLifecycle
{
    public function activate(User $actor, string $user): User
    {
        return $this->transitionTo($actor, $user, true);
    }

    public function deactivate(User $actor, string $user): User
    {
        return $this->transitionTo($actor, $user, false);
    }

    private function transitionTo(User $actor, string $user, bool $targetIsActive): User
    {
        return DB::transaction(function () use ($actor, $user, $targetIsActive): User {
            $lockedUser = $this->lockInstitutionUser($actor, $user);

            if ($lockedUser->is_active === $targetIsActive) {
                return $lockedUser;
            }

            $lockedUser->forceFill([
                'is_active' => $targetIsActive,
                'deactivated_at' => $targetIsActive ? null : now(),
            ])->save();

            return $lockedUser->refresh();
        });
    }

    private function lockInstitutionUser(User $actor, string $user): User
    {
        if (! Str::isUuid($user)) {
            throw new NotFoundHttpException;
        }

        $lockedUser = User::query()
            ->whereKey($user)
            ->where('institution_id', $actor->institution_id)
            ->whereIn('role', ListInstitutionUsers::allowedRoles())
            ->lockForUpdate()
            ->first();

        if (! $lockedUser instanceof User) {
            throw new NotFoundHttpException;
        }

        return $lockedUser;
    }
}
