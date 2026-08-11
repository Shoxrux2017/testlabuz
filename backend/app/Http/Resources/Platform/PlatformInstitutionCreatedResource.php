<?php

namespace App\Http\Resources\Platform;

use Illuminate\Http\Request;

class PlatformInstitutionCreatedResource extends PlatformInstitutionResource
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
            'contact_email' => $this->contact_email,
            'contact_phone' => $this->contact_phone,
            'address' => $this->address,
            'description' => $this->description,
            'created_at' => $this->timestamp($this->created_at),
            'updated_at' => $this->timestamp($this->updated_at),
        ];
    }
}
