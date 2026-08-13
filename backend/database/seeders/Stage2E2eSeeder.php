<?php

namespace Database\Seeders;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class Stage2E2eSeeder extends Seeder
{
    private const TEST_DATABASE = 'testlabuz_testing';

    private const INSTITUTION_PREFIX = 'E2E S02 ';

    private const LOGIN_PREFIX = 'e2e_s02_';

    private const REQUIRED_SECRETS = [
        'STAGE2_E2E_PASSWORD',
        'STAGE2_E2E_ADMIN_INITIAL_PASSWORD',
        'STAGE2_E2E_ADMIN_NEW_PASSWORD',
    ];

    private const TARGET_INSTITUTION_ID = '02000000-0000-4000-8000-000000000101';

    private const INACTIVE_INSTITUTION_ID = '02000000-0000-4000-8000-000000000102';

    private const UNAFFECTED_INSTITUTION_ID = '02000000-0000-4000-8000-000000000103';

    public function run(): void
    {
        $this->assertSafeRuntime();

        $passwords = $this->requiredSecrets();

        DB::transaction(function () use ($passwords): void {
            $this->resetStage2Fixtures();

            $institutions = $this->createInstitutions();
            $this->createUsers(
                $institutions,
                $passwords['STAGE2_E2E_PASSWORD'],
                $passwords['STAGE2_E2E_ADMIN_INITIAL_PASSWORD'],
            );
        });
    }

    protected function runtimeEnvironment(): string
    {
        return app()->environment();
    }

    protected function currentDatabase(): string
    {
        return (string) DB::scalar('select current_database()');
    }

    private function assertSafeRuntime(): void
    {
        if ($this->runtimeEnvironment() !== 'testing') {
            throw new RuntimeException('Stage2E2eSeeder may only run with APP_ENV=testing.');
        }

        if ($this->currentDatabase() !== self::TEST_DATABASE) {
            throw new RuntimeException('Stage2E2eSeeder may only run against testlabuz_testing.');
        }
    }

    /**
     * @return array<string, string>
     */
    private function requiredSecrets(): array
    {
        $secrets = [];

        foreach (self::REQUIRED_SECRETS as $name) {
            $value = env($name);

            if (! is_string($value) || trim($value) === '') {
                throw new RuntimeException($name.' must be provided by the local environment.');
            }

            $secrets[$name] = $value;
        }

        if ($secrets['STAGE2_E2E_ADMIN_INITIAL_PASSWORD'] === $secrets['STAGE2_E2E_ADMIN_NEW_PASSWORD']) {
            throw new RuntimeException('Stage 2 E2E initial and new administrator passwords must differ.');
        }

        return $secrets;
    }

    private function resetStage2Fixtures(): void
    {
        $institutionIds = Institution::query()
            ->whereRaw('left(name, ?) = ?', [strlen(self::INSTITUTION_PREFIX), self::INSTITUTION_PREFIX])
            ->pluck('id');

        $fixtureUsers = User::query()
            ->where(function ($query) use ($institutionIds): void {
                $query->whereRaw(
                    'left(login_name, ?) = ?',
                    [strlen(self::LOGIN_PREFIX), self::LOGIN_PREFIX],
                );

                if ($institutionIds->isNotEmpty()) {
                    $query->orWhereIn('institution_id', $institutionIds);
                }
            })
            ->pluck('id');

        if ($fixtureUsers->isNotEmpty()) {
            DB::table('personal_access_tokens')
                ->where('tokenable_type', User::class)
                ->whereIn('tokenable_id', $fixtureUsers)
                ->delete();

            Institution::query()
                ->whereIn('created_by_user_id', $fixtureUsers)
                ->update(['created_by_user_id' => null]);

            InstitutionSetting::query()
                ->whereIn('updated_by_user_id', $fixtureUsers)
                ->update(['updated_by_user_id' => null]);

            User::query()
                ->whereIn('created_by_user_id', $fixtureUsers)
                ->update(['created_by_user_id' => null]);

            User::query()->whereIn('id', $fixtureUsers)->delete();
        }

        if ($institutionIds->isEmpty()) {
            return;
        }

        InstitutionSetting::query()
            ->whereIn('institution_id', $institutionIds)
            ->delete();

        Institution::query()->whereIn('id', $institutionIds)->delete();
    }

    /**
     * @return array<string, Institution>
     */
    private function createInstitutions(): array
    {
        $specifications = [
            $this->institutionSpecification(
                'target',
                self::TARGET_INSTITUTION_ID,
                'E2E S02 Target Institution',
                InstitutionType::School,
                InstitutionStatus::Active,
                '2029-01-01 09:00:00+00',
            ),
            $this->institutionSpecification(
                'inactive',
                self::INACTIVE_INSTITUTION_ID,
                'E2E S02 Inactive Institution',
                InstitutionType::College,
                InstitutionStatus::Inactive,
                '2029-01-02 09:00:00+00',
            ),
            $this->institutionSpecification(
                'unaffected',
                self::UNAFFECTED_INSTITUTION_ID,
                'E2E S02 Unaffected Institution',
                InstitutionType::University,
                InstitutionStatus::Active,
                '2029-01-03 09:00:00+00',
            ),
            $this->institutionSpecification(
                'literal_percent',
                $this->institutionId(104),
                'E2E S02 Literal % Academy',
                InstitutionType::LearningCenter,
                InstitutionStatus::Active,
                '2029-01-04 09:00:00+00',
            ),
            $this->institutionSpecification(
                'literal_underscore',
                $this->institutionId(105),
                'E2E S02 Literal _ Academy',
                InstitutionType::TrainingCenter,
                InstitutionStatus::Inactive,
                '2029-01-05 09:00:00+00',
            ),
            $this->institutionSpecification(
                'mixed_case',
                $this->institutionId(106),
                'E2E S02 MiXeD Case Lyceum',
                InstitutionType::Lyceum,
                InstitutionStatus::Active,
                '2029-01-06 09:00:00+00',
            ),
        ];

        $types = InstitutionType::cases();
        for ($index = 1; $index <= 20; $index++) {
            $specifications[] = $this->institutionSpecification(
                'campus_'.$index,
                $this->institutionId(200 + $index),
                sprintf('E2E S02 Campus %02d', $index),
                $types[($index - 1) % count($types)],
                $index % 5 === 0 ? InstitutionStatus::Inactive : InstitutionStatus::Active,
                sprintf('2028-02-%02d 08:00:00+00', $index),
            );
        }

        for ($index = 1; $index <= 5; $index++) {
            $specifications[] = $this->institutionSpecification(
                'recent_'.$index,
                $this->institutionId(300 + $index),
                sprintf('E2E S02 Recent %02d', $index),
                $types[$index % count($types)],
                $index % 2 === 0 ? InstitutionStatus::Inactive : InstitutionStatus::Active,
                sprintf('2030-01-%02d 12:00:00+00', $index),
            );
        }

        $institutions = [];

        foreach ($specifications as $specification) {
            $createdAt = Carbon::parse($specification['created_at']);
            $isInactive = $specification['status'] === InstitutionStatus::Inactive;
            $institution = Institution::factory()->create([
                'id' => $specification['id'],
                'name' => $specification['name'],
                'type' => $specification['type'],
                'status' => $specification['status'],
                'contact_email' => $specification['key'].'@e2e-s02.invalid',
                'contact_phone' => '+99890000'.str_pad((string) count($institutions), 4, '0', STR_PAD_LEFT),
                'address' => 'E2E S02 deterministic address',
                'description' => 'E2E S02 deterministic verification fixture.',
                'created_by_user_id' => null,
                'deactivated_at' => $isInactive ? $createdAt->copy()->addHour() : null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);

            InstitutionSetting::factory()->create([
                'institution_id' => $institution->id,
                'acceptable_score_difference' => null,
                'blitz_timer_start_mode' => null,
                'student_result_release_mode' => null,
                'parent_result_release_mode' => null,
                'timezone' => 'Asia/Tashkent',
                'learning_material_max_mb' => 25,
                'student_submission_max_mb' => 15,
                'updated_by_user_id' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);

            $institutions[$specification['key']] = $institution;
        }

        return $institutions;
    }

    /**
     * @return array{key: string, id: string, name: string, type: InstitutionType, status: InstitutionStatus, created_at: string}
     */
    private function institutionSpecification(
        string $key,
        string $id,
        string $name,
        InstitutionType $type,
        InstitutionStatus $status,
        string $createdAt,
    ): array {
        return compact('key', 'id', 'name', 'type', 'status') + [
            'created_at' => $createdAt,
        ];
    }

    /**
     * @param  array<string, Institution>  $institutions
     */
    private function createUsers(array $institutions, string $password, string $initialPassword): void
    {
        $createdAt = Carbon::parse('2029-02-01 10:00:00+00');

        $this->createUser(
            1,
            UserRole::PlatformOwner,
            null,
            'e2e_s02_platform_owner',
            'E2E S02 Platform Owner',
            $password,
            $createdAt,
        );

        for ($index = 1; $index <= 24; $index++) {
            $loginName = match ($index) {
                1 => 'e2e_s02_target_admin',
                2 => 'e2e_s02_inactive_admin',
                3 => 'e2e_s02_password_gate_admin',
                4 => 'e2e_s02_admin_percent',
                default => sprintf('e2e_s02_admin_%02d', $index),
            };
            $fullName = match ($index) {
                1 => 'E2E S02 Target Admin',
                2 => 'E2E S02 Inactive Admin',
                3 => 'E2E S02 Password Gate Admin',
                4 => 'E2E S02 Admin % Literal',
                default => sprintf('E2E S02 Admin %02d', $index),
            };
            $isActive = $index !== 2;
            $mustChangePassword = $index === 3;

            $this->createUser(
                100 + $index,
                UserRole::InstitutionAdmin,
                $institutions['target'],
                $loginName,
                $fullName,
                $mustChangePassword ? $initialPassword : $password,
                $createdAt->copy()->addMinutes($index),
                isActive: $isActive,
                mustChangePassword: $mustChangePassword,
            );
        }

        $this->createUser(
            201,
            UserRole::Teacher,
            $institutions['target'],
            'e2e_s02_teacher',
            'E2E S02 Teacher',
            $password,
            $createdAt->copy()->addHours(1),
        );
        $this->createUser(
            202,
            UserRole::Student,
            $institutions['target'],
            'e2e_s02_student',
            'E2E S02 Student',
            $password,
            $createdAt->copy()->addHours(2),
        );
        $this->createUser(
            203,
            UserRole::Parent,
            $institutions['target'],
            'e2e_s02_parent',
            'E2E S02 Parent',
            $password,
            $createdAt->copy()->addHours(3),
        );
        $this->createUser(
            204,
            UserRole::Teacher,
            $institutions['target'],
            'e2e_s02_non_admin_target',
            'E2E S02 Non Admin Target',
            $password,
            $createdAt->copy()->addHours(4),
            isActive: false,
        );
        $this->createUser(
            205,
            UserRole::InstitutionAdmin,
            $institutions['inactive'],
            'e2e_s02_inactive_institution_admin',
            'E2E S02 Inactive Institution Admin',
            $password,
            $createdAt->copy()->addHours(5),
        );
        $this->createUser(
            206,
            UserRole::InstitutionAdmin,
            $institutions['unaffected'],
            'e2e_s02_unaffected_admin',
            'E2E S02 Unaffected Admin',
            $password,
            $createdAt->copy()->addHours(6),
        );
    }

    private function createUser(
        int $idSuffix,
        UserRole $role,
        ?Institution $institution,
        string $loginName,
        string $fullName,
        string $password,
        Carbon $createdAt,
        bool $isActive = true,
        bool $mustChangePassword = false,
    ): void {
        $factory = match ($role) {
            UserRole::PlatformOwner => User::factory()->platformOwner(),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
        };

        $factory->withPassword($password)->create([
            'id' => $this->userId($idSuffix),
            'full_name' => $fullName,
            'login_name' => $loginName,
            'email' => $loginName.'@e2e-s02.invalid',
            'phone' => '+998911'.str_pad((string) $idSuffix, 6, '0', STR_PAD_LEFT),
            'is_active' => $isActive,
            'must_change_password' => $mustChangePassword,
            'last_login_at' => null,
            'deactivated_at' => $isActive ? null : $createdAt->copy()->addMinute(),
            'created_by_user_id' => null,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
    }

    private function institutionId(int $suffix): string
    {
        return sprintf('02000000-0000-4000-8000-%012d', $suffix);
    }

    private function userId(int $suffix): string
    {
        return sprintf('02000000-0000-4000-9000-%012d', $suffix);
    }
}
