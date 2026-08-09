<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use App\Models\User;
use Closure;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasRole
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next, string ...$allowedRoleValues): Response
    {
        $allowedRoles = $this->resolveAllowedRoles($allowedRoleValues);
        $user = $request->user();

        if ($allowedRoles === [] || ! $user instanceof User || ! in_array($user->role, $allowedRoles, true)) {
            throw new AuthorizationException;
        }

        return $next($request);
    }

    /**
     * @param  list<string>  $allowedRoleValues
     * @return list<UserRole>
     */
    private function resolveAllowedRoles(array $allowedRoleValues): array
    {
        $allowedRoles = [];

        foreach ($allowedRoleValues as $allowedRoleValue) {
            $allowedRole = UserRole::tryFrom($allowedRoleValue);

            if (! $allowedRole instanceof UserRole) {
                return [];
            }

            $allowedRoles[] = $allowedRole;
        }

        return $allowedRoles;
    }
}
