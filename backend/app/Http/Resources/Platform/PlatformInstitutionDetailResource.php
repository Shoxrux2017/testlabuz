<?php

namespace App\Http\Resources\Platform;

use Illuminate\Http\Request;

class PlatformInstitutionDetailResource extends PlatformInstitutionResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return $this->platformFields(includeDetailFields: true);
    }
}
