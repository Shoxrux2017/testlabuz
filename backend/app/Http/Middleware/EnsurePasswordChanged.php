<?php

namespace App\Http\Middleware;

use App\Exceptions\Auth\PasswordChangeRequiredException;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePasswordChanged
{
    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        /** @var User $user */
        $user = $request->user();

        if ($user->must_change_password) {
            throw new PasswordChangeRequiredException;
        }

        return $next($request);
    }
}
