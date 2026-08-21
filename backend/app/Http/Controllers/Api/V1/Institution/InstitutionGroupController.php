<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ArchiveInstitutionGroup;
use App\Actions\Institution\CreateInstitutionGroup;
use App\Actions\Institution\ListInstitutionGroups;
use App\Actions\Institution\ShowInstitutionGroup;
use App\Actions\Institution\UpdateInstitutionGroup;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionGroupArchiveRequest;
use App\Http\Requests\Institution\InstitutionGroupCreateRequest;
use App\Http\Requests\Institution\InstitutionGroupIndexRequest;
use App\Http\Requests\Institution\InstitutionGroupShowRequest;
use App\Http\Requests\Institution\InstitutionGroupUpdateRequest;
use App\Http\Resources\Institution\InstitutionGroupCollection;
use App\Http\Resources\Institution\InstitutionGroupResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class InstitutionGroupController extends Controller
{
    public function index(
        InstitutionGroupIndexRequest $request,
        ListInstitutionGroups $listInstitutionGroups,
    ): InstitutionGroupCollection {
        /** @var User $actor */
        $actor = $request->user();

        $groups = $listInstitutionGroups(
            actor: $actor,
            search: $request->search(),
            status: $request->status(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        );

        return new InstitutionGroupCollection($groups);
    }

    public function store(
        InstitutionGroupCreateRequest $request,
        CreateInstitutionGroup $createInstitutionGroup,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $group = $createInstitutionGroup($actor, $request->groupAttributes());

        return (new InstitutionGroupResource($group))
            ->additional(['message' => 'Group created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(
        InstitutionGroupShowRequest $request,
        string $group,
        ShowInstitutionGroup $showInstitutionGroup,
    ): InstitutionGroupResource {
        /** @var User $actor */
        $actor = $request->user();

        return new InstitutionGroupResource($showInstitutionGroup($actor, $group));
    }

    public function update(
        InstitutionGroupUpdateRequest $request,
        string $group,
        UpdateInstitutionGroup $updateInstitutionGroup,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $updatedGroup = $updateInstitutionGroup($actor, $group, $request->groupAttributes());

        return (new InstitutionGroupResource($updatedGroup))
            ->additional(['message' => 'Group updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function archive(
        InstitutionGroupArchiveRequest $request,
        string $group,
        ArchiveInstitutionGroup $archiveInstitutionGroup,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $archivedGroup = $archiveInstitutionGroup($actor, $group);

        return (new InstitutionGroupResource($archivedGroup))
            ->additional(['message' => 'Group archived successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }
}
