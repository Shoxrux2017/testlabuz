<?php

namespace Database\Factories;

use App\Models\Assessment;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<TopicResultPair>
 */
class TopicResultPairFactory extends Factory
{
    public function definition(): array
    {
        return [
            'homework_assessment_id' => Assessment::factory()->homework()->groupAssignment(),
            'institution_id' => fn (array $attributes) => $this->homeworkFor($attributes)->institution_id,
            'topic_id' => fn (array $attributes) => $this->homeworkFor($attributes)->topic_id,
            'blitz_assessment_id' => null,
            'designated_by_user_id' => fn (array $attributes) => User::factory()
                ->teacher()
                ->state(['institution_id' => $attributes['institution_id']]),
            'designated_at' => now(),
            'cohort_snapshotted_at' => null,
            'locked_at' => null,
        ];
    }

    public function withBlitz(): static
    {
        return $this->state([
            'blitz_assessment_id' => fn (array $attributes) => Assessment::factory()
                ->blitz()
                ->groupAssignment()
                ->state([
                    'institution_id' => $attributes['institution_id'],
                    'topic_id' => $attributes['topic_id'],
                ]),
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function homeworkFor(array $attributes): Assessment
    {
        return Assessment::query()->findOrFail($attributes['homework_assessment_id']);
    }
}
