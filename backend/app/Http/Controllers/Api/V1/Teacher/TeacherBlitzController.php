<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ArchiveTeacherBlitz;
use App\Actions\Teacher\CreateTeacherBlitz;
use App\Actions\Teacher\ListTeacherBlitz;
use App\Actions\Teacher\ScheduleTeacherBlitz;
use App\Actions\Teacher\ShowTeacherBlitz;
use App\Actions\Teacher\UpdateTeacherBlitz;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherBlitzCreateRequest;
use App\Http\Requests\Teacher\TeacherBlitzIndexRequest;
use App\Http\Requests\Teacher\TeacherBlitzLifecycleRequest;
use App\Http\Requests\Teacher\TeacherBlitzScheduleRequest;
use App\Http\Requests\Teacher\TeacherBlitzShowRequest;
use App\Http\Requests\Teacher\TeacherBlitzUpdateRequest;
use App\Http\Resources\Teacher\TeacherBlitzCollection;
use App\Http\Resources\Teacher\TeacherBlitzResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class TeacherBlitzController extends Controller
{
    public function index(
        TeacherBlitzIndexRequest $request,
        ListTeacherBlitz $listTeacherBlitz,
    ): TeacherBlitzCollection {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherBlitzCollection($listTeacherBlitz($teacher, $request->filters()));
    }

    public function store(
        TeacherBlitzCreateRequest $request,
        string $topic,
        CreateTeacherBlitz $createTeacherBlitz,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $blitz = $createTeacherBlitz($teacher, $topic, $request->blitzAttributes());

        return (new TeacherBlitzResource($blitz))
            ->additional(['message' => 'Blitz task created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(
        TeacherBlitzShowRequest $request,
        string $blitz,
        ShowTeacherBlitz $showTeacherBlitz,
    ): TeacherBlitzResource {
        /** @var User $teacher */
        $teacher = $request->user();

        return new TeacherBlitzResource($showTeacherBlitz($teacher, $blitz));
    }

    public function update(
        TeacherBlitzUpdateRequest $request,
        string $blitz,
        UpdateTeacherBlitz $updateTeacherBlitz,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $updatedBlitz = $updateTeacherBlitz($teacher, $blitz, $request->blitzAttributes());

        return (new TeacherBlitzResource($updatedBlitz))
            ->additional(['message' => 'Blitz task updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function schedule(
        TeacherBlitzScheduleRequest $request,
        string $blitz,
        ScheduleTeacherBlitz $scheduleTeacherBlitz,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $scheduledBlitz = $scheduleTeacherBlitz($teacher, $blitz, $request->scheduledAttributes());

        return (new TeacherBlitzResource($scheduledBlitz))
            ->additional(['message' => 'Blitz task scheduled successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function archive(
        TeacherBlitzLifecycleRequest $request,
        string $blitz,
        ArchiveTeacherBlitz $archiveTeacherBlitz,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $archivedBlitz = $archiveTeacherBlitz($teacher, $blitz);

        return (new TeacherBlitzResource($archivedBlitz))
            ->additional(['message' => 'Blitz task archived successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }
}
