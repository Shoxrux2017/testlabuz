<?php

namespace Database\Factories;

use App\Models\File;
use App\Models\Institution;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<LearningMaterial>
 */
class LearningMaterialFactory extends Factory
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
            'file_id' => fn (array $attributes) => File::factory()->state([
                'institution_id' => $attributes['institution_id'],
                'uploaded_by_user_id' => $attributes['teacher_id'],
            ]),
            'title' => fake()->optional()->sentence(3),
            'position' => 0,
            'removed_at' => null,
        ];
    }

    public function removed(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinute();

            return [
                'removed_at' => $createdAt->copy()->addSeconds(30),
                'created_at' => $createdAt,
            ];
        });
    }
}
