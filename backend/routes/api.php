<?php

use App\Enums\UserRole;
use App\Http\Controllers\Api\V1\Auth\ChangePasswordController;
use App\Http\Controllers\Api\V1\Auth\CurrentUserController;
use App\Http\Controllers\Api\V1\Auth\LoginController;
use App\Http\Controllers\Api\V1\Auth\LogoutController;
use App\Http\Controllers\Api\V1\Institution\InstitutionAssessmentSettingsController;
use App\Http\Controllers\Api\V1\Institution\InstitutionDashboardController;
use App\Http\Controllers\Api\V1\Institution\InstitutionGroupController;
use App\Http\Controllers\Api\V1\Institution\InstitutionGroupStudentMembershipController;
use App\Http\Controllers\Api\V1\Institution\InstitutionGroupTeacherMembershipController;
use App\Http\Controllers\Api\V1\Institution\InstitutionParentStudentRelationshipController;
use App\Http\Controllers\Api\V1\Institution\InstitutionParentStudentsController;
use App\Http\Controllers\Api\V1\Institution\InstitutionProfileController;
use App\Http\Controllers\Api\V1\Institution\InstitutionStudentParentsController;
use App\Http\Controllers\Api\V1\Institution\InstitutionUnderstandingCategoryController;
use App\Http\Controllers\Api\V1\Institution\InstitutionUserController;
use App\Http\Controllers\Api\V1\Platform\PlatformDashboardController;
use App\Http\Controllers\Api\V1\Platform\PlatformInstitutionAdminController;
use App\Http\Controllers\Api\V1\Platform\PlatformInstitutionController;
use App\Http\Controllers\Api\V1\Teacher\TeacherGroupController;
use App\Http\Controllers\Api\V1\Teacher\TeacherTopicController;
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
        Route::get('groups', [InstitutionGroupController::class, 'index']);
        Route::post('groups', [InstitutionGroupController::class, 'store']);
        Route::get('groups/{group}', [InstitutionGroupController::class, 'show']);
        Route::patch('groups/{group}', [InstitutionGroupController::class, 'update']);
        Route::post('groups/{group}/archive', [InstitutionGroupController::class, 'archive']);
        Route::get('groups/{group}/teachers', [InstitutionGroupTeacherMembershipController::class, 'index']);
        Route::post('groups/{group}/teachers', [InstitutionGroupTeacherMembershipController::class, 'store']);
        Route::delete('groups/{group}/teachers/{teacher}', [InstitutionGroupTeacherMembershipController::class, 'destroy']);
        Route::get('groups/{group}/students', [InstitutionGroupStudentMembershipController::class, 'index']);
        Route::post('groups/{group}/students', [InstitutionGroupStudentMembershipController::class, 'store']);
        Route::delete('groups/{group}/students/{student}', [InstitutionGroupStudentMembershipController::class, 'destroy']);
        Route::get('parents/{parent}/students', [InstitutionParentStudentsController::class, 'index']);
        Route::get('students/{student}/parents', [InstitutionStudentParentsController::class, 'index']);
        Route::post('parent-student-relationships', [InstitutionParentStudentRelationshipController::class, 'store']);
        Route::delete('parent-student-relationships/{relationship}', [InstitutionParentStudentRelationshipController::class, 'destroy']);
        Route::get('users', [InstitutionUserController::class, 'index']);
        Route::post('users', [InstitutionUserController::class, 'store']);
        Route::patch('users/{user}', [InstitutionUserController::class, 'update']);
        Route::post('users/{user}/activate', [InstitutionUserController::class, 'activate']);
        Route::post('users/{user}/deactivate', [InstitutionUserController::class, 'deactivate']);
        Route::get('users/{user}', [InstitutionUserController::class, 'show']);
    });

Route::prefix('teacher')
    ->middleware(['auth:sanctum', 'active.account', 'password.changed', 'role:'.UserRole::Teacher->value])
    ->group(function (): void {
        Route::get('groups', TeacherGroupController::class);
        Route::get('topics', [TeacherTopicController::class, 'index']);
        Route::post('topics', [TeacherTopicController::class, 'store']);
        Route::get('topics/{topic}', [TeacherTopicController::class, 'show']);
        Route::patch('topics/{topic}', [TeacherTopicController::class, 'update']);
    });
