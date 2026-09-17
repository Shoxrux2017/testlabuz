<?php

namespace App\Http\Resources\Student;

use App\Models\Assessment;
use Illuminate\Http\Request;

/** @mixin Assessment */
class StudentBlitzResource extends StudentBlitzSummaryResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $summary = parent::toArray($request);

        return [
            'id' => $summary['id'],
            'topic' => $summary['topic'],
            'title' => $summary['title'],
            'description' => $this->description,
            'student_instructions' => $this->student_instructions,
            'status' => $summary['status'],
            'duration_seconds' => $summary['duration_seconds'],
            'total_possible_points' => (float) $this->total_possible_points,
            'timing' => $summary['timing'],
            'attempts' => $summary['attempts'],
        ];
    }
}
