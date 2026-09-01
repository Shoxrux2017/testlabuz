<?php

namespace Database\Factories;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<AssessmentAttempt>
 */
class AssessmentAttemptFactory extends Factory
{
    public function definition(): array
    {
        return [
            'assessment_student_id' => AssessmentStudent::factory(),
            'institution_id' => fn (array $attributes) => $this->recipientFor($attributes)->institution_id,
            'assessment_id' => fn (array $attributes) => $this->recipientFor($attributes)->assessment_id,
            'student_id' => fn (array $attributes) => $this->recipientFor($attributes)->student_id,
            'attempt_number' => 1,
            'status' => AssessmentAttemptStatus::InProgress,
            'started_at' => now(),
            'deadline_at' => null,
            'submitted_at' => null,
            'finalized_at' => null,
            'finalization_reason' => null,
            'locked_at' => null,
            'official_score_eligible' => true,
            'earned_points' => null,
            'possible_points' => '0.000000',
            'normalized_score' => null,
            'scoring_completed_at' => null,
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function recipientFor(array $attributes): AssessmentStudent
    {
        return AssessmentStudent::query()->findOrFail($attributes['assessment_student_id']);
    }
}
