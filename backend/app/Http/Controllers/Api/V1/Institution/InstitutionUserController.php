<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ListInstitutionUsers;
use App\Actions\Institution\ShowInstitutionUser;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionUserIndexRequest;
use App\Http\Requests\Institution\InstitutionUserShowRequest;
use App\Http\Resources\Institution\InstitutionUserCollection;
use App\Http\Resources\Institution\InstitutionUserResource;
use App\Models\User;

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
