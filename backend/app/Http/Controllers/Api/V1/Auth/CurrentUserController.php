<?php

namespace App\Http\Controllers\Api\V1\Auth;

use App\Http\Controllers\Controller;
use App\Http\Resources\Auth\CurrentUserResource;
use App\Models\User;
use Illuminate\Http\Request;

class CurrentUserController extends Controller
{
    public function __invoke(Request $request): CurrentUserResource
    {
        /** @var User $user */
        $user = $request->user();
        $user->loadMissing('institution.setting');

        return new CurrentUserResource($user);
    }
}
