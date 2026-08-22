<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\CreateTeacherTopic;
use App\Actions\Teacher\ListTeacherTopics;
use App\Actions\Teacher\ShowTeacherTopic;
use App\Actions\Teacher\UpdateTeacherTopic;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherTopicCreateRequest;
use App\Http\Requests\Teacher\TeacherTopicIndexRequest;
use App\Http\Requests\Teacher\TeacherTopicShowRequest;
use App\Http\Requests\Teacher\TeacherTopicUpdateRequest;
use App\Http\Resources\Teacher\TeacherTopicCollection;
use App\Http\Resources\Teacher\TeacherTopicResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class TeacherTopicController extends Controller
{
    public function index(
        TeacherTopicIndexRequest $request,
        ListTeacherTopics $listTeacherTopics,
    ): TeacherTopicCollection {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherTopicCollection($listTeacherTopics(
            teacher: $teacher,
            groupId: $request->groupId(),
            status: $request->status(),
            search: $request->search(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        ));
    }

    public function store(
        TeacherTopicCreateRequest $request,
        CreateTeacherTopic $createTeacherTopic,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $topic = $createTeacherTopic($teacher, $request->topicAttributes());

        return (new TeacherTopicResource($topic))
            ->additional(['message' => 'Topic created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(
        TeacherTopicShowRequest $request,
        string $topic,
        ShowTeacherTopic $showTeacherTopic,
    ): TeacherTopicResource {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherTopicResource($showTeacherTopic($teacher, $topic));
    }

    public function update(
        TeacherTopicUpdateRequest $request,
        string $topic,
        UpdateTeacherTopic $updateTeacherTopic,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $updatedTopic = $updateTeacherTopic($teacher, $topic, $request->topicAttributes());

        return (new TeacherTopicResource($updatedTopic))
            ->additional(['message' => 'Topic updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }
}
