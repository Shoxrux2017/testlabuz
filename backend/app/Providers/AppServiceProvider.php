<?php

namespace App\Providers;

use App\Support\Auth\LoginRateLimitKey;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    private const LOGIN_ATTEMPTS_PER_MINUTE = 5;

    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for(LoginRateLimitKey::LIMITER_NAME, function (Request $request): Limit {
            return Limit::perMinute(self::LOGIN_ATTEMPTS_PER_MINUTE)
                ->by(LoginRateLimitKey::limiterKey($request->input('login'), $request->ip()));
        });
    }
}
