<?php

namespace App\Actions\Platform;

use App\Models\Institution;

class UpdatePlatformInstitution
{
    /**
     * @param  array<string, mixed>  $profileAttributes
     */
    public function __invoke(Institution $institution, array $profileAttributes): Institution
    {
        foreach ($profileAttributes as $attribute => $value) {
            $institution->setAttribute($attribute, $value);
        }

        $institution->save();

        return $institution->refresh();
    }
}
