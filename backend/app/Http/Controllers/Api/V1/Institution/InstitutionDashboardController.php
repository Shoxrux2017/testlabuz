<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ShowInstitutionDashboard;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionDashboardRequest;
use App\Http\Resources\Institution\InstitutionDashboardResource;
use App\Models\User;

class InstitutionDashboardController extends Controller
{
    public function __invoke(
        InstitutionDashboardRequest $request,
        ShowInstitutionDashboard $showDashboard,
    ): InstitutionDashboardResource {
        /** @var User $actor */
        $actor = $request->user();

        return new InstitutionDashboardResource($showDashboard($actor));
    }
}
