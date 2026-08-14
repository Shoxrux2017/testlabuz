<?php

namespace App\Actions\Institution;

use App\Models\InstitutionSetting;
use App\Models\User;
use RuntimeException;

class ShowInstitutionAssessmentSettings
{
    public function __invoke(User $actor): InstitutionSetting
    {
        if ($actor->institution_id === null) {
            throw new RuntimeException;
        }

        $settings = InstitutionSetting::query()
            ->where('institution_id', $actor->institution_id)
            ->first();

        if (! $settings instanceof InstitutionSetting) {
            throw new RuntimeException;
        }

        return $settings;
    }
}
