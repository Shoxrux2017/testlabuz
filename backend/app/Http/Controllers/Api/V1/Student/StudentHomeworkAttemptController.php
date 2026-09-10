<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\ShowStudentHomeworkAttempt;
use App\Actions\Student\StartStudentHomeworkAttempt;
use App\Actions\Student\SubmitStudentHomeworkAttempt;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentHomeworkAttemptShowRequest;
use App\Http\Requests\Student\StudentHomeworkAttemptStartRequest;
use App\Http\Requests\Student\StudentHomeworkAttemptSubmitRequest;
use App\Http\Resources\Student\StudentHomeworkAttemptResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class StudentHomeworkAttemptController extends Controller
{
    public function store(
        StudentHomeworkAttemptStartRequest $request,
        string $homework,
        StartStudentHomeworkAttempt $startAttempt,
        ShowStudentHomeworkAttempt $showAttempt,
    ): JsonResponse {
        /** @var User $student */
        $student = $request->user();
        $result = $startAttempt($student, $homework, $request->idempotencyKey());

        return (new StudentHomeworkAttemptResource($showAttempt($student, $result->attemptId)))
            ->response()
            ->setStatusCode($result->httpStatus);
    }

    public function show(
        StudentHomeworkAttemptShowRequest $request,
        string $attempt,
        ShowStudentHomeworkAttempt $showAttempt,
    ): StudentHomeworkAttemptResource {
        /** @var User $student */
        $student = $request->user();

        return new StudentHomeworkAttemptResource($showAttempt($student, $attempt));
    }

    public function submit(
        StudentHomeworkAttemptSubmitRequest $request,
        string $attempt,
        SubmitStudentHomeworkAttempt $submitAttempt,
        ShowStudentHomeworkAttempt $showAttempt,
    ): JsonResponse {
        /** @var User $student */
        $student = $request->user();
        $result = $submitAttempt($student, $attempt, $request->idempotencyKey());

        return (new StudentHomeworkAttemptResource($showAttempt($student, $result->attemptId)))
            ->additional(['message' => 'Homework submitted successfully.'])
            ->response()
            ->setStatusCode($result->httpStatus);
    }
}
