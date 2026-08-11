<?php

namespace App\Http\Resources\Platform;

use Illuminate\Http\Request;

class PlatformRecentInstitutionResource extends PlatformInstitutionResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'type' => $this->type->value,
            'status' => $this->status->value,
            'created_at' => $this->timestamp($this->created_at),
        ];
    }
}
