<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\SaveStudentHomeworkAttemptAnswer;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentHomeworkAttemptAnswerRequest;
use App\Http\Resources\Student\StudentAttemptAnswerStateResource;
use App\Models\User;

class StudentHomeworkAttemptAnswerController extends Controller
{
    public function update(
        StudentHomeworkAttemptAnswerRequest $request,
        string $attempt,
        string $question,
        SaveStudentHomeworkAttemptAnswer $saveAnswer,
    ): StudentAttemptAnswerStateResource {
        /** @var User $student */
        $student = $request->user();

        return new StudentAttemptAnswerStateResource($saveAnswer($student, $attempt, $question, $request->validated()));
    }
}
