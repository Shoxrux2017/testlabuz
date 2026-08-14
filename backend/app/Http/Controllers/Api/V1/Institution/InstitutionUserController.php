<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\CreateInstitutionUser;
use App\Actions\Institution\ListInstitutionUsers;
use App\Actions\Institution\ShowInstitutionUser;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionUserCreateRequest;
use App\Http\Requests\Institution\InstitutionUserIndexRequest;
use App\Http\Requests\Institution\InstitutionUserShowRequest;
use App\Http\Resources\Institution\InstitutionUserCollection;
use App\Http\Resources\Institution\InstitutionUserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class InstitutionUserController extends Controller
{
    public function index(
        InstitutionUserIndexRequest $request,
        ListInstitutionUsers $listInstitutionUsers,
    ): InstitutionUserCollection {
        /** @var User $actor */
        $actor = $request->user();

        $users = $listInstitutionUsers(
            actor: $actor,
            role: $request->role(),
            status: $request->status(),
            search: $request->search(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        );

        return new InstitutionUserCollection($users);
    }

    public function store(
        InstitutionUserCreateRequest $request,
        CreateInstitutionUser $createInstitutionUser,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $user = $createInstitutionUser(
            actor: $actor,
            role: $request->role(),
            fullName: $request->fullName(),
            loginName: $request->loginName(),
            email: $request->email(),
            phone: $request->phone(),
            password: $request->password(),
        );

        return (new InstitutionUserResource($user))
            ->additional(['message' => 'Institution user created successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(
        InstitutionUserShowRequest $request,
        string $user,
        ShowInstitutionUser $showInstitutionUser,
    ): InstitutionUserResource {
        /** @var User $actor */
        $actor = $request->user();

        return new InstitutionUserResource($showInstitutionUser($actor, $user));
    }
}
