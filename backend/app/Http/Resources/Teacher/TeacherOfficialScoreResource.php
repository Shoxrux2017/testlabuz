<?php

namespace App\Http\Resources\Teacher;

use App\Support\Checking\OfficialScoreReading;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One Student's official task score for a Teacher (docs/09 §24.1); every result field is null
 * unless the score is ready.
 *
 * @property OfficialScoreReading $resource
 */
class TeacherOfficialScoreResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $reading = $this->resource;
        $score = $reading->score;

        return [
            'assessment_id' => $reading->assessment->id,
            'assessment_type' => $reading->assessment->type->value,
            'student_id' => $reading->recipient->student_id,
            'status' => $reading->status->value,
            'official_attempt_id' => $score?->official_attempt_id,
            'attempt_number' => $reading->attempt?->attempt_number,
            'normalized_score' => $score === null ? null : (float) $score->normalized_score,
            'selection_policy_code' => $score?->selection_policy_code->value,
            'selected_at' => TeacherSubmissionResource::timestamp($score?->selected_at),
        ];
    }
}
