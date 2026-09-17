<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\StartStudentBlitzAttempt;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentBlitzAttemptStartRequest;
use App\Http\Resources\Student\StudentBlitzAttemptResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class StudentBlitzAttemptController extends Controller
{
    public function store(
        StudentBlitzAttemptStartRequest $request,
        string $blitz,
        StartStudentBlitzAttempt $startAttempt,
    ): JsonResponse {
        /** @var User $student */
        $student = $request->user();
        $result = $startAttempt($student, $blitz, $request->idempotencyKey(), $request->intent(), $request->attemptId());

        return (new StudentBlitzAttemptResource($result->attempt))
            ->additional(['message' => $result->httpStatus === 201
                ? 'Blitz attempt started successfully.'
                : 'Blitz attempt resumed successfully.'])
            ->response()
            ->setStatusCode($result->httpStatus);
    }
}
