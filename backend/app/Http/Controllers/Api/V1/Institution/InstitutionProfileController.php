<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ShowInstitutionProfile;
use App\Actions\Institution\UpdateInstitutionProfile;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionProfileShowRequest;
use App\Http\Requests\Institution\InstitutionProfileUpdateRequest;
use App\Http\Resources\Institution\InstitutionProfileResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class InstitutionProfileController extends Controller
{
    public function show(
        InstitutionProfileShowRequest $request,
        ShowInstitutionProfile $showInstitutionProfile,
    ): InstitutionProfileResource {
        /** @var User $actor */
        $actor = $request->user();

        return new InstitutionProfileResource($showInstitutionProfile($actor));
    }

    public function update(
        InstitutionProfileUpdateRequest $request,
        ShowInstitutionProfile $showInstitutionProfile,
        UpdateInstitutionProfile $updateInstitutionProfile,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $institution = $updateInstitutionProfile(
            institution: $showInstitutionProfile($actor),
            profileAttributes: $request->profileAttributes(),
        );

        return (new InstitutionProfileResource($institution))
            ->additional(['message' => 'Institution profile updated successfully.'])
            ->response()
            ->setStatusCode(Response::HTTP_OK);
    }
}
