<?php

namespace Database\Factories;

use App\Enums\AssessmentAssignmentSource;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<AssessmentStudent>
 */
class AssessmentStudentFactory extends Factory
{
    public function definition(): array
    {
        return [
            'assessment_id' => Assessment::factory()->homework(),
            'institution_id' => fn (array $attributes) => $this->assessmentFor($attributes)->institution_id,
            'student_id' => fn (array $attributes) => User::factory()
                ->student()
                ->state(['institution_id' => $attributes['institution_id']]),
            'assignment_source' => AssessmentAssignmentSource::Group,
            'assigned_at' => now(),
            'assigned_by_user_id' => fn (array $attributes) => User::factory()
                ->teacher()
                ->state(['institution_id' => $attributes['institution_id']]),
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function assessmentFor(array $attributes): Assessment
    {
        return Assessment::query()->findOrFail($attributes['assessment_id']);
    }
}
