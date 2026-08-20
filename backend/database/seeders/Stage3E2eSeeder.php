<?php

namespace Database\Seeders;

use App\Enums\BlitzTimerStartMode;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Enums\UnderstandingCategoryCode;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class Stage3E2eSeeder extends Seeder
{
    private const TEST_DATABASE = 'testlabuz_testing';

    private const REQUIRED_SECRETS = [
        'STAGE3_E2E_PASSWORD',
        'STAGE3_E2E_FIRST_LOGIN_PASSWORD',
        'STAGE3_E2E_USER_INITIAL_PASSWORD',
        'STAGE3_E2E_USER_NEW_PASSWORD',
    ];

    private const TARGET_INSTITUTION_ID = '03000000-0000-4000-8000-000000000101';

    private const FOREIGN_INSTITUTION_ID = '03000000-0000-4000-8000-000000000102';

    private const INACTIVE_INSTITUTION_ID = '03000000-0000-4000-8000-000000000103';

    private const EMPTY_INSTITUTION_ID = '03000000-0000-4000-8000-000000000104';

    /** @var list<string> */
    private const FIXTURE_INSTITUTION_IDS = [
        self::TARGET_INSTITUTION_ID,
        self::FOREIGN_INSTITUTION_ID,
        self::INACTIVE_INSTITUTION_ID,
        self::EMPTY_INSTITUTION_ID,
    ];

    /** @var list<string> */
    private const RESERVED_UI_LOGIN_NAMES = [
        'e2e_s03_created_teacher',
        'e2e_s03_created_student',
        'e2e_s03_created_parent',
    ];

    public function run(): void
    {
        $this->assertSafeRuntime();
        $passwords = $this->requiredSecrets();

        DB::transaction(function () use ($passwords): void {
            $this->assertManifestCollisionsSafe();
            $this->resetOwnedFixtures();

            $institutions = $this->createInstitutions();
            $users = $this->createUsers(
                $institutions,
                $passwords['STAGE3_E2E_PASSWORD'],
                $passwords['STAGE3_E2E_FIRST_LOGIN_PASSWORD'],
            );
            $this->createSettings($institutions, $users);
            $this->createCategories($institutions, $users);
            $this->createPreservedTokenRows($users['teacher']);
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
            throw new RuntimeException('Stage3E2eSeeder may only run with APP_ENV=testing.');
        }

        if ($this->currentDatabase() !== self::TEST_DATABASE) {
            throw new RuntimeException('Stage3E2eSeeder may only run against testlabuz_testing.');
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

        if (count(array_unique(array_values($secrets))) !== count($secrets)) {
            throw new RuntimeException('Every Stage 3 E2E transient password must be distinct.');
        }

        return $secrets;
    }

    private function assertManifestCollisionsSafe(): void
    {
        $institutionManifest = $this->fixtureInstitutionManifest();
        $reservedNames = collect($institutionManifest)
            ->flatMap(static fn (array $specification): array => $specification['names'])
            ->all();
        $institutions = Institution::query()
            ->whereIn('id', array_keys($institutionManifest))
            ->orWhereIn('name', $reservedNames)
            ->get();

        foreach ($institutions as $institution) {
            $expected = $institutionManifest[$institution->id] ?? null;
            if (
                $expected === null
                || ! in_array($institution->name, $expected['names'], true)
                || $institution->type->value !== $expected['type']
                || $institution->status->value !== $expected['status']
            ) {
                throw new RuntimeException('Stage 3 E2E Institution manifest collision detected.');
            }
        }

        $userManifest = $this->fixtureUserManifest();
        $reservedUiManifest = $this->reservedUiUserManifest();
        $reservedLogins = [
            ...array_column($userManifest, 'login_name'),
            ...array_keys($reservedUiManifest),
        ];
        $users = User::query()
            ->whereIn('id', array_keys($userManifest))
            ->orWhereIn('login_name', $reservedLogins)
            ->get();

        foreach ($users as $user) {
            $expected = $userManifest[$user->id] ?? null;
            if ($expected !== null) {
                if (
                    $user->login_name !== $expected['login_name']
                    || $user->role->value !== $expected['role']
                    || $user->institution_id !== $expected['institution_id']
                ) {
                    throw new RuntimeException('Stage 3 E2E User manifest collision detected.');
                }

                continue;
            }

            $reserved = $reservedUiManifest[$user->login_name] ?? null;
            if (
                $reserved === null
                || $user->role->value !== $reserved['role']
                || $user->institution_id !== self::TARGET_INSTITUTION_ID
            ) {
                throw new RuntimeException('Stage 3 E2E reserved User login collision detected.');
            }
        }
    }

    /**
     * @return array<string, array{names: list<string>, type: string, status: string}>
     */
    private function fixtureInstitutionManifest(): array
    {
        return [
            self::TARGET_INSTITUTION_ID => [
                'names' => ['E2E S03 Target Institution', 'E2E S03 Target Institution Edited'],
                'type' => InstitutionType::School->value,
                'status' => InstitutionStatus::Active->value,
            ],
            self::FOREIGN_INSTITUTION_ID => [
                'names' => ['E2E S03 Foreign Institution'],
                'type' => InstitutionType::University->value,
                'status' => InstitutionStatus::Active->value,
            ],
            self::INACTIVE_INSTITUTION_ID => [
                'names' => ['E2E S03 Inactive Institution'],
                'type' => InstitutionType::LearningCenter->value,
                'status' => InstitutionStatus::Inactive->value,
            ],
            self::EMPTY_INSTITUTION_ID => [
                'names' => ['E2E S03 Empty Institution'],
                'type' => InstitutionType::TrainingCenter->value,
                'status' => InstitutionStatus::Active->value,
            ],
        ];
    }

    /**
     * @return array<string, array{login_name: string, role: string, institution_id: ?string}>
     */
    private function fixtureUserManifest(): array
    {
        $users = [
            101 => ['e2e_s03_target_admin', UserRole::InstitutionAdmin, self::TARGET_INSTITUTION_ID],
            102 => ['e2e_s03_second_admin', UserRole::InstitutionAdmin, self::TARGET_INSTITUTION_ID],
            103 => ['e2e_s03_password_gate_admin', UserRole::InstitutionAdmin, self::TARGET_INSTITUTION_ID],
            104 => ['e2e_s03_inactive_admin', UserRole::InstitutionAdmin, self::TARGET_INSTITUTION_ID],
            105 => ['e2e_s03_foreign_admin', UserRole::InstitutionAdmin, self::FOREIGN_INSTITUTION_ID],
            106 => ['e2e_s03_inactive_institution_admin', UserRole::InstitutionAdmin, self::INACTIVE_INSTITUTION_ID],
            107 => ['e2e_s03_empty_admin', UserRole::InstitutionAdmin, self::EMPTY_INSTITUTION_ID],
            108 => ['e2e_s03_platform_owner', UserRole::PlatformOwner, null],
            201 => ['e2e_s03_teacher', UserRole::Teacher, self::TARGET_INSTITUTION_ID],
            202 => ['e2e_s03_student', UserRole::Student, self::TARGET_INSTITUTION_ID],
            203 => ['e2e_s03_parent', UserRole::Parent, self::TARGET_INSTITUTION_ID],
            204 => ['e2e_s03_foreign_teacher', UserRole::Teacher, self::FOREIGN_INSTITUTION_ID],
            205 => ['e2e_s03_foreign_student', UserRole::Student, self::FOREIGN_INSTITUTION_ID],
            206 => ['e2e_s03_foreign_parent', UserRole::Parent, self::FOREIGN_INSTITUTION_ID],
        ];

        $roles = [UserRole::Teacher, UserRole::Student, UserRole::Parent];
        for ($index = 1; $index <= 24; $index++) {
            $loginName = match ($index) {
                4 => 'e2e_s03_literal_percent',
                5 => 'e2e_s03_literal_underscore',
                default => sprintf('e2e_s03_member_%02d', $index),
            };
            $users[300 + $index] = [
                $loginName,
                $roles[($index - 1) % count($roles)],
                self::TARGET_INSTITUTION_ID,
            ];
        }

        $manifest = [];
        foreach ($users as $suffix => [$loginName, $role, $institutionId]) {
            $manifest[$this->userId($suffix)] = [
                'login_name' => $loginName,
                'role' => $role->value,
                'institution_id' => $institutionId,
            ];
        }

        return $manifest;
    }

    /**
     * @return array<string, array{role: string}>
     */
    private function reservedUiUserManifest(): array
    {
        return [
            'e2e_s03_created_teacher' => ['role' => UserRole::Teacher->value],
            'e2e_s03_created_student' => ['role' => UserRole::Student->value],
            'e2e_s03_created_parent' => ['role' => UserRole::Parent->value],
        ];
    }

    private function resetOwnedFixtures(): void
    {
        $seededUserIds = $this->fixtureUserIds();
        $ownedUserIds = User::query()
            ->whereIn('id', $seededUserIds)
            ->orWhereIn('login_name', self::RESERVED_UI_LOGIN_NAMES)
            ->pluck('id');

        InstitutionUnderstandingCategory::query()
            ->whereIn('institution_id', self::FIXTURE_INSTITUTION_IDS)
            ->delete();

        if ($ownedUserIds->isNotEmpty()) {
            DB::table('personal_access_tokens')
                ->where('tokenable_type', User::class)
                ->whereIn('tokenable_id', $ownedUserIds)
                ->delete();

            Institution::query()
                ->whereIn('created_by_user_id', $ownedUserIds)
                ->update(['created_by_user_id' => null]);

            InstitutionSetting::query()
                ->whereIn('updated_by_user_id', $ownedUserIds)
                ->update(['updated_by_user_id' => null]);

            User::query()
                ->whereIn('created_by_user_id', $ownedUserIds)
                ->update(['created_by_user_id' => null]);

            User::query()->whereIn('id', $ownedUserIds)->delete();
        }

        InstitutionSetting::query()
            ->whereIn('institution_id', self::FIXTURE_INSTITUTION_IDS)
            ->delete();

        Institution::query()
            ->whereIn('id', self::FIXTURE_INSTITUTION_IDS)
            ->delete();
    }

    /**
     * @return array<string, Institution>
     */
    private function createInstitutions(): array
    {
        $createdAt = Carbon::parse('2031-03-01 08:00:00+00');
        $specifications = [
            'target' => [
                'id' => self::TARGET_INSTITUTION_ID,
                'name' => 'E2E S03 Target Institution',
                'type' => InstitutionType::School,
                'status' => InstitutionStatus::Active,
            ],
            'foreign' => [
                'id' => self::FOREIGN_INSTITUTION_ID,
                'name' => 'E2E S03 Foreign Institution',
                'type' => InstitutionType::University,
                'status' => InstitutionStatus::Active,
            ],
            'inactive' => [
                'id' => self::INACTIVE_INSTITUTION_ID,
                'name' => 'E2E S03 Inactive Institution',
                'type' => InstitutionType::LearningCenter,
                'status' => InstitutionStatus::Inactive,
            ],
            'empty' => [
                'id' => self::EMPTY_INSTITUTION_ID,
                'name' => 'E2E S03 Empty Institution',
                'type' => InstitutionType::TrainingCenter,
                'status' => InstitutionStatus::Active,
            ],
        ];

        $institutions = [];
        foreach ($specifications as $index => $specification) {
            $timestamp = $createdAt->copy()->addMinutes(count($institutions));
            $inactive = $specification['status'] === InstitutionStatus::Inactive;
            $institutions[$index] = Institution::factory()->create([
                'id' => $specification['id'],
                'name' => $specification['name'],
                'type' => $specification['type'],
                'status' => $specification['status'],
                'contact_email' => $index.'@e2e-s03.invalid',
                'contact_phone' => '+99890030000'.count($institutions),
                'address' => 'E2E S03 deterministic address '.$index,
                'description' => 'E2E S03 deterministic verification fixture '.$index.'.',
                'created_by_user_id' => null,
                'deactivated_at' => $inactive ? $timestamp->copy()->addMinute() : null,
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ]);
        }

        return $institutions;
    }

    /**
     * @param  array<string, Institution>  $institutions
     * @return array<string, User>
     */
    private function createUsers(array $institutions, string $password, string $initialPassword): array
    {
        $createdAt = Carbon::parse('2031-03-02 08:00:00+00');
        $users = [];
        $users['target_admin'] = $this->createUser(101, $institutions['target'], UserRole::InstitutionAdmin, 'e2e_s03_target_admin', 'E2E S03 Target Admin', $password, $createdAt);
        $users['second_admin'] = $this->createUser(102, $institutions['target'], UserRole::InstitutionAdmin, 'e2e_s03_second_admin', 'E2E S03 Second Admin', $password, $createdAt->copy()->addMinute());
        $users['password_gate_admin'] = $this->createUser(103, $institutions['target'], UserRole::InstitutionAdmin, 'e2e_s03_password_gate_admin', 'E2E S03 Password Gate Admin', $initialPassword, $createdAt->copy()->addMinutes(2), mustChangePassword: true);
        $users['inactive_admin'] = $this->createUser(104, $institutions['target'], UserRole::InstitutionAdmin, 'e2e_s03_inactive_admin', 'E2E S03 Inactive Admin', $password, $createdAt->copy()->addMinutes(3), isActive: false);
        $users['foreign_admin'] = $this->createUser(105, $institutions['foreign'], UserRole::InstitutionAdmin, 'e2e_s03_foreign_admin', 'E2E S03 Foreign Admin', $password, $createdAt->copy()->addMinutes(4));
        $users['inactive_institution_admin'] = $this->createUser(106, $institutions['inactive'], UserRole::InstitutionAdmin, 'e2e_s03_inactive_institution_admin', 'E2E S03 Inactive Institution Admin', $password, $createdAt->copy()->addMinutes(5));
        $users['empty_admin'] = $this->createUser(107, $institutions['empty'], UserRole::InstitutionAdmin, 'e2e_s03_empty_admin', 'E2E S03 Empty Admin', $password, $createdAt->copy()->addMinutes(6));
        $users['platform_owner'] = User::factory()->platformOwner()->withPassword($password)->create([
            'id' => $this->userId(108),
            'full_name' => 'E2E S03 Platform Owner',
            'login_name' => 'e2e_s03_platform_owner',
            'email' => 'e2e_s03_platform_owner@e2e-s03.invalid',
            'phone' => '+998930300108',
            'is_active' => true,
            'must_change_password' => false,
            'last_login_at' => null,
            'deactivated_at' => null,
            'created_by_user_id' => null,
            'created_at' => $createdAt->copy()->addMinutes(7),
            'updated_at' => $createdAt->copy()->addMinutes(7),
        ]);

        $users['teacher'] = $this->createUser(201, $institutions['target'], UserRole::Teacher, 'e2e_s03_teacher', 'E2E S03 Teacher', $password, $createdAt->copy()->addMinutes(10));
        $users['student'] = $this->createUser(202, $institutions['target'], UserRole::Student, 'e2e_s03_student', 'E2E S03 Student', $password, $createdAt->copy()->addMinutes(11));
        $users['parent'] = $this->createUser(203, $institutions['target'], UserRole::Parent, 'e2e_s03_parent', 'E2E S03 Parent', $password, $createdAt->copy()->addMinutes(12));
        $users['foreign_teacher'] = $this->createUser(204, $institutions['foreign'], UserRole::Teacher, 'e2e_s03_foreign_teacher', 'E2E S03 Foreign Teacher', $password, $createdAt->copy()->addMinutes(13));
        $users['foreign_student'] = $this->createUser(205, $institutions['foreign'], UserRole::Student, 'e2e_s03_foreign_student', 'E2E S03 Foreign Student', $password, $createdAt->copy()->addMinutes(14));
        $users['foreign_parent'] = $this->createUser(206, $institutions['foreign'], UserRole::Parent, 'e2e_s03_foreign_parent', 'E2E S03 Foreign Parent', $password, $createdAt->copy()->addMinutes(15));

        $roles = [UserRole::Teacher, UserRole::Student, UserRole::Parent];
        for ($index = 1; $index <= 24; $index++) {
            $role = $roles[($index - 1) % count($roles)];
            $loginName = match ($index) {
                4 => 'e2e_s03_literal_percent',
                5 => 'e2e_s03_literal_underscore',
                default => sprintf('e2e_s03_member_%02d', $index),
            };
            $fullName = match ($index) {
                4 => 'E2E S03 Literal % User',
                5 => 'E2E S03 Literal _ User',
                6 => 'E2E S03 Literal ! User',
                default => sprintf('E2E S03 Member %02d', $index),
            };

            $this->createUser(
                300 + $index,
                $institutions['target'],
                $role,
                $loginName,
                $fullName,
                $password,
                $createdAt->copy()->addMinutes(30 + $index),
                isActive: $index % 7 !== 0,
            );
        }

        return $users;
    }

    private function createUser(
        int $idSuffix,
        Institution $institution,
        UserRole $role,
        string $loginName,
        string $fullName,
        string $password,
        Carbon $createdAt,
        bool $isActive = true,
        bool $mustChangePassword = false,
    ): User {
        $factory = match ($role) {
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
            UserRole::PlatformOwner => throw new RuntimeException('Stage 3 fixture users must be Institution-scoped.'),
        };

        return $factory->withPassword($password)->create([
            'id' => $this->userId($idSuffix),
            'full_name' => $fullName,
            'login_name' => $loginName,
            'email' => $loginName.'@e2e-s03.invalid',
            'phone' => '+9989303'.str_pad((string) $idSuffix, 5, '0', STR_PAD_LEFT),
            'is_active' => $isActive,
            'must_change_password' => $mustChangePassword,
            'last_login_at' => null,
            'deactivated_at' => $isActive ? null : $createdAt->copy()->addMinute(),
            'created_by_user_id' => null,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
    }

    /**
     * @param  array<string, Institution>  $institutions
     * @param  array<string, User>  $users
     */
    private function createSettings(array $institutions, array $users): void
    {
        $settings = [
            'target' => [null, null, null, null, 'Asia/Tashkent', 25, 15, null],
            'foreign' => [7, BlitzTimerStartMode::Individual, StudentResultReleaseMode::ManualTeacher, ParentResultReleaseMode::Hidden, 'Europe/London', 20, 10, $users['foreign_admin']],
            'inactive' => [null, null, null, null, 'Asia/Tashkent', 25, 15, null],
            'empty' => [null, null, null, null, 'Asia/Tashkent', 25, 15, null],
        ];

        foreach ($settings as $key => [$difference, $timer, $studentRelease, $parentRelease, $timezone, $learningLimit, $submissionLimit, $updater]) {
            InstitutionSetting::factory()->create([
                'institution_id' => $institutions[$key]->id,
                'acceptable_score_difference' => $difference,
                'blitz_timer_start_mode' => $timer,
                'student_result_release_mode' => $studentRelease,
                'parent_result_release_mode' => $parentRelease,
                'timezone' => $timezone,
                'learning_material_max_mb' => $learningLimit,
                'student_submission_max_mb' => $submissionLimit,
                'updated_by_user_id' => $updater?->id,
                'created_at' => Carbon::parse('2031-03-03 08:00:00+00'),
                'updated_at' => Carbon::parse('2031-03-03 08:00:00+00'),
            ]);
        }
    }

    /**
     * @param  array<string, Institution>  $institutions
     * @param  array<string, User>  $users
     */
    private function createCategories(array $institutions, array $users): void
    {
        $this->createCategorySet($institutions['foreign'], $users['foreign_admin'], [90, 70, 40, 0]);
    }

    /**
     * @param  list<int>  $minimums
     */
    private function createCategorySet(Institution $institution, User $updater, array $minimums): void
    {
        $codes = UnderstandingCategoryCode::cases();
        foreach ($codes as $index => $code) {
            $minimum = $code->isNumeric() ? $minimums[$index] : null;
            $maximum = match ($index) {
                0 => 100,
                1, 2, 3 => $minimums[$index - 1] - 1,
                default => null,
            };

            InstitutionUnderstandingCategory::factory()
                ->forInstitution($institution, $updater)
                ->forCode($code, $minimum, $maximum)
                ->create([
                    'id' => $this->categoryId(200 + $index),
                    'created_at' => Carbon::parse('2031-03-03 09:00:00+00'),
                    'updated_at' => Carbon::parse('2031-03-03 09:00:00+00'),
                ]);
        }
    }

    private function createPreservedTokenRows(User $lifecycleUser): void
    {
        $timestamp = Carbon::parse('2031-03-03 10:00:00+00');

        foreach (['stage3-preservation-a', 'stage3-preservation-b'] as $index => $name) {
            DB::table('personal_access_tokens')->insert([
                'tokenable_type' => User::class,
                'tokenable_id' => $lifecycleUser->id,
                'name' => $name,
                'token' => hash('sha256', random_bytes(32)),
                'abilities' => json_encode(['*'], JSON_THROW_ON_ERROR),
                'last_used_at' => null,
                'expires_at' => null,
                'created_at' => $timestamp->copy()->addMinutes($index),
                'updated_at' => $timestamp->copy()->addMinutes($index),
            ]);
        }
    }

    /**
     * @return list<string>
     */
    private function fixtureUserIds(): array
    {
        $suffixes = [101, 102, 103, 104, 105, 106, 107, 108, 201, 202, 203, 204, 205, 206];
        for ($suffix = 301; $suffix <= 324; $suffix++) {
            $suffixes[] = $suffix;
        }

        return array_map(fn (int $suffix): string => $this->userId($suffix), $suffixes);
    }

    private function userId(int $suffix): string
    {
        return sprintf('03000000-0000-4000-9000-%012d', $suffix);
    }

    private function categoryId(int $suffix): string
    {
        return sprintf('03000000-0000-4000-a000-%012d', $suffix);
    }
}
