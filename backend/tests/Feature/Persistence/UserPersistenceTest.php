<?php

namespace Tests\Feature\Persistence;

use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class UserPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_all_locked_roles_persist_in_valid_institution_state(): void
    {
        $institution = Institution::factory()->create();

        $users = [
            User::factory()->platformOwner()->create(),
            User::factory()->institutionAdmin($institution)->create(),
            User::factory()->teacher($institution)->create(),
            User::factory()->student($institution)->create(),
            User::factory()->parent($institution)->create(),
        ];

        $this->assertSame(UserRole::PlatformOwner, $users[0]->role);
        $this->assertNull($users[0]->institution_id);

        foreach (array_slice($users, 1) as $user) {
            $this->assertTrue(Str::isUuid($user->id));
            $this->assertSame($institution->id, $user->institution_id);
            $this->assertTrue($institution->is($user->institution));
        }
    }

    public function test_role_institution_check_allows_only_platform_owner_without_institution(): void
    {
        $institution = Institution::factory()->create();

        $platformOwner = User::factory()->platformOwner()->create();
        $institutionTeacher = User::factory()->teacher($institution)->create();

        $this->assertNull($platformOwner->institution_id);
        $this->assertSame($institution->id, $institutionTeacher->institution_id);

        $this->assertDatabaseRejects(fn () => DB::table('users')->insert($this->userPayload([
            'role' => UserRole::PlatformOwner->value,
            'institution_id' => $institution->id,
        ])));

        $this->assertDatabaseRejects(fn () => DB::table('users')->insert($this->userPayload([
            'role' => UserRole::Teacher->value,
            'institution_id' => null,
        ])));
    }

    public function test_user_database_rejects_invalid_role_and_unknown_institution(): void
    {
        $this->assertDatabaseRejects(fn () => DB::table('users')->insert($this->userPayload([
            'role' => 'owner',
        ])));

        $this->assertDatabaseRejects(fn () => DB::table('users')->insert($this->userPayload([
            'institution_id' => Str::uuid()->toString(),
        ])));
    }

    public function test_login_name_is_unique_but_phone_and_email_are_not_globally_unique(): void
    {
        $institution = Institution::factory()->create();
        $loginName = 'unique_login_'.Str::lower(Str::random(8));

        User::factory()->teacher($institution)->create([
            'login_name' => $loginName,
        ]);

        $this->assertDatabaseRejects(fn () => User::factory()->student($institution)->create([
            'login_name' => $loginName,
        ]));

        $sharedPhone = '+998901234567';
        User::factory()->teacher($institution)->create([
            'phone' => $sharedPhone,
        ]);
        User::factory()->student($institution)->create([
            'phone' => $sharedPhone,
        ]);

        User::factory()->teacher($institution)->create([
            'phone' => null,
        ]);
        User::factory()->student($institution)->create([
            'phone' => null,
        ]);

        $sharedEmail = 'shared-contact@example.test';
        User::factory()->teacher($institution)->create([
            'email' => $sharedEmail,
        ]);
        User::factory()->student($institution)->create([
            'email' => $sharedEmail,
        ]);

        $this->assertDatabaseCount('users', 7);
    }

    public function test_password_hashing_and_boolean_casts_are_enforced_by_model(): void
    {
        $plainTestPassword = Str::password(24);
        $user = User::factory()
            ->student()
            ->inactive()
            ->mustChangePassword()
            ->withPassword($plainTestPassword)
            ->create();

        $this->assertNotSame($plainTestPassword, $user->password);
        $this->assertTrue(Hash::check($plainTestPassword, $user->password));
        $this->assertIsBool($user->is_active);
        $this->assertIsBool($user->must_change_password);
        $this->assertFalse($user->is_active);
        $this->assertTrue($user->must_change_password);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function userPayload(array $overrides = []): array
    {
        return array_merge([
            'id' => Str::uuid()->toString(),
            'institution_id' => Institution::factory()->create()->id,
            'role' => UserRole::Teacher->value,
            'full_name' => 'Persistence Test User',
            'login_name' => 'login_'.Str::lower(Str::random(16)),
            'email' => null,
            'phone' => null,
            'password' => Hash::make(Str::password(32)),
            'is_active' => true,
            'must_change_password' => true,
            'last_login_at' => null,
            'deactivated_at' => null,
            'created_by_user_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }
}
