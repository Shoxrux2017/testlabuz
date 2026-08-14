<?php

namespace App\Actions\Institution;

use App\Models\User;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ShowInstitutionUser
{
    public function __invoke(User $actor, string $user): User
    {
        if (! Str::isUuid($user)) {
            throw new NotFoundHttpException;
        }

        $resolvedUser = User::query()
            ->select([
                'id',
                'role',
                'full_name',
                'login_name',
                'email',
                'phone',
                'is_active',
                'must_change_password',
                'last_login_at',
                'deactivated_at',
                'created_at',
                'updated_at',
            ])
            ->whereKey($user)
            ->where('institution_id', $actor->institution_id)
            ->whereIn('role', ListInstitutionUsers::allowedRoles())
            ->first();

        if (! $resolvedUser instanceof User) {
            throw new NotFoundHttpException;
        }

        return $resolvedUser;
    }
}
