<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ActivateTeacherHomework;
use App\Actions\Teacher\ArchiveTeacherHomework;
use App\Actions\Teacher\CloseTeacherHomework;
use App\Actions\Teacher\CreateTeacherHomework;
use App\Actions\Teacher\ListTeacherHomework;
use App\Actions\Teacher\ShowTeacherHomework;
use App\Actions\Teacher\UpdateTeacherHomework;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherHomeworkCreateRequest;
use App\Http\Requests\Teacher\TeacherHomeworkIndexRequest;
use App\Http\Requests\Teacher\TeacherHomeworkLifecycleRequest;
use App\Http\Requests\Teacher\TeacherHomeworkShowRequest;
use App\Http\Requests\Teacher\TeacherHomeworkUpdateRequest;
use App\Http\Resources\Teacher\TeacherHomeworkCollection;
use App\Http\Resources\Teacher\TeacherHomeworkResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class TeacherHomeworkController extends Controller
{
    public function index(
        TeacherHomeworkIndexRequest $request,
        string $topic,
        ListTeacherHomework $listTeacherHomework,
    ): TeacherHomeworkCollection {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherHomeworkCollection($listTeacherHomework(
            teacher: $teacher,
            topicId: $topic,
            status: $request->status(),
            assignmentMode: $request->assignmentMode(),
            search: $request->search(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        ));
    }

    public function store(
        TeacherHomeworkCreateRequest $request,
        string $topic,
        CreateTeacherHomework $createTeacherHomework,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $homework = $createTeacherHomework($teacher, $topic, $request->homeworkAttributes());

        return (new TeacherHomeworkResource($homework))
            ->additional(['message' => 'Homework created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(
        TeacherHomeworkShowRequest $request,
        string $homework,
        ShowTeacherHomework $showTeacherHomework,
    ): TeacherHomeworkResource {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherHomeworkResource($showTeacherHomework($teacher, $homework));
    }

    public function update(
        TeacherHomeworkUpdateRequest $request,
        string $homework,
        UpdateTeacherHomework $updateTeacherHomework,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $updatedHomework = $updateTeacherHomework($teacher, $homework, $request->homeworkAttributes());

        return (new TeacherHomeworkResource($updatedHomework))
            ->additional(['message' => 'Homework updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function activate(
        TeacherHomeworkLifecycleRequest $request,
        string $homework,
        ActivateTeacherHomework $activateTeacherHomework,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $activatedHomework = $activateTeacherHomework($teacher, $homework);

        return (new TeacherHomeworkResource($activatedHomework))
            ->additional(['message' => 'Homework activated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function close(
        TeacherHomeworkLifecycleRequest $request,
        string $homework,
        CloseTeacherHomework $closeTeacherHomework,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $closedHomework = $closeTeacherHomework($teacher, $homework);

        return (new TeacherHomeworkResource($closedHomework))
            ->additional(['message' => 'Homework closed successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function archive(
        TeacherHomeworkLifecycleRequest $request,
        string $homework,
        ArchiveTeacherHomework $archiveTeacherHomework,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $archivedHomework = $archiveTeacherHomework($teacher, $homework);

        return (new TeacherHomeworkResource($archivedHomework))
            ->additional(['message' => 'Homework archived successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }
}
