<?php

namespace App\Support\Auth;

use Illuminate\Support\Str;

final class LoginRateLimitKey
{
    public const LIMITER_NAME = 'auth.login';

    public static function limiterKey(?string $login, ?string $ip): string
    {
        $normalizedLogin = Str::lower(trim((string) $login));
        $normalizedIp = trim((string) $ip);

        return hash('sha256', $normalizedLogin.'|'.$normalizedIp);
    }

    public static function throttleCacheKey(?string $login, ?string $ip): string
    {
        return md5(self::LIMITER_NAME.self::limiterKey($login, $ip));
    }
}
