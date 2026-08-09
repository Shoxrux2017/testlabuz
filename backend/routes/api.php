<?php

use App\Http\Controllers\Api\V1\Auth\ChangePasswordController;
use App\Http\Controllers\Api\V1\Auth\CurrentUserController;
use App\Http\Controllers\Api\V1\Auth\LoginController;
use App\Http\Controllers\Api\V1\Auth\LogoutController;
use App\Support\Auth\LoginRateLimitKey;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function (): void {
    Route::post('login', LoginController::class)
        ->middleware('throttle:'.LoginRateLimitKey::LIMITER_NAME);

    Route::post('logout', LogoutController::class)
        ->middleware('auth:sanctum');

    Route::get('me', CurrentUserController::class)
        ->middleware(['auth:sanctum', 'active.account']);

    Route::post('change-password', ChangePasswordController::class)
        ->middleware(['auth:sanctum', 'active.account']);
});
