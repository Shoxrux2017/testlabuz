<?php

namespace App\Http\Controllers\Api\V1\Auth;

use App\Actions\Auth\AuthenticateUser;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\Auth\LoginResource;
use Illuminate\Support\Facades\RateLimiter;

class LoginController extends Controller
{
    public function __invoke(LoginRequest $request, AuthenticateUser $authenticateUser): LoginResource
    {
        $session = $authenticateUser($request->login(), $request->password());

        RateLimiter::clear($request->rateLimiterCacheKey());

        return new LoginResource($session);
    }
}
