<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class ChangePasswordRequest extends FormRequest
{
    private const CURRENT_PASSWORD_MAX_LENGTH = 1024;

    private const NEW_PASSWORD_MIN_LENGTH = 8;

    private const NEW_PASSWORD_MAX_LENGTH = 255;

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
            'current_password' => ['required', 'string', 'max:'.self::CURRENT_PASSWORD_MAX_LENGTH],
            'new_password' => [
                'required',
                'string',
                'confirmed',
                'min:'.self::NEW_PASSWORD_MIN_LENGTH,
                'max:'.self::NEW_PASSWORD_MAX_LENGTH,
                'different:current_password',
            ],
            'new_password_confirmation' => ['required', 'string', 'max:'.self::NEW_PASSWORD_MAX_LENGTH],
        ];
    }

    public function currentPassword(): string
    {
        return (string) $this->validated('current_password');
    }

    public function newPassword(): string
    {
        return (string) $this->validated('new_password');
    }
}
