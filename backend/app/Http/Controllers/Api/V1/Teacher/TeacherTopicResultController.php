<?php

namespace App\Http\Controllers\Api\V1\Teacher;

use App\Actions\Teacher\ListTeacherTopicResults;
use App\Actions\Teacher\ReleaseTeacherTopicResult;
use App\Actions\Teacher\ReleaseTeacherTopicResults;
use App\Actions\Teacher\ShowTeacherTopicResult;
use App\Actions\Teacher\UpdateTeacherTopicResultComment;
use App\Enums\TopicResultReleaseAudience;
use App\Http\Controllers\Controller;
use App\Http\Requests\Teacher\TeacherTopicLifecycleRequest;
use App\Http\Requests\Teacher\TeacherTopicResultCommentRequest;
use App\Http\Requests\Teacher\TeacherTopicResultIndexRequest;
use App\Http\Requests\Teacher\TeacherTopicResultShowRequest;
use App\Http\Resources\Teacher\TeacherTopicResultBulkResource;
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

    public function releaseToStudent(TeacherTopicLifecycleRequest $request, string $topic, string $student, ReleaseTeacherTopicResult $release): JsonResponse
    {
        return $this->released($request, $topic, $student, $release, TopicResultReleaseAudience::Student, 'Topic result released to the Student.');
    }

    public function releaseToParent(TeacherTopicLifecycleRequest $request, string $topic, string $student, ReleaseTeacherTopicResult $release): JsonResponse
    {
        return $this->released($request, $topic, $student, $release, TopicResultReleaseAudience::Parent, 'Topic result released to Parents.');
    }

    public function releaseAllToStudents(TeacherTopicLifecycleRequest $request, string $topic, ReleaseTeacherTopicResults $release): JsonResponse
    {
        return $this->releasedAll($request, $topic, $release, TopicResultReleaseAudience::Student, 'Topic results released to Students.');
    }

    public function releaseAllToParents(TeacherTopicLifecycleRequest $request, string $topic, ReleaseTeacherTopicResults $release): JsonResponse
    {
        return $this->releasedAll($request, $topic, $release, TopicResultReleaseAudience::Parent, 'Topic results released to Parents.');
    }

    private function released(
        TeacherTopicLifecycleRequest $request,
        string $topic,
        string $student,
        ReleaseTeacherTopicResult $release,
        TopicResultReleaseAudience $audience,
        string $message,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();

        return (new TeacherTopicResultDetailResource($release($teacher, $topic, $student, $audience)))
            ->additional(['message' => $message])
            ->response();
    }

    private function releasedAll(
        TeacherTopicLifecycleRequest $request,
        string $topic,
        ReleaseTeacherTopicResults $release,
        TopicResultReleaseAudience $audience,
        string $message,
    ): JsonResponse {
        /** @var User $teacher */
        $teacher = $request->user();

        return (new TeacherTopicResultBulkResource($release($teacher, $topic, $audience)))
            ->additional(['message' => $message])
            ->response();
    }
}
