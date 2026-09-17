<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\ShowStudentHomeworkAttempt;
use App\Actions\Student\SubmitStudentAttempt;
use App\Enums\AssessmentType;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentAttemptSubmitRequest;
use App\Http\Resources\Student\StudentBlitzAttemptResource;
use App\Http\Resources\Student\StudentHomeworkAttemptResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class StudentAttemptSubmissionController extends Controller
{
    public function __invoke(
        StudentAttemptSubmitRequest $request,
        string $attempt,
        SubmitStudentAttempt $submitAttempt,
        ShowStudentHomeworkAttempt $showHomeworkAttempt,
    ): JsonResponse {
        /** @var User $student */
        $student = $request->user();
        $result = $submitAttempt($student, $attempt, $request->idempotencyKey());
        $resource = match ($result->assessmentType) {
            AssessmentType::Homework => new StudentHomeworkAttemptResource($showHomeworkAttempt($student, $result->attemptId)),
            AssessmentType::Blitz => new StudentBlitzAttemptResource($result->attempt),
        };
        $message = match ($result->assessmentType) {
            AssessmentType::Homework => 'Homework submitted successfully.',
            AssessmentType::Blitz => 'Blitz attempt submitted successfully.',
        };

        return $resource->additional(['message' => $message])->response()->setStatusCode($result->httpStatus);
    }
}
