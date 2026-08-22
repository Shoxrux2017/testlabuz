<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ListTeacherGroups;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherGroupIndexRequest;
use App\Http\Resources\Teacher\TeacherGroupCollection;
use App\Models\User;

class TeacherGroupController extends Controller
{
    public function __invoke(
        TeacherGroupIndexRequest $request,
        ListTeacherGroups $listTeacherGroups,
    ): TeacherGroupCollection {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherGroupCollection($listTeacherGroups(
            teacher: $teacher,
            search: $request->search(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        ));
    }
}
