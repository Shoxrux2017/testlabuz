<?php

use App\Exceptions\Auth\CurrentPasswordInvalidException;
use App\Exceptions\Auth\InstitutionInactiveException;
use App\Exceptions\Auth\InvalidCredentialsException;
use App\Exceptions\Auth\PasswordChangeRequiredException;
use App\Exceptions\Auth\UserInactiveException;
use App\Exceptions\Files\FileNotAvailableException;
use App\Exceptions\Files\FileTooLargeException;
use App\Exceptions\Files\FileUploadFailedException;
use App\Exceptions\Files\UnsupportedFileTypeException;
use App\Exceptions\Institution\GroupArchivedException;
use App\Exceptions\Institution\InactiveGroupMemberException;
use App\Exceptions\Institution\InactiveParentStudentRelationshipUserException;
use App\Exceptions\Teacher\AssessmentHasNoScoreablePointsException;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Http\Middleware\EnsureAccountIsActive;
use App\Http\Middleware\EnsurePasswordChanged;
use App\Http\Middleware\EnsureUserHasRole;
use App\Support\ApiErrorResponse;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        apiPrefix: 'api/v1',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->convertEmptyStringsToNull(except: [
            fn (Request $request): bool => ($request->isMethod('post') && $request->is('api/v1/teacher/topics/*/materials'))
                || ($request->isMethod('patch') && $request->is('api/v1/teacher/materials/*')),
        ]);

        $middleware->alias([
            'active.account' => EnsureAccountIsActive::class,
            'password.changed' => EnsurePasswordChanged::class,
            'role' => EnsureUserHasRole::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request, Throwable $e): bool => ApiErrorResponse::isApiRequest($request)
        );

        $exceptions->render(fn (ValidationException $e, Request $request) => ApiErrorResponse::validation($e, $request));
        $exceptions->render(fn (AuthenticationException $e, Request $request) => ApiErrorResponse::authenticationRequired($request));
        $exceptions->render(fn (InvalidCredentialsException $e, Request $request) => ApiErrorResponse::invalidCredentials($request));
        $exceptions->render(fn (CurrentPasswordInvalidException $e, Request $request) => ApiErrorResponse::currentPasswordInvalid($request));
        $exceptions->render(fn (UserInactiveException $e, Request $request) => ApiErrorResponse::userInactive($request));
        $exceptions->render(fn (InstitutionInactiveException $e, Request $request) => ApiErrorResponse::institutionInactive($request));
        $exceptions->render(fn (PasswordChangeRequiredException $e, Request $request) => ApiErrorResponse::passwordChangeRequired($request));
        $exceptions->render(fn (AuthorizationException $e, Request $request) => ApiErrorResponse::forbidden($request));
        $exceptions->render(fn (AccessDeniedHttpException $e, Request $request) => ApiErrorResponse::forbidden($request));
        $exceptions->render(fn (GroupArchivedException $e, Request $request) => ApiErrorResponse::groupArchived($request));
        $exceptions->render(fn (InactiveGroupMemberException $e, Request $request) => ApiErrorResponse::inactiveGroupMember($request));
        $exceptions->render(fn (InactiveParentStudentRelationshipUserException $e, Request $request) => ApiErrorResponse::inactiveParentStudentRelationshipUser($request));
        $exceptions->render(fn (TopicNotEditableException $e, Request $request) => ApiErrorResponse::topicNotEditable($request));
        $exceptions->render(fn (TaskClosedException $e, Request $request) => ApiErrorResponse::taskClosed($request));
        $exceptions->render(fn (TaskArchivedException $e, Request $request) => ApiErrorResponse::taskArchived($request));
        $exceptions->render(fn (BusinessConflictException $e, Request $request) => ApiErrorResponse::businessConflict($request));
        $exceptions->render(fn (ResultPairLockedException $e, Request $request) => ApiErrorResponse::resultPairLocked($request));
        $exceptions->render(fn (AssessmentHasNoScoreablePointsException $e, Request $request) => ApiErrorResponse::assessmentHasNoScoreablePoints($request));
        $exceptions->render(fn (UnsupportedFileTypeException $e, Request $request) => ApiErrorResponse::unsupportedFileType($request));
        $exceptions->render(fn (FileTooLargeException $e, Request $request) => ApiErrorResponse::fileTooLarge($e->maxSizeBytes, $request));
        $exceptions->render(fn (FileUploadFailedException $e, Request $request) => ApiErrorResponse::fileUploadFailed($request));
        $exceptions->render(fn (FileNotAvailableException $e, Request $request) => ApiErrorResponse::fileNotAvailable($request));
        $exceptions->render(fn (NotFoundHttpException $e, Request $request) => ApiErrorResponse::resourceNotFound($request));
        $exceptions->render(fn (ThrottleRequestsException $e, Request $request) => ApiErrorResponse::rateLimited($request));
        $exceptions->render(fn (Throwable $e, Request $request) => ApiErrorResponse::serverError($request));
    })->create();
