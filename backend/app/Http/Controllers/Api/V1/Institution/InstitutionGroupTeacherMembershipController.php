<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\AssignTeacherToInstitutionGroup;
use App\Actions\Institution\ListInstitutionGroupTeachers;
use App\Actions\Institution\RemoveTeacherFromInstitutionGroup;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionGroupTeacherMembershipAssignRequest;
use App\Http\Requests\Institution\InstitutionGroupTeacherMembershipIndexRequest;
use App\Http\Requests\Institution\InstitutionGroupTeacherMembershipRemoveRequest;
use App\Http\Resources\Institution\InstitutionGroupTeacherMembershipCollection;
use App\Http\Resources\Institution\InstitutionGroupTeacherMembershipResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Symfony\Component\HttpFoundation\Response as HttpResponse;

class InstitutionGroupTeacherMembershipController extends Controller
{
    public function index(
        InstitutionGroupTeacherMembershipIndexRequest $request,
        string $group,
        ListInstitutionGroupTeachers $listInstitutionGroupTeachers,
    ): InstitutionGroupTeacherMembershipCollection {
        /** @var User $actor */
        $actor = $request->user();

        $teachers = $listInstitutionGroupTeachers(
            actor: $actor,
            group: $group,
            search: $request->search(),
            isActive: $request->status(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        );

        return new InstitutionGroupTeacherMembershipCollection($teachers);
    }

    public function store(
        InstitutionGroupTeacherMembershipAssignRequest $request,
        string $group,
        AssignTeacherToInstitutionGroup $assignTeacherToInstitutionGroup,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $result = $assignTeacherToInstitutionGroup($actor, $group, $request->teacherIds());

        return InstitutionGroupTeacherMembershipResource::collection($result->members)
            ->additional(['message' => 'Teachers assigned to group successfully.'])
            ->response()
            ->setStatusCode($result->createdCount > 0 ? HttpResponse::HTTP_CREATED : HttpResponse::HTTP_OK);
    }

    public function destroy(
        InstitutionGroupTeacherMembershipRemoveRequest $request,
        string $group,
        string $teacher,
        RemoveTeacherFromInstitutionGroup $removeTeacherFromInstitutionGroup,
    ): Response {
        /** @var User $actor */
        $actor = $request->user();

        $removeTeacherFromInstitutionGroup($actor, $group, $teacher);

        return response()->noContent();
    }
}
