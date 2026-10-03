<?php

namespace App\Http\Controllers\Api\V1\Parent;

use App\Actions\Parent\ShowParentChildTopicResult;
use App\Http\Controllers\Controller;
use App\Http\Requests\Parent\ParentChildTopicResultRequest;
use App\Http\Resources\Student\StudentTopicResultResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class ParentChildTopicResultController extends Controller
{
    public function show(
        ParentChildTopicResultRequest $request,
        string $student,
        string $topic,
        ShowParentChildTopicResult $showParentChildTopicResult,
    ): JsonResponse|StudentTopicResultResource {
        /** @var User $parent */
        $parent = $request->user();
        $reading = $showParentChildTopicResult($parent, $student, $topic);

        // The Student result shape (docs/09 §30.5), with the Parent's visibility.
        return $reading === null ? response()->json(['data' => null]) : new StudentTopicResultResource($reading);
    }
}
