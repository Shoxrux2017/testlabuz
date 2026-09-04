<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\SetTeacherTopicResultPair;
use App\Actions\Teacher\ShowTeacherTopicResultPair;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherTopicResultPairShowRequest;
use App\Http\Requests\Teacher\TeacherTopicResultPairUpdateRequest;
use App\Http\Resources\Teacher\TeacherTopicResultPairResource;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class TeacherTopicResultPairController extends Controller
{
    public function show(
        TeacherTopicResultPairShowRequest $request,
        string $topic,
        ShowTeacherTopicResultPair $showTeacherTopicResultPair,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $pair = $showTeacherTopicResultPair($teacher, $topic);

        if (! $pair instanceof TopicResultPair) {
            return response()->json(['data' => null]);
        }

        return (new TeacherTopicResultPairResource($pair))->response();
    }

    public function update(
        TeacherTopicResultPairUpdateRequest $request,
        string $topic,
        SetTeacherTopicResultPair $setTeacherTopicResultPair,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $pair = $setTeacherTopicResultPair($teacher, $topic, $request->homeworkAssessmentId());

        return (new TeacherTopicResultPairResource($pair))
            ->additional(['message' => 'Topic result pair updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }
}
