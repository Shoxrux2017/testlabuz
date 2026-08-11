<?php

namespace App\Actions\Platform;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class UpdatePlatformInstitutionAdmin
{
    /**
     * @param  array<string, mixed>  $profileAttributes
     */
    public function __invoke(User $admin, array $profileAttributes): User
    {
        return DB::transaction(function () use ($admin, $profileAttributes): User {
            $lockedAdmin = $this->lockInstitutionAdmin($admin);

            foreach ($profileAttributes as $attribute => $value) {
                $lockedAdmin->setAttribute($attribute, $value);
            }

            if (! $lockedAdmin->isDirty()) {
                return $lockedAdmin;
            }

            $lockedAdmin->save();

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
