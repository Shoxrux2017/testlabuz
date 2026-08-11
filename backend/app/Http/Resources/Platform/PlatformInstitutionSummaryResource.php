<?php

namespace App\Http\Resources\Platform;

use Illuminate\Http\Request;

class PlatformInstitutionSummaryResource extends PlatformInstitutionResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return $this->platformFields(includeDetailFields: false);
    }
}
