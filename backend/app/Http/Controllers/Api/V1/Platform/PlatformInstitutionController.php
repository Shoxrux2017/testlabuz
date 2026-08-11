<?php

namespace App\Http\Controllers\Api\V1\Platform;

use App\Actions\Platform\ChangePlatformInstitutionLifecycle;
use App\Actions\Platform\CreatePlatformInstitution;
use App\Actions\Platform\ListPlatformInstitutions;
use App\Actions\Platform\LoadPlatformInstitutionForDetail;
use App\Actions\Platform\UpdatePlatformInstitution;
use App\Http\Controllers\Controller;
use App\Http\Requests\Platform\PlatformInstitutionCreateRequest;
use App\Http\Requests\Platform\PlatformInstitutionIndexRequest;
use App\Http\Requests\Platform\PlatformInstitutionLifecycleRequest;
use App\Http\Requests\Platform\PlatformInstitutionUpdateRequest;
use App\Http\Resources\Platform\PlatformInstitutionCreatedResource;
use App\Http\Resources\Platform\PlatformInstitutionDetailResource;
use App\Http\Resources\Platform\PlatformInstitutionLifecycleResource;
use App\Http\Resources\Platform\PlatformInstitutionSummaryCollection;
use App\Http\Resources\Platform\PlatformInstitutionUpdatedResource;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

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
        string $institution,
        LoadPlatformInstitutionForDetail $loadInstitutionForDetail,
    ): PlatformInstitutionDetailResource {
        return new PlatformInstitutionDetailResource(
            $loadInstitutionForDetail($this->resolveInstitution($institution))
        );
    }

    public function update(
        PlatformInstitutionUpdateRequest $request,
        string $institution,
        UpdatePlatformInstitution $updateInstitution,
    ): JsonResponse {
        $updatedInstitution = $updateInstitution(
            institution: $this->resolveInstitution($institution),
            profileAttributes: $request->profileAttributes(),
        );

        return (new PlatformInstitutionUpdatedResource($updatedInstitution))
            ->additional(['message' => 'Institution updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function activate(
        PlatformInstitutionLifecycleRequest $request,
        string $institution,
        ChangePlatformInstitutionLifecycle $changeInstitutionLifecycle,
    ): JsonResponse {
        $activatedInstitution = $changeInstitutionLifecycle->activate($this->resolveInstitution($institution));

        return (new PlatformInstitutionLifecycleResource($activatedInstitution))
            ->additional(['message' => 'Institution activated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function deactivate(
        PlatformInstitutionLifecycleRequest $request,
        string $institution,
        ChangePlatformInstitutionLifecycle $changeInstitutionLifecycle,
    ): JsonResponse {
        $deactivatedInstitution = $changeInstitutionLifecycle->deactivate($this->resolveInstitution($institution));

        return (new PlatformInstitutionLifecycleResource($deactivatedInstitution))
            ->additional(['message' => 'Institution deactivated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    private function resolveInstitution(string $institution): Institution
    {
        if (! Str::isUuid($institution)) {
            throw new NotFoundHttpException;
        }

        $resolvedInstitution = Institution::query()->find($institution);

        if (! $resolvedInstitution instanceof Institution) {
            throw new NotFoundHttpException;
        }

        return $resolvedInstitution;
    }
}
