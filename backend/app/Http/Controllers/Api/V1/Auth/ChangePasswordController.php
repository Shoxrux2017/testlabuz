<?php

namespace App\Http\Controllers\Api\V1\Auth;

use App\Actions\Auth\ChangePassword;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Models\User;
use Illuminate\Http\Response;

class ChangePasswordController extends Controller
{
    public function __invoke(ChangePasswordRequest $request, ChangePassword $changePassword): Response
    {
        /** @var User $user */
        $user = $request->user();

        $changePassword($user, $request->currentPassword(), $request->newPassword());

        return response()->noContent();
    }
}
