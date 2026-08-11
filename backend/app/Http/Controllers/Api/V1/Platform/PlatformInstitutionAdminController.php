<?php

namespace App\Http\Controllers\Api\V1\Platform;

use App\Actions\Platform\ChangePlatformInstitutionAdminLifecycle;
use App\Actions\Platform\CreatePlatformInstitutionAdmin;
use App\Actions\Platform\ListPlatformInstitutionAdmins;
use App\Actions\Platform\UpdatePlatformInstitutionAdmin;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Platform\PlatformInstitutionAdminCreateRequest;
use App\Http\Requests\Platform\PlatformInstitutionAdminIndexRequest;
use App\Http\Requests\Platform\PlatformInstitutionAdminLifecycleRequest;
use App\Http\Requests\Platform\PlatformInstitutionAdminUpdateRequest;
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

    public function update(
        PlatformInstitutionAdminUpdateRequest $request,
        string $user,
        UpdatePlatformInstitutionAdmin $updateAdmin,
    ): JsonResponse {
        $updatedAdmin = $updateAdmin(
            admin: $this->resolveInstitutionAdmin($user),
            profileAttributes: $request->profileAttributes(),
        );

        return (new PlatformInstitutionAdminResource($updatedAdmin))
            ->additional(['message' => 'Institution admin updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function activate(
        PlatformInstitutionAdminLifecycleRequest $request,
        string $user,
        ChangePlatformInstitutionAdminLifecycle $changeAdminLifecycle,
    ): JsonResponse {
        $activatedAdmin = $changeAdminLifecycle->activate($this->resolveInstitutionAdmin($user));

        return (new PlatformInstitutionAdminResource($activatedAdmin))
            ->additional(['message' => 'Institution admin activated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }

    public function deactivate(
        PlatformInstitutionAdminLifecycleRequest $request,
        string $user,
        ChangePlatformInstitutionAdminLifecycle $changeAdminLifecycle,
    ): JsonResponse {
        $deactivatedAdmin = $changeAdminLifecycle->deactivate($this->resolveInstitutionAdmin($user));

        return (new PlatformInstitutionAdminResource($deactivatedAdmin))
            ->additional(['message' => 'Institution admin deactivated successfully.'])
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

    private function resolveInstitutionAdmin(string $user): User
    {
        if (! Str::isUuid($user)) {
            throw new NotFoundHttpException;
        }

        $resolvedAdmin = User::query()
            ->whereKey($user)
            ->where('role', UserRole::InstitutionAdmin->value)
            ->whereNotNull('institution_id')
            ->first();

        if (! $resolvedAdmin instanceof User) {
            throw new NotFoundHttpException;
        }

        return $resolvedAdmin;
    }
}
