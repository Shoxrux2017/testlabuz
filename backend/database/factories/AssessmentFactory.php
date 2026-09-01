<?php

namespace Database\Factories;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentType;
use App\Models\Assessment;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Assessment>
 */
class AssessmentFactory extends Factory
{
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'teacher_id' => fn (array $attributes) => User::factory()
                ->teacher()
                ->state(['institution_id' => $attributes['institution_id']]),
            'topic_id' => fn (array $attributes) => Topic::factory()->state([
                'institution_id' => $attributes['institution_id'],
                'teacher_id' => $attributes['teacher_id'],
            ]),
            'type' => AssessmentType::Homework,
            'title' => fake()->sentence(4),
            'description' => fake()->optional()->paragraph(),
            'student_instructions' => fake()->paragraph(),
            'assignment_mode' => AssessmentAssignmentMode::Group,
            'total_possible_points' => '0.000000',
        ];
    }

    public function homework(): static
    {
        return $this->state(fn (array $attributes) => [
            'type' => AssessmentType::Homework,
        ]);
    }

    public function blitz(): static
    {
        return $this->state(fn (array $attributes) => [
            'type' => AssessmentType::Blitz,
        ]);
    }

    public function groupAssignment(): static
    {
        return $this->state(fn (array $attributes) => [
            'assignment_mode' => AssessmentAssignmentMode::Group,
        ]);
    }

    public function selectedStudentsAssignment(): static
    {
        return $this->state(fn (array $attributes) => [
            'assignment_mode' => AssessmentAssignmentMode::SelectedStudents,
        ]);
    }
}
