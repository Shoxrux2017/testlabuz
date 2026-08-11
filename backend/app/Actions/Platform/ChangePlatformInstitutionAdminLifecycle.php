<?php

namespace App\Actions\Platform;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ChangePlatformInstitutionAdminLifecycle
{
    public function activate(User $admin): User
    {
        return $this->transitionTo($admin, true);
    }

    public function deactivate(User $admin): User
    {
        return $this->transitionTo($admin, false);
    }

    private function transitionTo(User $admin, bool $targetIsActive): User
    {
        return DB::transaction(function () use ($admin, $targetIsActive): User {
            $lockedAdmin = $this->lockInstitutionAdmin($admin);

            if ($lockedAdmin->is_active === $targetIsActive) {
                return $lockedAdmin;
            }

            $lockedAdmin->forceFill([
                'is_active' => $targetIsActive,
                'deactivated_at' => $targetIsActive ? null : now(),
            ])->save();

            return $lockedAdmin->refresh();
        });
    }

    private function lockInstitutionAdmin(User $admin): User
    {
        /** @var User|null $lockedAdmin */
        $lockedAdmin = User::query()
            ->whereKey($admin->getKey())
            ->lockForUpdate()
            ->first();

        if (
            ! $lockedAdmin instanceof User
            || $lockedAdmin->role !== UserRole::InstitutionAdmin
            || $lockedAdmin->institution_id === null
        ) {
            throw new NotFoundHttpException;
        }

        return $lockedAdmin;
    }
}
