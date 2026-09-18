<?php

namespace App\Http\Resources\Teacher;

use App\Models\BlitzAttemptException;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin BlitzAttemptException */
final class TeacherBlitzAttemptExceptionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'blitz_id' => $this->assessment_id,
            'student_id' => $this->student_id,
            'invalidated_attempt_id' => $this->invalidated_attempt_id,
            'replacement_attempt_id' => $this->replacement_attempt_id,
            'reason_type' => $this->reason_type->value,
            'reason' => $this->reason,
            'granted_at' => $this->granted_at->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            'replacement_attempt_available' => $this->replacement_attempt_available,
        ];
    }
}
