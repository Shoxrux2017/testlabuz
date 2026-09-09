<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\ListStudentHomework;
use App\Actions\Student\ShowStudentHomework;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentHomeworkIndexRequest;
use App\Http\Requests\Student\StudentHomeworkShowRequest;
use App\Http\Resources\Student\StudentHomeworkCollection;
use App\Http\Resources\Student\StudentHomeworkResource;
use App\Models\User;

class StudentHomeworkController extends Controller
{
    public function index(StudentHomeworkIndexRequest $request, ListStudentHomework $listStudentHomework): StudentHomeworkCollection
    {
        /** @var User $student */
        $student = $request->user();

        return new StudentHomeworkCollection($listStudentHomework(
            student: $student,
            topicId: $request->topicId(),
            status: $request->status(),
            page: $request->page(),
            perPage: $request->perPage(),
            sort: $request->sort(),
            direction: $request->direction(),
        ));
    }

    public function show(StudentHomeworkShowRequest $request, string $homework, ShowStudentHomework $showStudentHomework): StudentHomeworkResource
    {
        /** @var User $student */
        $student = $request->user();

        return new StudentHomeworkResource($showStudentHomework($student, $homework));
    }
}
