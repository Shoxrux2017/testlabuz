<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\SaveStudentAttemptAnswer;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentAttemptAnswerRequest;
use App\Http\Resources\Student\StudentAttemptAnswerStateResource;
use App\Models\User;

class StudentAttemptAnswerController extends Controller
{
    public function update(
        StudentAttemptAnswerRequest $request,
        string $attempt,
        string $question,
        SaveStudentAttemptAnswer $saveAnswer,
    ): StudentAttemptAnswerStateResource {
        /** @var User $student */
        $student = $request->user();

        return new StudentAttemptAnswerStateResource(
            $saveAnswer($student, $attempt, $question, $request->validated(), $request->file('file')),
        );
    }
}
