<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ShowInstitutionAssessmentSettings;
use App\Actions\Institution\UpdateInstitutionAssessmentSettings;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionAssessmentSettingsShowRequest;
use App\Http\Requests\Institution\InstitutionAssessmentSettingsUpdateRequest;
use App\Http\Resources\Institution\InstitutionAssessmentSettingsResource;
use App\Models\User;

class InstitutionAssessmentSettingsController extends Controller
{
    public function show(
        InstitutionAssessmentSettingsShowRequest $request,
        ShowInstitutionAssessmentSettings $showInstitutionAssessmentSettings,
    ): InstitutionAssessmentSettingsResource {
        /** @var User $actor */
        $actor = $request->user();

        return new InstitutionAssessmentSettingsResource($showInstitutionAssessmentSettings($actor));
    }

    public function update(
        InstitutionAssessmentSettingsUpdateRequest $request,
        UpdateInstitutionAssessmentSettings $updateInstitutionAssessmentSettings,
    ): InstitutionAssessmentSettingsResource {
        /** @var User $actor */
        $actor = $request->user();

        return new InstitutionAssessmentSettingsResource($updateInstitutionAssessmentSettings(
            actor: $actor,
            acceptableScoreDifference: $request->acceptableScoreDifference(),
            blitzTimerStartMode: $request->blitzTimerStartMode(),
            studentResultReleaseMode: $request->studentResultReleaseMode(),
            parentResultReleaseMode: $request->parentResultReleaseMode(),
            timezone: $request->timezone(),
            learningMaterialMaxMb: $request->learningMaterialMaxMb(),
            studentSubmissionMaxMb: $request->studentSubmissionMaxMb(),
        ));
    }
}
