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

    private const CODE_BUSINESS_CONFLICT = 'business_conflict';

    private const CODE_CURRENT_PASSWORD_INVALID = 'current_password_invalid';

    private const CODE_INSTITUTION_INACTIVE = 'institution_inactive';

    private const CODE_INVALID_CREDENTIALS = 'invalid_credentials';

    private const CODE_PASSWORD_CHANGE_REQUIRED = 'password_change_required';

    private const CODE_FORBIDDEN = 'forbidden';

    private const CODE_FILE_TOO_LARGE = 'file_too_large';

    private const CODE_FILE_UPLOAD_FAILED = 'file_upload_failed';

    private const CODE_RATE_LIMITED = 'rate_limited';

    private const CODE_RESOURCE_NOT_FOUND = 'resource_not_found';

    private const CODE_SERVER_ERROR = 'server_error';

    private const CODE_TOPIC_NOT_EDITABLE = 'topic_not_editable';

    private const CODE_UNSUPPORTED_FILE_TYPE = 'unsupported_file_type';

    private const CODE_USER_INACTIVE = 'user_inactive';

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

    public static function invalidCredentials(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The provided login credentials are invalid.',
            self::CODE_INVALID_CREDENTIALS,
            Response::HTTP_UNAUTHORIZED,
        );
    }

    public static function currentPasswordInvalid(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The current password is invalid.',
            self::CODE_CURRENT_PASSWORD_INVALID,
            Response::HTTP_CONFLICT,
        );
    }

    public static function userInactive(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'This user account is inactive.',
            self::CODE_USER_INACTIVE,
            Response::HTTP_FORBIDDEN,
        );
    }

    public static function institutionInactive(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'This institution is inactive.',
            self::CODE_INSTITUTION_INACTIVE,
            Response::HTTP_FORBIDDEN,
        );
    }

    public static function passwordChangeRequired(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'Password change is required before using this endpoint.',
            self::CODE_PASSWORD_CHANGE_REQUIRED,
            Response::HTTP_FORBIDDEN,
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

    public static function groupArchived(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The group is archived.',
            self::CODE_BUSINESS_CONFLICT,
            Response::HTTP_CONFLICT,
        );
    }

    public static function inactiveGroupMember(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The selected user is inactive.',
            self::CODE_BUSINESS_CONFLICT,
            Response::HTTP_CONFLICT,
        );
    }

    public static function inactiveParentStudentRelationshipUser(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The selected parent or student is inactive.',
            self::CODE_BUSINESS_CONFLICT,
            Response::HTTP_CONFLICT,
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

    public static function topicNotEditable(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The topic is not editable.',
            self::CODE_TOPIC_NOT_EDITABLE,
            Response::HTTP_CONFLICT,
        );
    }

    public static function unsupportedFileType(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The uploaded file type is not supported.',
            self::CODE_UNSUPPORTED_FILE_TYPE,
            Response::HTTP_UNPROCESSABLE_ENTITY,
            ['file' => ['Supported file types are PDF, DOCX, PPT, and PPTX.']],
        );
    }

    public static function fileTooLarge(int $maxSizeBytes, Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        $maxSizeMiB = intdiv($maxSizeBytes, 1_048_576);

        return self::json(
            'The uploaded file exceeds the allowed size.',
            self::CODE_FILE_TOO_LARGE,
            Response::HTTP_UNPROCESSABLE_ENTITY,
            ['file' => ["The file must not exceed {$maxSizeBytes} bytes ({$maxSizeMiB} MiB)."]],
        );
    }

    public static function fileUploadFailed(Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        return self::json(
            'The file could not be uploaded.',
            self::CODE_FILE_UPLOAD_FAILED,
            Response::HTTP_INTERNAL_SERVER_ERROR,
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
