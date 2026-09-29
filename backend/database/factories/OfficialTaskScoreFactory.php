<?php

namespace Database\Factories;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\OfficialScoreSelectionPolicy;
use App\Models\AssessmentAttempt;
use App\Models\OfficialTaskScore;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<OfficialTaskScore>
 */
class OfficialTaskScoreFactory extends Factory
{
    public function definition(): array
    {
        return [
            'official_attempt_id' => fn () => AssessmentAttempt::factory()->create([
                'status' => AssessmentAttemptStatus::Checked,
                'started_at' => now()->subMinutes(20),
                'submitted_at' => now()->subMinutes(10),
                'finalized_at' => now()->subMinutes(10),
                'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
                'locked_at' => now()->subMinutes(10),
                'earned_points' => '4.00000000',
                'possible_points' => '5.000000',
                'normalized_score' => '80.00000000',
                'scoring_completed_at' => now()->subMinutes(5),
            ])->id,
            'institution_id' => fn (array $attributes) => $this->attemptFor($attributes)->institution_id,
            'assessment_id' => fn (array $attributes) => $this->attemptFor($attributes)->assessment_id,
            'student_id' => fn (array $attributes) => $this->attemptFor($attributes)->student_id,
            'normalized_score' => fn (array $attributes) => $this->attemptFor($attributes)->normalized_score,
            'selection_policy_code' => OfficialScoreSelectionPolicy::HighestValidCompleted,
            'selected_by_user_id' => null,
            'selected_at' => now(),
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function attemptFor(array $attributes): AssessmentAttempt
    {
        return AssessmentAttempt::query()->findOrFail($attributes['official_attempt_id']);
    }
}
