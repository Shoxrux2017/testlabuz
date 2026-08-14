<?php

namespace App\Actions\Institution;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class UpdateInstitutionUser
{
    /**
     * @param  array<string, mixed>  $profileAttributes
     */
    public function __invoke(User $actor, string $user, array $profileAttributes): User
    {
        return DB::transaction(function () use ($actor, $user, $profileAttributes): User {
            $lockedUser = $this->lockInstitutionUser($actor, $user);

            foreach ($profileAttributes as $attribute => $value) {
                $lockedUser->setAttribute($attribute, $value);
            }

            if (! $lockedUser->isDirty()) {
                return $lockedUser;
            }

            $lockedUser->save();

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
