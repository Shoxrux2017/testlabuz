<?php

namespace Database\Factories;

use App\Enums\HomeworkStatus;
use App\Models\Assessment;
use App\Models\HomeworkAssignment;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<HomeworkAssignment>
 */
class HomeworkAssignmentFactory extends Factory
{
    public function definition(): array
    {
        return [
            'assessment_id' => Assessment::factory()->homework(),
            'institution_id' => fn (array $attributes) => $this->assessmentFor($attributes)->institution_id,
            'status' => HomeworkStatus::Draft,
            'deadline_at' => null,
            'activated_at' => null,
            'closed_at' => null,
            'archived_at' => null,
        ];
    }

    public function draft(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => HomeworkStatus::Draft,
            'activated_at' => null,
            'closed_at' => null,
            'archived_at' => null,
        ]);
    }

    public function active(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinute();

            return [
                'status' => HomeworkStatus::Active,
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
                'status' => HomeworkStatus::Closed,
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
                'status' => HomeworkStatus::Archived,
                'activated_at' => null,
                'closed_at' => null,
                'archived_at' => $createdAt->copy()->addSeconds(30),
                'created_at' => $createdAt,
            ];
        });
    }

    public function archivedAfterClose(): static
    {
        return $this->state(function (array $attributes) {
            $createdAt = now()->subMinutes(3);

            return [
                'status' => HomeworkStatus::Archived,
                'activated_at' => $createdAt->copy()->addSeconds(30),
                'closed_at' => $createdAt->copy()->addMinute(),
                'archived_at' => $createdAt->copy()->addMinutes(2),
                'created_at' => $createdAt,
            ];
        });
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function assessmentFor(array $attributes): Assessment
    {
        return Assessment::query()->findOrFail($attributes['assessment_id']);
    }
}
