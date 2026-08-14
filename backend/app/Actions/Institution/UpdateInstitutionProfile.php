<?php

namespace App\Actions\Institution;

use App\Models\Institution;

class UpdateInstitutionProfile
{
    /**
     * @param  array<string, mixed>  $profileAttributes
     */
    public function __invoke(Institution $institution, array $profileAttributes): Institution
    {
        foreach ($profileAttributes as $attribute => $value) {
            $institution->setAttribute($attribute, $value);
        }

        if (! $institution->isDirty()) {
            return $institution;
        }

        $institution->save();

        return $institution->refresh();
    }
}
