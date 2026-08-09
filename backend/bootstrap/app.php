<?php

use App\Exceptions\Auth\CurrentPasswordInvalidException;
use App\Exceptions\Auth\InstitutionInactiveException;
use App\Exceptions\Auth\InvalidCredentialsException;
use App\Exceptions\Auth\PasswordChangeRequiredException;
use App\Exceptions\Auth\UserInactiveException;
use App\Http\Middleware\EnsureAccountIsActive;
use App\Http\Middleware\EnsurePasswordChanged;
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
        $middleware->alias([
            'active.account' => EnsureAccountIsActive::class,
            'password.changed' => EnsurePasswordChanged::class,
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
        $exceptions->render(fn (NotFoundHttpException $e, Request $request) => ApiErrorResponse::resourceNotFound($request));
        $exceptions->render(fn (ThrottleRequestsException $e, Request $request) => ApiErrorResponse::rateLimited($request));
        $exceptions->render(fn (Throwable $e, Request $request) => ApiErrorResponse::serverError($request));
    })->create();
