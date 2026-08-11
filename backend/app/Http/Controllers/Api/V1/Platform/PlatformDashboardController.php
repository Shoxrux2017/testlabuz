<?php

namespace App\Http\Controllers\Api\V1\Platform;

use App\Actions\Platform\ShowPlatformDashboard;
use App\Http\Controllers\Controller;
use App\Http\Requests\Platform\PlatformDashboardRequest;
use App\Http\Resources\Platform\PlatformDashboardResource;

class PlatformDashboardController extends Controller
{
    public function __invoke(
        PlatformDashboardRequest $request,
        ShowPlatformDashboard $showDashboard,
    ): PlatformDashboardResource {
        return new PlatformDashboardResource($showDashboard());
    }
}
