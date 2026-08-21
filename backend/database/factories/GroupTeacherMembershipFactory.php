<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<GroupTeacherMembership>
 */
class GroupTeacherMembershipFactory extends Factory
{
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'group_id' => fn (array $attributes) => Group::factory()
                ->state(['institution_id' => $attributes['institution_id']]),
            'teacher_id' => fn (array $attributes) => User::factory()
                ->teacher()
                ->state(['institution_id' => $attributes['institution_id']]),
            'assigned_by_user_id' => fn (array $attributes) => User::factory()
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
