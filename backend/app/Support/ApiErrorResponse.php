<?php

namespace App\Support;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use stdClass;
use Symfony\Component\HttpFoundation\Response;

final class ApiErrorResponse
{
    private const CODE_AUTHENTICATION_REQUIRED = 'authentication_required';

    private const CODE_FORBIDDEN = 'forbidden';

    private const CODE_RATE_LIMITED = 'rate_limited';

    private const CODE_RESOURCE_NOT_FOUND = 'resource_not_found';

    private const CODE_SERVER_ERROR = 'server_error';

    private const CODE_VALIDATION_FAILED = 'validation_failed';

    public static function isApiRequest(Request $request): bool
    {
        return $request->is('api/v1') || $request->is('api/v1/*');
    }

    public static function validation(ValidationException $exception, Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The request contains invalid data.',
            self::CODE_VALIDATION_FAILED,
            Response::HTTP_UNPROCESSABLE_ENTITY,
            $exception->errors(),
        );
    }

    public static function authenticationRequired(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'Authentication is required.',
            self::CODE_AUTHENTICATION_REQUIRED,
            Response::HTTP_UNAUTHORIZED,
        );
    }

    public static function forbidden(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'You do not have permission to perform this action.',
            self::CODE_FORBIDDEN,
            Response::HTTP_FORBIDDEN,
        );
    }

    public static function resourceNotFound(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The requested resource was not found.',
            self::CODE_RESOURCE_NOT_FOUND,
            Response::HTTP_NOT_FOUND,
        );
    }

    public static function rateLimited(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'Too many requests. Please try again later.',
            self::CODE_RATE_LIMITED,
            Response::HTTP_TOO_MANY_REQUESTS,
        );
    }

    public static function serverError(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'An unexpected server error occurred.',
            self::CODE_SERVER_ERROR,
            Response::HTTP_INTERNAL_SERVER_ERROR,
        );
    }

    /**
     * @param  array<string, array<int, string>>|stdClass  $errors
     */
    private static function json(string $message, string $code, int $status, array|stdClass $errors = new stdClass): JsonResponse
    {
        return response()->json([
            'message' => $message,
            'code' => $code,
            'errors' => $errors,
        ], $status);
    }
}
