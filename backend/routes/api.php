<?php

use App\Enums\UserRole;
use App\Http\Controllers\Api\V1\Auth\ChangePasswordController;
use App\Http\Controllers\Api\V1\Auth\CurrentUserController;
use App\Http\Controllers\Api\V1\Auth\LoginController;
use App\Http\Controllers\Api\V1\Auth\LogoutController;
use App\Http\Controllers\Api\V1\Institution\InstitutionAssessmentSettingsController;
use App\Http\Controllers\Api\V1\Institution\InstitutionDashboardController;
use App\Http\Controllers\Api\V1\Institution\InstitutionProfileController;
use App\Http\Controllers\Api\V1\Institution\InstitutionUnderstandingCategoryController;
use App\Http\Controllers\Api\V1\Institution\InstitutionUserController;
use App\Http\Controllers\Api\V1\Platform\PlatformDashboardController;
use App\Http\Controllers\Api\V1\Platform\PlatformInstitutionAdminController;
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
        Route::get('institutions/{institution}/admins', [PlatformInstitutionAdminController::class, 'index']);
        Route::post('institutions/{institution}/admins', [PlatformInstitutionAdminController::class, 'store']);
        Route::patch('institution-admins/{user}', [PlatformInstitutionAdminController::class, 'update']);
        Route::post('institution-admins/{user}/activate', [PlatformInstitutionAdminController::class, 'activate']);
        Route::post('institution-admins/{user}/deactivate', [PlatformInstitutionAdminController::class, 'deactivate']);
        Route::get('institutions/{institution}', [PlatformInstitutionController::class, 'show']);
    });

Route::prefix('institution')
    ->middleware(['auth:sanctum', 'active.account', 'password.changed', 'role:'.UserRole::InstitutionAdmin->value])
    ->group(function (): void {
        Route::get('dashboard', InstitutionDashboardController::class);
        Route::get('settings/assessment', [InstitutionAssessmentSettingsController::class, 'show']);
        Route::put('settings/assessment', [InstitutionAssessmentSettingsController::class, 'update']);
        Route::get('understanding-categories', [InstitutionUnderstandingCategoryController::class, 'index']);
        Route::put('understanding-categories', [InstitutionUnderstandingCategoryController::class, 'update']);
        Route::get('profile', [InstitutionProfileController::class, 'show']);
        Route::patch('profile', [InstitutionProfileController::class, 'update']);
        Route::get('users', [InstitutionUserController::class, 'index']);
        Route::post('users', [InstitutionUserController::class, 'store']);
        Route::patch('users/{user}', [InstitutionUserController::class, 'update']);
        Route::post('users/{user}/activate', [InstitutionUserController::class, 'activate']);
        Route::post('users/{user}/deactivate', [InstitutionUserController::class, 'deactivate']);
        Route::get('users/{user}', [InstitutionUserController::class, 'show']);
    });
