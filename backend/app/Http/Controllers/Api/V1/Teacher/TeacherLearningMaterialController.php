<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ListTeacherLearningMaterials;
use App\Actions\Teacher\RemoveTeacherLearningMaterial;
use App\Actions\Teacher\ReplaceTeacherLearningMaterial;
use App\Actions\Teacher\UpdateTeacherLearningMaterial;
use App\Actions\Teacher\UploadTeacherLearningMaterial;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherLearningMaterialIndexRequest;
use App\Http\Requests\Teacher\TeacherLearningMaterialRemoveRequest;
use App\Http\Requests\Teacher\TeacherLearningMaterialReplaceRequest;
use App\Http\Requests\Teacher\TeacherLearningMaterialUpdateRequest;
use App\Http\Requests\Teacher\TeacherLearningMaterialUploadRequest;
use App\Http\Resources\Teacher\TeacherLearningMaterialCollection;
use App\Http\Resources\Teacher\TeacherLearningMaterialResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Symfony\Component\HttpFoundation\Response as HttpResponse;

class TeacherLearningMaterialController extends Controller
{
    public function index(
        TeacherLearningMaterialIndexRequest $request,
        string $topic,
        ListTeacherLearningMaterials $listTeacherLearningMaterials,
    ): TeacherLearningMaterialCollection {
        /** @var User $teacher */
        $teacher = $request->user();
        $list = $listTeacherLearningMaterials($teacher, $topic);

        return new TeacherLearningMaterialCollection($list->materials, $list->maxSizeBytes);
    }

    public function store(
        TeacherLearningMaterialUploadRequest $request,
        string $topic,
        UploadTeacherLearningMaterial $uploadTeacherLearningMaterial,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $material = $uploadTeacherLearningMaterial($teacher, $topic, $request->upload(), $request->title());

        return (new TeacherLearningMaterialResource($material))
            ->response()
            ->setStatusCode(HttpResponse::HTTP_CREATED);
    }

    public function replace(
        TeacherLearningMaterialReplaceRequest $request,
        string $material,
        ReplaceTeacherLearningMaterial $replaceTeacherLearningMaterial,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $replacedMaterial = $replaceTeacherLearningMaterial($teacher, $material, $request->upload());

        return (new TeacherLearningMaterialResource($replacedMaterial))
            ->additional(['message' => 'Learning material replaced successfully.'])
            ->response()
            ->setStatusCode(HttpResponse::HTTP_OK);
    }

    public function update(
        TeacherLearningMaterialUpdateRequest $request,
        string $material,
        UpdateTeacherLearningMaterial $updateTeacherLearningMaterial,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $updatedMaterial = $updateTeacherLearningMaterial($teacher, $material, $request->title());

        return (new TeacherLearningMaterialResource($updatedMaterial))
            ->additional(['message' => 'Learning material updated successfully.'])
            ->response()
            ->setStatusCode(HttpResponse::HTTP_OK);
    }

    public function destroy(
        TeacherLearningMaterialRemoveRequest $request,
        string $material,
        RemoveTeacherLearningMaterial $removeTeacherLearningMaterial,
    ): Response {
        /** @var User $teacher */
        $teacher = $request->user();
        $removeTeacherLearningMaterial($teacher, $material);

        return response()->noContent();
    }
}
