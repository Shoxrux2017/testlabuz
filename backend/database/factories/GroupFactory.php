<?php

namespace Database\Factories;

use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Group>
 */
class GroupFactory extends Factory
{
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'name' => fake()->words(3, true),
            'level' => fake()->optional()->word(),
            'subject_direction' => fake()->optional()->words(2, true),
            'description' => fake()->optional()->sentence(),
            'status' => GroupStatus::Active,
            'created_by_user_id' => fn (array $attributes) => User::factory()
                ->institutionAdmin()
                ->state(['institution_id' => $attributes['institution_id']]),
            'archived_at' => null,
        ];
    }

    public function archived(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => GroupStatus::Archived,
            'archived_at' => now(),
        ]);
    }
}
