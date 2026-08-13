<?php

namespace Tests\Feature\Seeders;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Database\Seeders\Stage2E2eSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class Stage2E2eSeederTest extends TestCase
{
    use RefreshDatabase;

    private const TARGET_INSTITUTION_ID = '02000000-0000-4000-8000-000000000101';

    public function test_stage_2_e2e_seeder_refuses_a_non_testing_environment_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Unrelated environment guard record']);
        $this->setSecrets();

        $seeder = new class extends Stage2E2eSeeder
        {
            protected function runtimeEnvironment(): string
            {
                return 'local';
            }
        };

        try {
            $seeder->run();
            self::fail('The Stage 2 E2E seeder accepted a non-testing environment.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('APP_ENV=testing', $exception->getMessage());
        }

        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
        $this->assertSame(0, $this->fixtureInstitutionCount());
    }

    public function test_stage_2_e2e_seeder_refuses_any_other_database_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Unrelated database guard record']);
        $this->setSecrets();

        $seeder = new class extends Stage2E2eSeeder
        {
            protected function currentDatabase(): string
            {
                return 'testlabuz';
            }
        };

        try {
            $seeder->run();
            self::fail('The Stage 2 E2E seeder accepted the development database.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('testlabuz_testing', $exception->getMessage());
        }

        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
        $this->assertSame(0, $this->fixtureInstitutionCount());
    }

    #[DataProvider('requiredSecretNames')]
    public function test_stage_2_e2e_seeder_requires_every_transient_secret(string $missingSecret): void
    {
        $this->setSecrets();
        $this->clearSecret($missingSecret);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage($missingSecret.' must be provided');

        $this->seed(Stage2E2eSeeder::class);
    }

    /**
     * @return iterable<string, array{string}>
     */
    public static function requiredSecretNames(): iterable
    {
        yield 'shared password' => ['STAGE2_E2E_PASSWORD'];
        yield 'initial admin password' => ['STAGE2_E2E_ADMIN_INITIAL_PASSWORD'];
        yield 'new admin password' => ['STAGE2_E2E_ADMIN_NEW_PASSWORD'];
    }

    public function test_stage_2_e2e_seeder_creates_the_exact_guarded_fixture_world_and_preserves_unrelated_data(): void
    {
        $unrelatedInstitution = Institution::factory()->create(['name' => 'Manual unrelated Institution']);
        InstitutionSetting::factory()->configuredEducationalPolicy()->create([
            'institution_id' => $unrelatedInstitution->id,
        ]);
        $unrelatedUser = User::factory()->teacher($unrelatedInstitution)->create([
            'login_name' => 'manual_unrelated_teacher',
        ]);
        $this->setSecrets();

        $this->seed(Stage2E2eSeeder::class);

        $this->assertDatabaseHas('institutions', ['id' => $unrelatedInstitution->id]);
        $this->assertDatabaseHas('users', ['id' => $unrelatedUser->id]);
        $this->assertSame(31, $this->fixtureInstitutionCount());
        $this->assertSame(31, $this->fixtureUserCount());
        $this->assertSame(31, InstitutionSetting::query()
            ->whereIn('institution_id', $this->fixtureInstitutionIds())
            ->count());

        $target = Institution::query()->findOrFail(self::TARGET_INSTITUTION_ID);
        $this->assertSame(InstitutionStatus::Active, $target->status);
        $this->assertSame(28, $target->users()->count());
        $this->assertSame(26, $target->users()->where('is_active', true)->count());
        $this->assertSame(24, $target->users()->where('role', UserRole::InstitutionAdmin)->count());

        $settings = InstitutionSetting::query()->findOrFail($target->id);
        $this->assertSame('Asia/Tashkent', $settings->timezone);
        $this->assertSame(25, $settings->learning_material_max_mb);
        $this->assertSame(15, $settings->student_submission_max_mb);
        $this->assertNull($settings->acceptable_score_difference);
        $this->assertNull($settings->blitz_timer_start_mode);
        $this->assertNull($settings->student_result_release_mode);
        $this->assertNull($settings->parent_result_release_mode);
        $this->assertNull($settings->updated_by_user_id);

        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s02_platform_owner',
            'role' => UserRole::PlatformOwner->value,
            'institution_id' => null,
            'is_active' => true,
            'must_change_password' => false,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s02_inactive_admin',
            'role' => UserRole::InstitutionAdmin->value,
            'is_active' => false,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s02_inactive_institution_admin',
            'role' => UserRole::InstitutionAdmin->value,
            'is_active' => true,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s02_non_admin_target',
            'role' => UserRole::Teacher->value,
        ]);
    }

    public function test_stage_2_e2e_seeder_is_repeatable_and_removes_only_owned_prior_run_rows(): void
    {
        $this->setSecrets();
        $this->seed(Stage2E2eSeeder::class);

        $firstInstitutionIds = $this->fixtureInstitutionIds()->all();
        $firstUserIds = $this->fixtureUserIds()->all();
        $unrelated = Institution::factory()->create(['name' => 'Preserved between Stage 2 runs']);

        $createdByUi = Institution::factory()->create([
            'name' => 'E2E S02 Created Institution',
            'type' => InstitutionType::PrivateEducation,
            'status' => InstitutionStatus::Active,
        ]);
        InstitutionSetting::factory()->create(['institution_id' => $createdByUi->id]);
        User::factory()->institutionAdmin($createdByUi)->create([
            'login_name' => 'e2e_s02_created_admin',
        ]);

        $this->seed(Stage2E2eSeeder::class);

        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
        $this->assertDatabaseMissing('institutions', ['id' => $createdByUi->id]);
        $this->assertDatabaseMissing('users', ['login_name' => 'e2e_s02_created_admin']);
        $this->assertSame($firstInstitutionIds, $this->fixtureInstitutionIds()->all());
        $this->assertSame($firstUserIds, $this->fixtureUserIds()->all());
        $this->assertSame(31, $this->fixtureInstitutionCount());
        $this->assertSame(31, $this->fixtureUserCount());
    }

    protected function tearDown(): void
    {
        foreach (array_keys($this->secrets()) as $name) {
            $this->clearSecret($name);
        }

        parent::tearDown();
    }

    private function setSecrets(): void
    {
        foreach ($this->secrets() as $name => $value) {
            putenv($name.'='.$value);
            $_ENV[$name] = $value;
            $_SERVER[$name] = $value;
        }
    }

    /**
     * @return array<string, string>
     */
    private function secrets(): array
    {
        return [
            'STAGE2_E2E_PASSWORD' => 'Shared-'.Str::random(24).'Aa1!',
            'STAGE2_E2E_ADMIN_INITIAL_PASSWORD' => 'Initial-'.Str::random(24).'Aa1!',
            'STAGE2_E2E_ADMIN_NEW_PASSWORD' => 'New-'.Str::random(24).'Aa1!',
        ];
    }

    private function clearSecret(string $name): void
    {
        putenv($name);
        unset($_ENV[$name], $_SERVER[$name]);
    }

    private function fixtureInstitutionCount(): int
    {
        return $this->fixtureInstitutions()->count();
    }

    private function fixtureUserCount(): int
    {
        return $this->fixtureUsers()->count();
    }

    private function fixtureInstitutions()
    {
        return Institution::query()
            ->whereRaw('left(name, ?) = ?', [strlen('E2E S02 '), 'E2E S02 ']);
    }

    private function fixtureUsers()
    {
        return User::query()
            ->whereRaw('left(login_name, ?) = ?', [strlen('e2e_s02_'), 'e2e_s02_']);
    }

    private function fixtureInstitutionIds()
    {
        return $this->fixtureInstitutions()->orderBy('id')->pluck('id');
    }

    private function fixtureUserIds()
    {
        return $this->fixtureUsers()->orderBy('id')->pluck('id');
    }
}
