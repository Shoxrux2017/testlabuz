<?php

use App\Enums\UserRole;
use App\Http\Controllers\Api\V1\Auth\ChangePasswordController;
use App\Http\Controllers\Api\V1\Auth\CurrentUserController;
use App\Http\Controllers\Api\V1\Auth\LoginController;
use App\Http\Controllers\Api\V1\Auth\LogoutController;
use App\Http\Controllers\Api\V1\Platform\PlatformDashboardController;
use App\Http\Controllers\Api\V1\Platform\PlatformInstitutionController;
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

Route::prefix('platform')
    ->middleware(['auth:sanctum', 'active.account', 'password.changed', 'role:'.UserRole::PlatformOwner->value])
    ->group(function (): void {
        Route::get('dashboard', PlatformDashboardController::class);
        Route::get('institutions', [PlatformInstitutionController::class, 'index']);
        Route::post('institutions', [PlatformInstitutionController::class, 'store']);
        Route::patch('institutions/{institution}', [PlatformInstitutionController::class, 'update']);
        Route::post('institutions/{institution}/activate', [PlatformInstitutionController::class, 'activate']);
        Route::post('institutions/{institution}/deactivate', [PlatformInstitutionController::class, 'deactivate']);
        Route::get('institutions/{institution}', [PlatformInstitutionController::class, 'show']);
    });
