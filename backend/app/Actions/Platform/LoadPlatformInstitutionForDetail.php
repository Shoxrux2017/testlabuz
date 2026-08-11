<?php

namespace App\Actions\Platform;

use App\Models\Institution;
use App\Support\Platform\InstitutionUserCounts;

class LoadPlatformInstitutionForDetail
{
    public function __invoke(Institution $institution): Institution
    {
        return InstitutionUserCounts::loadFor($institution);
    }
}
