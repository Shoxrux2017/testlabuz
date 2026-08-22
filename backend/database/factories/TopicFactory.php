<?php

namespace Database\Factories;

use App\Enums\TopicStatus;
use App\Models\Group;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Topic>
 */
class TopicFactory extends Factory
{
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'teacher_id' => fn (array $attributes) => User::factory()
                ->teacher()
                ->state(['institution_id' => $attributes['institution_id']]),
            'group_id' => fn (array $attributes) => Group::factory()
                ->state(['institution_id' => $attributes['institution_id']]),
            'title' => fake()->sentence(4),
            'description' => fake()->optional()->paragraph(),
            'subject' => fake()->words(2, true),
            'student_instructions' => fake()->paragraph(),
            'lesson_at' => null,
            'status' => TopicStatus::Draft,
            'activated_at' => null,
            'closed_at' => null,
            'archived_at' => null,
        ];
    }

    public function active(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinute();

            return [
                'status' => TopicStatus::Active,
                'activated_at' => $createdAt->copy()->addSeconds(30),
                'closed_at' => null,
                'archived_at' => null,
                'created_at' => $createdAt,
            ];
        });
    }

    public function closed(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinutes(2);

            return [
                'status' => TopicStatus::Closed,
                'activated_at' => $createdAt->copy()->addSeconds(30),
                'closed_at' => $createdAt->copy()->addMinute(),
                'archived_at' => null,
                'created_at' => $createdAt,
            ];
        });
    }

    public function archivedFromDraft(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinute();

            return [
                'status' => TopicStatus::Archived,
                'activated_at' => null,
                'closed_at' => null,
                'archived_at' => $createdAt->copy()->addSeconds(30),
                'created_at' => $createdAt,
            ];
        });
    }

    public function archivedFromClosed(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinutes(3);

            return [
                'status' => TopicStatus::Archived,
                'activated_at' => $createdAt->copy()->addSeconds(30),
                'closed_at' => $createdAt->copy()->addMinute(),
                'archived_at' => $createdAt->copy()->addMinutes(2),
                'created_at' => $createdAt,
            ];
        });
    }
}
