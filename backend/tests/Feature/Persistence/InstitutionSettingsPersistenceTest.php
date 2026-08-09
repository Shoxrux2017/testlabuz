<?php

namespace Tests\Feature\Persistence;

use App\Enums\BlitzTimerStartMode;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class InstitutionSettingsPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_settings_defaults_policy_nulls_primary_key_and_one_row_per_institution(): void
    {
        $setting = InstitutionSetting::factory()->create();

        $this->assertTrue(Str::isUuid($setting->institution_id));
        $this->assertSame($setting->institution_id, $setting->getKey());
        $this->assertSame('Asia/Tashkent', $setting->timezone);
        $this->assertSame(25, $setting->learning_material_max_mb);
        $this->assertSame(15, $setting->student_submission_max_mb);
        $this->assertNull($setting->acceptable_score_difference);
        $this->assertNull($setting->blitz_timer_start_mode);
        $this->assertNull($setting->student_result_release_mode);
        $this->assertNull($setting->parent_result_release_mode);

        $this->assertTrue($setting->institution->setting->is($setting));

        $this->assertDatabaseRejects(fn () => InstitutionSetting::factory()->create([
            'institution_id' => $setting->institution_id,
        ]));
    }

    public function test_configured_settings_cast_locked_enums_and_preserve_score_precision(): void
    {
        $setting = InstitutionSetting::factory()->configuredEducationalPolicy()->create([
            'acceptable_score_difference' => '12.34567891',
        ]);

        $this->assertSame('12.34567891', $setting->acceptable_score_difference);
        $this->assertSame(BlitzTimerStartMode::Synchronized, $setting->blitz_timer_start_mode);
        $this->assertSame(StudentResultReleaseMode::Automatic, $setting->student_result_release_mode);
        $this->assertSame(ParentResultReleaseMode::WithStudent, $setting->parent_result_release_mode);
    }

    public function test_settings_constraints_reject_invalid_values(): void
    {
        foreach ([
            ['acceptable_score_difference' => '-0.00000001'],
            ['acceptable_score_difference' => '100.00000001'],
            ['blitz_timer_start_mode' => 'teacher_started'],
            ['student_result_release_mode' => 'instant'],
            ['parent_result_release_mode' => 'before_student'],
            ['learning_material_max_mb' => 0],
            ['learning_material_max_mb' => 26],
            ['student_submission_max_mb' => 0],
            ['student_submission_max_mb' => 16],
            ['timezone' => ''],
        ] as $invalidValues) {
            $this->assertDatabaseRejects(fn () => DB::table('institution_settings')->insert(
                $this->settingsPayload($invalidValues),
            ));
        }
    }

    public function test_settings_foreign_keys_reject_unknown_institution_and_updater(): void
    {
        $this->assertDatabaseRejects(fn () => DB::table('institution_settings')->insert($this->settingsPayload([
            'institution_id' => Str::uuid()->toString(),
        ])));

        $institution = Institution::factory()->create();

        $this->assertDatabaseRejects(fn () => DB::table('institution_settings')->insert($this->settingsPayload([
            'institution_id' => $institution->id,
            'updated_by_user_id' => Str::uuid()->toString(),
        ])));

        $updater = User::factory()->institutionAdmin($institution)->create();
        $setting = InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'updated_by_user_id' => $updater->id,
        ]);

        $this->assertTrue($updater->is($setting->updater));
    }

    public function test_attempt_limit_columns_are_absent_from_institution_settings(): void
    {
        $columns = collect(DB::select(
            <<<'SQL'
                select column_name
                from information_schema.columns
                where table_schema = 'public'
                  and table_name = 'institution_settings'
            SQL
        ))->pluck('column_name')->all();

        $this->assertNotContains('homework_attempt_limit', $columns);
        $this->assertNotContains('blitz_attempt_limit', $columns);
        $this->assertNotContains('blitz_exception_attempt_limit', $columns);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function settingsPayload(array $overrides = []): array
    {
        return array_merge([
            'institution_id' => Institution::factory()->create()->id,
            'acceptable_score_difference' => null,
            'blitz_timer_start_mode' => null,
            'student_result_release_mode' => null,
            'parent_result_release_mode' => null,
            'timezone' => 'Asia/Tashkent',
            'learning_material_max_mb' => 25,
            'student_submission_max_mb' => 15,
            'updated_by_user_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }
}
