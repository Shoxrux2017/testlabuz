<?php

namespace App\Http\Controllers\Api\V1\Platform;

use App\Actions\Platform\CreatePlatformInstitution;
use App\Actions\Platform\ListPlatformInstitutions;
use App\Actions\Platform\LoadPlatformInstitutionForDetail;
use App\Http\Controllers\Controller;
use App\Http\Requests\Platform\PlatformInstitutionCreateRequest;
use App\Http\Requests\Platform\PlatformInstitutionIndexRequest;
use App\Http\Resources\Platform\PlatformInstitutionCreatedResource;
use App\Http\Resources\Platform\PlatformInstitutionDetailResource;
use App\Http\Resources\Platform\PlatformInstitutionSummaryCollection;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class PlatformInstitutionController extends Controller
{
    public function index(
        PlatformInstitutionIndexRequest $request,
        ListPlatformInstitutions $listInstitutions,
    ): PlatformInstitutionSummaryCollection {
        $institutions = $listInstitutions(
            search: $request->search(),
            status: $request->status(),
            type: $request->type(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        );

        return new PlatformInstitutionSummaryCollection($institutions);
    }

    public function store(
        PlatformInstitutionCreateRequest $request,
        CreatePlatformInstitution $createInstitution,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $institution = $createInstitution(
            actor: $actor,
            name: $request->name(),
            type: $request->type(),
            status: $request->status(),
            contactEmail: $request->contactEmail(),
            contactPhone: $request->contactPhone(),
            address: $request->address(),
            description: $request->description(),
        );

        return (new PlatformInstitutionCreatedResource($institution))
            ->additional(['message' => 'Institution created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(
        Institution $institution,
        LoadPlatformInstitutionForDetail $loadInstitutionForDetail,
    ): PlatformInstitutionDetailResource {
        return new PlatformInstitutionDetailResource($loadInstitutionForDetail($institution));
    }
}
