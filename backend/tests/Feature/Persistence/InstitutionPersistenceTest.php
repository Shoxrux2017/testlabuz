<?php

namespace Tests\Feature\Persistence;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class InstitutionPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_institution_persists_uuid_identity_locked_values_and_settings_relationship(): void
    {
        $institution = Institution::factory()->create([
            'type' => InstitutionType::University,
            'status' => InstitutionStatus::Active,
        ]);

        $this->assertTrue(Str::isUuid($institution->id));
        $this->assertSame(InstitutionType::University, $institution->type);
        $this->assertSame(InstitutionStatus::Active, $institution->status);

        $setting = InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
        ]);

        $this->assertTrue($institution->is($setting->institution));
        $this->assertTrue($setting->is($institution->setting));
    }

    public function test_institution_database_constraints_reject_invalid_locked_values(): void
    {
        $this->assertDatabaseRejects(fn () => DB::table('institutions')->insert($this->institutionPayload([
            'status' => 'suspended',
        ])));

        $this->assertDatabaseRejects(fn () => DB::table('institutions')->insert($this->institutionPayload([
            'type' => 'academy',
        ])));

        $this->assertDatabaseRejects(fn () => DB::table('institutions')->insert($this->institutionPayload([
            'name' => '',
        ])));
    }

    public function test_referenced_institution_cannot_be_deleted_by_restrict_foreign_key(): void
    {
        $institution = Institution::factory()->create();
        User::factory()->teacher($institution)->create();

        $this->assertDatabaseRejects(fn () => $institution->delete());
    }

    public function test_institution_creator_foreign_key_is_enforced_after_users_exist(): void
    {
        $institution = Institution::factory()->create();
        $creator = User::factory()->platformOwner()->create();

        $institution->update(['created_by_user_id' => $creator->id]);

        $this->assertTrue($creator->is($institution->refresh()->creator));

        $this->assertDatabaseRejects(fn () => Institution::factory()->create([
            'created_by_user_id' => Str::uuid()->toString(),
        ]));
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function institutionPayload(array $overrides = []): array
    {
        return array_merge([
            'id' => Str::uuid()->toString(),
            'name' => 'Persistence Test Institution',
            'type' => InstitutionType::School->value,
            'status' => InstitutionStatus::Active->value,
            'contact_email' => null,
            'contact_phone' => null,
            'address' => null,
            'description' => null,
            'created_by_user_id' => null,
            'deactivated_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }
}
