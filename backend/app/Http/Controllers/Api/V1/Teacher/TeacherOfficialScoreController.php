<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ShowTeacherOfficialScore;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherOfficialScoreShowRequest;
use App\Http\Resources\Teacher\TeacherOfficialScoreResource;
use App\Models\User;

class TeacherOfficialScoreController extends Controller
{
    public function show(
        TeacherOfficialScoreShowRequest $request,
        string $assessment,
        string $student,
        ShowTeacherOfficialScore $showTeacherOfficialScore,
    ): TeacherOfficialScoreResource {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherOfficialScoreResource($showTeacherOfficialScore($teacher, $assessment, $student));
    }
}
