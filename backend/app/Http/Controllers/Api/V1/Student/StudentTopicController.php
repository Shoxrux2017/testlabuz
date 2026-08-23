<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\ListStudentTopics;
use App\Actions\Student\ShowStudentTopic;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentTopicIndexRequest;
use App\Http\Requests\Student\StudentTopicShowRequest;
use App\Http\Resources\Student\StudentTopicCollection;
use App\Http\Resources\Student\StudentTopicResource;
use App\Models\User;

class StudentTopicController extends Controller
{
    public function index(
        StudentTopicIndexRequest $request,
        ListStudentTopics $listStudentTopics,
    ): StudentTopicCollection {
        /** @var User $student */
        $student = $request->user();

        return new StudentTopicCollection($listStudentTopics(
            student: $student,
            status: $request->status(),
            search: $request->search(),
            page: $request->page(),
            perPage: $request->perPage(),
        ));
    }

    public function show(
        StudentTopicShowRequest $request,
        string $topic,
        ShowStudentTopic $showStudentTopic,
    ): StudentTopicResource {
        /** @var User $student */
        $student = $request->user();

        return new StudentTopicResource($showStudentTopic($student, $topic));
    }
}
