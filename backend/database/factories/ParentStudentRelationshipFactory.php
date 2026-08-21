<?php

namespace Database\Factories;

use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ParentStudentRelationship>
 */
class ParentStudentRelationshipFactory extends Factory
{
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'parent_id' => fn (array $attributes) => User::factory()
                ->parent()
                ->state(['institution_id' => $attributes['institution_id']]),
            'student_id' => fn (array $attributes) => User::factory()
                ->student()
                ->state(['institution_id' => $attributes['institution_id']]),
            'connected_by_user_id' => fn (array $attributes) => User::factory()
                ->institutionAdmin()
                ->state(['institution_id' => $attributes['institution_id']]),
            'started_at' => now(),
            'ended_at' => null,
        ];
    }

    public function ended(): static
    {
        return $this->state(function (array $attributes) {
            $endedAt = now();

            return [
                'started_at' => $endedAt->copy()->subDay(),
                'ended_at' => $endedAt,
            ];
        });
    }
}
