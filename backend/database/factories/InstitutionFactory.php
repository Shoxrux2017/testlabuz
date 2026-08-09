<?php

namespace Database\Factories;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Models\Institution;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Institution>
 */
class InstitutionFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->company(),
            'type' => fake()->randomElement(InstitutionType::cases()),
            'status' => InstitutionStatus::Active,
            'contact_email' => fake()->optional()->safeEmail(),
            'contact_phone' => fake()->optional()->numerify('+998#########'),
            'address' => fake()->optional()->address(),
            'description' => fake()->optional()->sentence(),
            'created_by_user_id' => null,
            'deactivated_at' => null,
        ];
    }

    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ]);
    }
}
