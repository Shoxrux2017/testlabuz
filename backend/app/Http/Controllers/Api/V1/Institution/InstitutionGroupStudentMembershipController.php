<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\AssignStudentToInstitutionGroup;
use App\Actions\Institution\ListInstitutionGroupStudents;
use App\Actions\Institution\RemoveStudentFromInstitutionGroup;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionGroupStudentMembershipAssignRequest;
use App\Http\Requests\Institution\InstitutionGroupStudentMembershipIndexRequest;
use App\Http\Requests\Institution\InstitutionGroupStudentMembershipRemoveRequest;
use App\Http\Resources\Institution\InstitutionGroupStudentMembershipCollection;
use App\Http\Resources\Institution\InstitutionGroupStudentMembershipResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Symfony\Component\HttpFoundation\Response as HttpResponse;

class InstitutionGroupStudentMembershipController extends Controller
{
    public function index(
        InstitutionGroupStudentMembershipIndexRequest $request,
        string $group,
        ListInstitutionGroupStudents $listInstitutionGroupStudents,
    ): InstitutionGroupStudentMembershipCollection {
        /** @var User $actor */
        $actor = $request->user();

        $students = $listInstitutionGroupStudents(
            actor: $actor,
            group: $group,
            search: $request->search(),
            isActive: $request->status(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        );

        return new InstitutionGroupStudentMembershipCollection($students);
    }

    public function store(
        InstitutionGroupStudentMembershipAssignRequest $request,
        string $group,
        AssignStudentToInstitutionGroup $assignStudentToInstitutionGroup,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $result = $assignStudentToInstitutionGroup($actor, $group, $request->studentIds());

        return InstitutionGroupStudentMembershipResource::collection($result->members)
            ->additional(['message' => 'Students assigned to group successfully.'])
            ->response()
            ->setStatusCode($result->createdCount > 0 ? HttpResponse::HTTP_CREATED : HttpResponse::HTTP_OK);
    }

    public function destroy(
        InstitutionGroupStudentMembershipRemoveRequest $request,
        string $group,
        string $student,
        RemoveStudentFromInstitutionGroup $removeStudentFromInstitutionGroup,
    ): Response {
        /** @var User $actor */
        $actor = $request->user();

        $removeStudentFromInstitutionGroup($actor, $group, $student);

        return response()->noContent();
    }
}
