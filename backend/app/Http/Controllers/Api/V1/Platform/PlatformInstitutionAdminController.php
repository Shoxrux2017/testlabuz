<?php

namespace App\Http\Controllers\Api\V1\Platform;

use App\Actions\Platform\CreatePlatformInstitutionAdmin;
use App\Actions\Platform\ListPlatformInstitutionAdmins;
use App\Http\Controllers\Controller;
use App\Http\Requests\Platform\PlatformInstitutionAdminCreateRequest;
use App\Http\Requests\Platform\PlatformInstitutionAdminIndexRequest;
use App\Http\Resources\Platform\PlatformInstitutionAdminCollection;
use App\Http\Resources\Platform\PlatformInstitutionAdminResource;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class PlatformInstitutionAdminController extends Controller
{
    public function index(
        PlatformInstitutionAdminIndexRequest $request,
        string $institution,
        ListPlatformInstitutionAdmins $listAdmins,
    ): PlatformInstitutionAdminCollection {
        $admins = $listAdmins(
            institution: $this->resolveInstitution($institution),
            search: $request->search(),
            status: $request->status(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        );

        return new PlatformInstitutionAdminCollection($admins);
    }

    public function store(
        PlatformInstitutionAdminCreateRequest $request,
        string $institution,
        CreatePlatformInstitutionAdmin $createAdmin,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $admin = $createAdmin(
            actor: $actor,
            institution: $this->resolveInstitution($institution),
            fullName: $request->fullName(),
            loginName: $request->loginName(),
            email: $request->email(),
            phone: $request->phone(),
            password: $request->password(),
        );

        return (new PlatformInstitutionAdminResource($admin))
            ->additional(['message' => 'Institution admin created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
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
