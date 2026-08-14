<?php

namespace App\Actions\Institution;

use App\Models\Institution;
use App\Models\User;
use RuntimeException;

class ShowInstitutionProfile
{
    public function __invoke(User $actor): Institution
    {
        $institution = $actor->institution()->first();

        if (! $institution instanceof Institution) {
            throw new RuntimeException('The authenticated institution could not be resolved.');
        }

        return $institution;
    }
}
