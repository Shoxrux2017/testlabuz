<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\ListStudentTopics;
use App\Actions\Student\ShowStudentTopic;
use App\Actions\Student\ShowStudentTopicResult;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentTopicIndexRequest;
use App\Http\Requests\Student\StudentTopicResultRequest;
use App\Http\Requests\Student\StudentTopicShowRequest;
use App\Http\Resources\Student\StudentTopicCollection;
use App\Http\Resources\Student\StudentTopicResource;
use App\Http\Resources\Student\StudentTopicResultResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;

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

    public function result(
        StudentTopicResultRequest $request,
        string $topic,
        ShowStudentTopicResult $showStudentTopicResult,
    ): JsonResponse|StudentTopicResultResource {
        /** @var User $student */
        $student = $request->user();
        $reading = $showStudentTopicResult($student, $topic);

        return $reading === null ? response()->json(['data' => null]) : new StudentTopicResultResource($reading);
    }
}
