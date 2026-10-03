<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ListTeacherTopicResults;
use App\Actions\Teacher\ShowTeacherTopicResult;
use App\Actions\Teacher\UpdateTeacherTopicResultComment;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherTopicResultCommentRequest;
use App\Http\Requests\Teacher\TeacherTopicResultIndexRequest;
use App\Http\Requests\Teacher\TeacherTopicResultShowRequest;
use App\Http\Resources\Teacher\TeacherTopicResultCollection;
use App\Http\Resources\Teacher\TeacherTopicResultDetailResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class TeacherTopicResultController extends Controller
{
    public function index(TeacherTopicResultIndexRequest $request, string $topic, ListTeacherTopicResults $listTeacherTopicResults): TeacherTopicResultCollection
    {
        /** @var User $teacher */
        $teacher = $request->user();
        ['page' => $page, 'counts' => $counts] = $listTeacherTopicResults($teacher, $topic, $request->filters(), $request->page(), $request->perPage());

        return new TeacherTopicResultCollection($page, $counts);
    }

    public function show(TeacherTopicResultShowRequest $request, string $topic, string $student, ShowTeacherTopicResult $showTeacherTopicResult): TeacherTopicResultDetailResource
    {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherTopicResultDetailResource($showTeacherTopicResult($teacher, $topic, $student));
    }

    public function updateComment(
        TeacherTopicResultCommentRequest $request,
        string $topic,
        string $student,
        UpdateTeacherTopicResultComment $updateTeacherTopicResultComment,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();

        return (new TeacherTopicResultDetailResource($updateTeacherTopicResultComment($teacher, $topic, $student, $request->comment())))
            ->additional(['message' => 'Topic result comment saved successfully.'])
            ->response();
    }
}
