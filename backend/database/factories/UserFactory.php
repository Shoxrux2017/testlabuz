<?php

namespace Database\Factories;

use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'institution_id' => Institution::factory(),
            'role' => UserRole::Teacher,
            'full_name' => fake()->name(),
            'login_name' => 'user_'.Str::lower(Str::random(16)),
            'email' => fake()->optional()->safeEmail(),
            'phone' => fake()->optional()->numerify('+998#########'),
            'password' => Hash::make(Str::password(32)),
            'is_active' => true,
            'must_change_password' => true,
            'last_login_at' => null,
            'deactivated_at' => null,
            'created_by_user_id' => null,
        ];
    }

    public function platformOwner(): static
    {
        return $this->state(fn (array $attributes) => [
            'institution_id' => null,
            'role' => UserRole::PlatformOwner,
            'must_change_password' => false,
        ]);
    }

    public function institutionAdmin(?Institution $institution = null): static
    {
        return $this->institutionRole(UserRole::InstitutionAdmin, $institution);
    }

    public function teacher(?Institution $institution = null): static
    {
        return $this->institutionRole(UserRole::Teacher, $institution);
    }

    public function student(?Institution $institution = null): static
    {
        return $this->institutionRole(UserRole::Student, $institution);
    }

    public function parent(?Institution $institution = null): static
    {
        return $this->institutionRole(UserRole::Parent, $institution);
    }

    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
    }

    public function mustChangePassword(): static
    {
        return $this->state(fn (array $attributes) => [
            'must_change_password' => true,
        ]);
    }

    public function withPassword(string $plainTestPassword): static
    {
        return $this->state(fn (array $attributes) => [
            'password' => Hash::make($plainTestPassword),
        ]);
    }

    private function institutionRole(UserRole $role, ?Institution $institution): static
    {
        return $this->state(fn (array $attributes) => [
            'institution_id' => $institution?->getKey() ?? Institution::factory(),
            'role' => $role,
            'must_change_password' => true,
        ]);
    }
}
