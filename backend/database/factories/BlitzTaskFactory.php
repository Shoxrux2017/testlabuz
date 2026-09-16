<?php

namespace Database\Factories;

use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use App\Models\Assessment;
use App\Models\BlitzTask;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/**
 * @extends Factory<BlitzTask>
 */
class BlitzTaskFactory extends Factory
{
    public function definition(): array
    {
        return [
            'assessment_id' => Assessment::factory()->blitz(),
            'institution_id' => fn (array $attributes) => $this->assessmentFor($attributes)->institution_id,
            'status' => BlitzStatus::Draft,
            'duration_seconds' => 600,
            'scheduled_at' => null,
            'timer_start_mode_snapshot' => null,
            'activated_at' => null,
            'synchronized_ends_at' => null,
            'closed_at' => null,
            'archived_at' => null,
            'activated_by_user_id' => null,
        ];
    }

    public function draft(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => BlitzStatus::Draft,
            'scheduled_at' => null,
            'timer_start_mode_snapshot' => null,
            'activated_at' => null,
            'synchronized_ends_at' => null,
            'closed_at' => null,
            'archived_at' => null,
            'activated_by_user_id' => null,
        ]);
    }

    public function scheduled(): static
    {
        return $this->draft()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Scheduled,
            'scheduled_at' => now()->addMinute(),
        ]);
    }

    public function activeSynchronized(): static
    {
        return $this->activated(BlitzTimerStartMode::Synchronized);
    }

    public function activeIndividual(): static
    {
        return $this->activated(BlitzTimerStartMode::Individual);
    }

    public function closedSynchronized(): static
    {
        return $this->activeSynchronized()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Closed,
            'closed_at' => now(),
        ]);
    }

    public function closedIndividual(): static
    {
        return $this->activeIndividual()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Closed,
            'closed_at' => now(),
        ]);
    }

    public function archivedFromDraft(): static
    {
        return $this->draft()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Archived,
            'created_at' => now()->subMinute(),
            'archived_at' => now(),
        ]);
    }

    public function archivedFromScheduled(): static
    {
        return $this->scheduled()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Archived,
            'created_at' => now()->subMinute(),
            'archived_at' => now(),
        ]);
    }

    public function archivedAfterCloseSynchronized(): static
    {
        return $this->closedSynchronized()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Archived,
            'archived_at' => now(),
        ]);
    }

    public function archivedAfterCloseIndividual(): static
    {
        return $this->closedIndividual()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Archived,
            'archived_at' => now(),
        ]);
    }

    private function activated(BlitzTimerStartMode $timerMode): static
    {
        return $this->draft()->state(fn (array $attributes) => [
            'status' => BlitzStatus::Active,
            'timer_start_mode_snapshot' => $timerMode,
            'created_at' => now()->subMinute(),
            'activated_at' => now()->subSeconds(30),
            'synchronized_ends_at' => $timerMode === BlitzTimerStartMode::Synchronized
                ? fn (array $attributes) => Carbon::parse($attributes['activated_at'])->addSeconds((int) $attributes['duration_seconds'])
                : null,
            'activated_by_user_id' => fn (array $attributes) => $this->assessmentFor($attributes)->teacher_id,
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
