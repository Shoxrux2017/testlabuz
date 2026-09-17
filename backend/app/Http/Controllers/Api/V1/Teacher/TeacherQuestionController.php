<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\AddTeacherAssessmentQuestion;
use App\Actions\Teacher\DeleteTeacherQuestion;
use App\Actions\Teacher\ReorderTeacherAssessmentQuestions;
use App\Actions\Teacher\UpdateTeacherQuestion;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherQuestionCreateRequest;
use App\Http\Requests\Teacher\TeacherQuestionDeleteRequest;
use App\Http\Requests\Teacher\TeacherQuestionReorderRequest;
use App\Http\Requests\Teacher\TeacherQuestionUpdateRequest;
use App\Http\Resources\Teacher\TeacherAssessmentAuthoringResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class TeacherQuestionController extends Controller
{
    public function store(
        TeacherQuestionCreateRequest $request,
        string $assessment,
        AddTeacherAssessmentQuestion $addQuestion,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $assessment = $addQuestion($teacher, $assessment, $request->questionAttributes());

        return (new TeacherAssessmentAuthoringResource($assessment))
            ->additional(['message' => 'Question created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function update(
        TeacherQuestionUpdateRequest $request,
        string $question,
        UpdateTeacherQuestion $updateQuestion,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $assessment = $updateQuestion($teacher, $question, $request->questionAttributes());

        return (new TeacherAssessmentAuthoringResource($assessment))
            ->additional(['message' => 'Question updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function destroy(
        TeacherQuestionDeleteRequest $request,
        string $question,
        DeleteTeacherQuestion $deleteQuestion,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $assessment = $deleteQuestion($teacher, $question);

        return (new TeacherAssessmentAuthoringResource($assessment))
            ->additional(['message' => 'Question deleted successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function reorder(
        TeacherQuestionReorderRequest $request,
        string $assessment,
        ReorderTeacherAssessmentQuestions $reorderQuestions,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();
        $assessment = $reorderQuestions($teacher, $assessment, $request->questionIds());

        return (new TeacherAssessmentAuthoringResource($assessment))
            ->additional(['message' => 'Questions reordered successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }
}
