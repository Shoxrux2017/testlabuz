<?php

namespace Database\Factories;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzAttemptExceptionReasonType;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<BlitzAttemptException>
 */
class BlitzAttemptExceptionFactory extends Factory
{
    public function definition(): array
    {
        return [
            'assessment_id' => fn () => BlitzTask::factory()->activeIndividual()->create()->assessment_id,
            'institution_id' => fn (array $attributes) => $this->assessmentFor($attributes)->institution_id,
            'assessment_student_id' => fn (array $attributes) => AssessmentStudent::factory()->state([
                'assessment_id' => $attributes['assessment_id'],
                'assigned_by_user_id' => $this->assessmentFor($attributes)->teacher_id,
            ]),
            'student_id' => fn (array $attributes) => AssessmentStudent::query()->findOrFail($attributes['assessment_student_id'])->student_id,
            'invalidated_attempt_id' => fn (array $attributes) => AssessmentAttempt::factory()->state([
                'assessment_student_id' => $attributes['assessment_student_id'],
                'attempt_number' => 1,
                'status' => AssessmentAttemptStatus::Submitted,
                'started_at' => now()->subSeconds(20),
                'submitted_at' => now()->subSeconds(10),
                'finalized_at' => now()->subSeconds(10),
                'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
                'locked_at' => now()->subSeconds(10),
                'official_score_eligible' => false,
            ]),
            'replacement_attempt_id' => null,
            'reason_type' => BlitzAttemptExceptionReasonType::Technical,
            'reason' => 'A technical interruption prevented completion of the normal attempt.',
            'granted_by_user_id' => fn (array $attributes) => $this->assessmentFor($attributes)->teacher_id,
            'granted_at' => now(),
        ];
    }

    public function withReplacementAttempt(): static
    {
        return $this->state(fn (array $attributes) => [
            'replacement_attempt_id' => fn (array $attributes) => AssessmentAttempt::factory()->state([
                'assessment_student_id' => $attributes['assessment_student_id'],
                'attempt_number' => 2,
            ]),
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function assessmentFor(array $attributes): Assessment
    {
        return Assessment::query()->findOrFail($attributes['assessment_id']);
    }
}
