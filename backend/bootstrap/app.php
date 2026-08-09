<?php

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
        //
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request, Throwable $e): bool => ApiErrorResponse::isApiRequest($request)
        );

        $exceptions->render(fn (ValidationException $e, Request $request) => ApiErrorResponse::validation($e, $request));
        $exceptions->render(fn (AuthenticationException $e, Request $request) => ApiErrorResponse::authenticationRequired($request));
        $exceptions->render(fn (AuthorizationException $e, Request $request) => ApiErrorResponse::forbidden($request));
        $exceptions->render(fn (AccessDeniedHttpException $e, Request $request) => ApiErrorResponse::forbidden($request));
        $exceptions->render(fn (NotFoundHttpException $e, Request $request) => ApiErrorResponse::resourceNotFound($request));
        $exceptions->render(fn (ThrottleRequestsException $e, Request $request) => ApiErrorResponse::rateLimited($request));
        $exceptions->render(fn (Throwable $e, Request $request) => ApiErrorResponse::serverError($request));
    })->create();
