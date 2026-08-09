<?php

namespace Tests\Feature\Persistence;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class UserFactoryModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_model_enum_casts_and_relationships_are_available(): void
    {
        $institution = Institution::factory()->create([
            'type' => InstitutionType::College,
            'status' => InstitutionStatus::Active,
        ]);
        $teacher = User::factory()->teacher($institution)->create();

        $this->assertSame(InstitutionType::College, $institution->type);
        $this->assertSame(InstitutionStatus::Active, $institution->status);
        $this->assertSame(UserRole::Teacher, $teacher->role);
        $this->assertTrue($institution->is($teacher->institution));
        $this->assertTrue($institution->users->contains($teacher));
    }

    public function test_role_factory_states_create_locked_institution_ownership(): void
    {
        $platformOwner = User::factory()->platformOwner()->create();

        $this->assertNull($platformOwner->institution_id);
        $this->assertFalse($platformOwner->must_change_password);

        foreach ([
            UserRole::InstitutionAdmin->value => User::factory()->institutionAdmin()->create(),
            UserRole::Teacher->value => User::factory()->teacher()->create(),
            UserRole::Student->value => User::factory()->student()->create(),
            UserRole::Parent->value => User::factory()->parent()->create(),
        ] as $expectedRole => $user) {
            $this->assertSame($expectedRole, $user->role->value);
            $this->assertNotNull($user->institution_id);
            $this->assertTrue($user->must_change_password);
            $this->assertTrue($user->institution instanceof Institution);
        }
    }

    public function test_inactive_state_and_password_helper_are_safe(): void
    {
        $plainTestPassword = Str::password(24);
        $user = User::factory()
            ->teacher()
            ->inactive()
            ->mustChangePassword()
            ->withPassword($plainTestPassword)
            ->create();

        $this->assertFalse($user->is_active);
        $this->assertTrue($user->must_change_password);
        $this->assertNotNull($user->deactivated_at);
        $this->assertNotSame($plainTestPassword, $user->password);
        $this->assertTrue(Hash::check($plainTestPassword, $user->password));
    }

    public function test_database_seeder_does_not_create_demo_credentials(): void
    {
        $this->seed(DatabaseSeeder::class);

        $this->assertDatabaseCount('institutions', 0);
        $this->assertDatabaseCount('users', 0);
    }
}
