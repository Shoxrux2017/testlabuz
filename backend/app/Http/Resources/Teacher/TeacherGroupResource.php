<?php

namespace App\Http\Resources\Teacher;

use App\Models\Group;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Group */
class TeacherGroupResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'level' => $this->level,
            'subject_direction' => $this->subject_direction,
            'status' => $this->status->value,
        ];
    }
}
