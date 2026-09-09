<?php

namespace Database\Factories;

use App\Enums\IdempotencyOperation;
use App\Models\IdempotencyRecord;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<IdempotencyRecord> */
class IdempotencyRecordFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory()->student(),
            'institution_id' => fn (array $attributes) => User::query()->findOrFail($attributes['user_id'])->institution_id,
            'operation' => IdempotencyOperation::StudentHomeworkAttemptStart,
            'idempotency_key' => Str::uuid()->toString(),
            'request_fingerprint' => hash('sha256', Str::uuid()->toString()),
            'result_resource_type' => null,
            'result_resource_id' => null,
            'response_status' => null,
            'completed_at' => null,
        ];
    }

    public function completed(): static
    {
        return $this->state(fn (array $attributes) => [
            'result_resource_type' => 'assessment_attempt',
            'result_resource_id' => Str::uuid()->toString(),
            'response_status' => 201,
            'created_at' => now()->subMinute(),
            'completed_at' => now(),
        ]);
    }
}
