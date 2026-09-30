<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ListTeacherSubmissions;
use App\Actions\Teacher\ShowTeacherSubmission;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherSubmissionIndexRequest;
use App\Http\Requests\Teacher\TeacherSubmissionShowRequest;
use App\Http\Resources\Teacher\TeacherSubmissionCollection;
use App\Http\Resources\Teacher\TeacherSubmissionDetailResource;
use App\Models\User;

class TeacherSubmissionController extends Controller
{
    public function index(TeacherSubmissionIndexRequest $request, ListTeacherSubmissions $listTeacherSubmissions): TeacherSubmissionCollection
    {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherSubmissionCollection($listTeacherSubmissions(
            teacher: $teacher,
            filters: $request->filters(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        ));
    }

    public function show(TeacherSubmissionShowRequest $request, string $submission, ShowTeacherSubmission $showTeacherSubmission): TeacherSubmissionDetailResource
    {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherSubmissionDetailResource($showTeacherSubmission($teacher, $submission));
    }
}
