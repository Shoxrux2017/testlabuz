<?php

namespace App\Http\Controllers\Api\V1\Platform;

use App\Actions\Platform\ListPlatformInstitutions;
use App\Actions\Platform\LoadPlatformInstitutionForDetail;
use App\Http\Controllers\Controller;
use App\Http\Requests\Platform\PlatformInstitutionIndexRequest;
use App\Http\Resources\Platform\PlatformInstitutionDetailResource;
use App\Http\Resources\Platform\PlatformInstitutionSummaryCollection;
use App\Models\Institution;

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

    public function show(
        Institution $institution,
        LoadPlatformInstitutionForDetail $loadInstitutionForDetail,
    ): PlatformInstitutionDetailResource {
        return new PlatformInstitutionDetailResource($loadInstitutionForDetail($institution));
    }
}
