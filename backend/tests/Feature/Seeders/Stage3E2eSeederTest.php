<?php

namespace Tests\Feature\Seeders;

use App\Enums\InstitutionStatus;
use App\Enums\UnderstandingCategoryCode;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\User;
use Database\Seeders\Stage3E2eSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class Stage3E2eSeederTest extends TestCase
{
    use RefreshDatabase;

    private const TARGET_INSTITUTION_ID = '03000000-0000-4000-8000-000000000101';

    private const FOREIGN_INSTITUTION_ID = '03000000-0000-4000-8000-000000000102';

    private const INACTIVE_INSTITUTION_ID = '03000000-0000-4000-8000-000000000103';

    private const EMPTY_INSTITUTION_ID = '03000000-0000-4000-8000-000000000104';

    public function test_stage_3_e2e_seeder_refuses_a_non_testing_environment_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Unrelated environment guard record']);
        $this->setSecrets();

        $seeder = new class extends Stage3E2eSeeder
        {
            protected function runtimeEnvironment(): string
            {
                return 'local';
            }
        };

        try {
            $seeder->run();
            self::fail('The Stage 3 E2E seeder accepted a non-testing environment.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('APP_ENV=testing', $exception->getMessage());
        }

        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
        $this->assertSame(0, Institution::query()->whereIn('id', $this->institutionIds())->count());
    }

    public function test_stage_3_e2e_seeder_refuses_any_other_database_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Unrelated database guard record']);
        $this->setSecrets();

        $seeder = new class extends Stage3E2eSeeder
        {
            protected function currentDatabase(): string
            {
                return 'testlabuz';
            }
        };

        try {
            $seeder->run();
            self::fail('The Stage 3 E2E seeder accepted the development database.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('testlabuz_testing', $exception->getMessage());
        }

        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
        $this->assertSame(0, Institution::query()->whereIn('id', $this->institutionIds())->count());
    }

    #[DataProvider('requiredSecretNames')]
    public function test_stage_3_e2e_seeder_requires_every_transient_secret(string $missingSecret): void
    {
        $this->setSecrets();
        $this->clearSecret($missingSecret);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage($missingSecret.' must be provided');

        $this->seed(Stage3E2eSeeder::class);
    }

    /**
     * @return iterable<string, array{string}>
     */
    public static function requiredSecretNames(): iterable
    {
        yield 'shared password' => ['STAGE3_E2E_PASSWORD'];
        yield 'first-login password' => ['STAGE3_E2E_FIRST_LOGIN_PASSWORD'];
        yield 'initial User password' => ['STAGE3_E2E_USER_INITIAL_PASSWORD'];
        yield 'new User password' => ['STAGE3_E2E_USER_NEW_PASSWORD'];
    }

    public function test_stage_3_e2e_seeder_creates_the_exact_fixture_world_and_preserves_unrelated_data(): void
    {
        $unrelatedInstitution = Institution::factory()->create(['name' => 'Manual unrelated Institution']);
        InstitutionSetting::factory()->configuredEducationalPolicy()->create([
            'institution_id' => $unrelatedInstitution->id,
        ]);
        $unrelatedUser = User::factory()->teacher($unrelatedInstitution)->create([
            'login_name' => 'manual_unrelated_teacher',
        ]);
        $this->setSecrets();

        $this->seed(Stage3E2eSeeder::class);

        $this->assertDatabaseHas('institutions', ['id' => $unrelatedInstitution->id]);
        $this->assertDatabaseHas('users', ['id' => $unrelatedUser->id]);
        $this->assertSame(4, Institution::query()->whereIn('id', $this->institutionIds())->count());
        $this->assertSame(38, User::query()->whereIn('id', $this->userIds())->count());
        $this->assertSame(4, InstitutionSetting::query()->whereIn('institution_id', $this->institutionIds())->count());
        $this->assertSame(5, InstitutionUnderstandingCategory::query()->whereIn('institution_id', $this->institutionIds())->count());

        $target = Institution::query()->findOrFail(self::TARGET_INSTITUTION_ID);
        $this->assertSame(InstitutionStatus::Active, $target->status);
        $this->assertSame(31, $target->users()->count());
        $this->assertSame(4, $target->users()->where('role', UserRole::InstitutionAdmin)->count());
        $this->assertSame(9, $target->users()->where('role', UserRole::Teacher)->count());
        $this->assertSame(9, $target->users()->where('role', UserRole::Student)->count());
        $this->assertSame(9, $target->users()->where('role', UserRole::Parent)->count());
        $this->assertSame(27, $target->users()->where('is_active', true)->count());

        $settings = InstitutionSetting::query()->findOrFail(self::TARGET_INSTITUTION_ID);
        $this->assertNull($settings->acceptable_score_difference);
        $this->assertNull($settings->blitz_timer_start_mode);
        $this->assertNull($settings->student_result_release_mode);
        $this->assertNull($settings->parent_result_release_mode);
        $this->assertSame('Asia/Tashkent', $settings->timezone);
        $this->assertSame(25, $settings->learning_material_max_mb);
        $this->assertSame(15, $settings->student_submission_max_mb);

        $this->assertSame(0, InstitutionUnderstandingCategory::query()
            ->where('institution_id', self::TARGET_INSTITUTION_ID)
            ->count());
        $categories = InstitutionUnderstandingCategory::query()
            ->where('institution_id', self::FOREIGN_INSTITUTION_ID)
            ->orderBy('sort_order')
            ->get();
        $this->assertSame(UnderstandingCategoryCode::values(), $categories->pluck('code')->map->value->all());
        $this->assertSame([90, 70, 40, 0, null], $categories->pluck('min_score')->all());
        $this->assertSame([100, 89, 69, 39, null], $categories->pluck('max_score')->all());

        $this->assertSame(0, User::query()
            ->where('institution_id', self::EMPTY_INSTITUTION_ID)
            ->whereIn('role', [UserRole::Teacher, UserRole::Student, UserRole::Parent])
            ->count());
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s03_platform_owner',
            'role' => UserRole::PlatformOwner->value,
            'institution_id' => null,
        ]);
        $this->assertSame(2, DB::table('personal_access_tokens')
            ->where('tokenable_id', $this->userId(201))
            ->whereIn('name', ['stage3-preservation-a', 'stage3-preservation-b'])
            ->count());

        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s03_password_gate_admin',
            'must_change_password' => true,
            'is_active' => true,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s03_inactive_admin',
            'is_active' => false,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s03_foreign_admin',
            'institution_id' => self::FOREIGN_INSTITUTION_ID,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s03_inactive_institution_admin',
            'institution_id' => self::INACTIVE_INSTITUTION_ID,
        ]);
    }

    public function test_stage_3_e2e_seeder_is_repeatable_and_removes_only_enumerated_owned_rows(): void
    {
        $this->setSecrets();
        $this->seed(Stage3E2eSeeder::class);

        $unrelated = Institution::factory()->create(['name' => 'Preserved between Stage 3 runs']);
        $target = Institution::query()->findOrFail(self::TARGET_INSTITUTION_ID);
        User::factory()->teacher($target)->create(['login_name' => 'e2e_s03_created_teacher']);
        User::factory()->student($target)->create(['login_name' => 'e2e_s03_created_student']);
        User::factory()->parent($target)->create(['login_name' => 'e2e_s03_created_parent']);

        $this->seed(Stage3E2eSeeder::class);

        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
        $this->assertDatabaseMissing('users', ['login_name' => 'e2e_s03_created_teacher']);
        $this->assertDatabaseMissing('users', ['login_name' => 'e2e_s03_created_student']);
        $this->assertDatabaseMissing('users', ['login_name' => 'e2e_s03_created_parent']);
        $this->assertSame(4, Institution::query()->whereIn('id', $this->institutionIds())->count());
        $this->assertSame(38, User::query()->whereIn('id', $this->userIds())->count());
        $this->assertSame(5, InstitutionUnderstandingCategory::query()->whereIn('institution_id', $this->institutionIds())->count());
    }

    public function test_stage_3_e2e_seeder_refuses_a_reserved_institution_collision_before_mutation(): void
    {
        $collision = Institution::factory()->create([
            'id' => self::TARGET_INSTITUTION_ID,
            'name' => 'Manual collision Institution',
        ]);
        $unrelated = Institution::factory()->create(['name' => 'Preserved after Institution collision']);
        $this->setSecrets();

        try {
            $this->seed(Stage3E2eSeeder::class);
            self::fail('The Stage 3 E2E seeder accepted a reserved Institution collision.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('manifest collision', $exception->getMessage());
        }

        $this->assertDatabaseHas('institutions', ['id' => $collision->id, 'name' => $collision->name]);
        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
    }

    public function test_stage_3_e2e_seeder_refuses_a_reserved_user_login_collision_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Preserved after User collision']);
        $collision = User::factory()->teacher($unrelated)->create([
            'login_name' => 'e2e_s03_created_teacher',
        ]);
        $this->setSecrets();

        try {
            $this->seed(Stage3E2eSeeder::class);
            self::fail('The Stage 3 E2E seeder accepted a reserved User login collision.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('reserved User login collision', $exception->getMessage());
        }

        $this->assertDatabaseHas('users', ['id' => $collision->id]);
        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
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

    /** @return array<string, string> */
    private function secrets(): array
    {
        return [
            'STAGE3_E2E_PASSWORD' => 'Shared-'.Str::random(24).'Aa1!',
            'STAGE3_E2E_FIRST_LOGIN_PASSWORD' => 'First-'.Str::random(24).'Aa1!',
            'STAGE3_E2E_USER_INITIAL_PASSWORD' => 'Initial-'.Str::random(24).'Aa1!',
            'STAGE3_E2E_USER_NEW_PASSWORD' => 'New-'.Str::random(24).'Aa1!',
        ];
    }

    private function clearSecret(string $name): void
    {
        putenv($name);
        unset($_ENV[$name], $_SERVER[$name]);
    }

    /** @return list<string> */
    private function institutionIds(): array
    {
        return [
            self::TARGET_INSTITUTION_ID,
            self::FOREIGN_INSTITUTION_ID,
            self::INACTIVE_INSTITUTION_ID,
            self::EMPTY_INSTITUTION_ID,
        ];
    }

    /** @return list<string> */
    private function userIds(): array
    {
        $suffixes = [101, 102, 103, 104, 105, 106, 107, 108, 201, 202, 203, 204, 205, 206];
        for ($suffix = 301; $suffix <= 324; $suffix++) {
            $suffixes[] = $suffix;
        }

        return array_map(
            fn (int $suffix): string => $this->userId($suffix),
            $suffixes,
        );
    }

    private function userId(int $suffix): string
    {
        return sprintf('03000000-0000-4000-9000-%012d', $suffix);
    }
}
