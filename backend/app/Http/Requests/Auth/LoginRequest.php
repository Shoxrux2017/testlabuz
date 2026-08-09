<?php

namespace App\Http\Requests\Auth;

use App\Support\Auth\LoginRateLimitKey;
use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    private const LOGIN_MAX_LENGTH = 191;

    private const PASSWORD_MAX_LENGTH = 1024;

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        return [
            'login' => ['required', 'string', 'max:'.self::LOGIN_MAX_LENGTH],
            'password' => ['required', 'string', 'max:'.self::PASSWORD_MAX_LENGTH],
        ];
    }

    public function login(): string
    {
        return (string) $this->validated('login');
    }

    public function password(): string
    {
        return (string) $this->validated('password');
    }

    public function rateLimiterCacheKey(): string
    {
        return LoginRateLimitKey::throttleCacheKey($this->login(), $this->ip());
    }
}
