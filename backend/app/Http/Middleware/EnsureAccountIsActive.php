<?php

namespace App\Http\Middleware;

use App\Enums\InstitutionStatus;
use App\Enums\UserRole;
use App\Exceptions\Auth\InstitutionInactiveException;
use App\Exceptions\Auth\UserInactiveException;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAccountIsActive
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        /** @var User $user */
        $user = $request->user();

        if (! $user->is_active) {
            throw new UserInactiveException;
        }

        if ($user->role !== UserRole::PlatformOwner) {
            $user->loadMissing('institution');

            if ($user->institution?->status !== InstitutionStatus::Active) {
                throw new InstitutionInactiveException;
            }
        }

        return $next($request);
    }
}
