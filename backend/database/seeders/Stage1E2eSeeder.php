<?php

namespace Database\Seeders;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class Stage1E2eSeeder extends Seeder
{
    private const TEST_DATABASE = 'testlabuz_testing';

    private const ACTIVE_INSTITUTION_NAME = 'E2E Active Institution';

    private const INACTIVE_INSTITUTION_NAME = 'E2E Inactive Institution';

    private const LOGIN_NAMES = [
        'e2e_platform_owner',
        'e2e_institution_admin',
        'e2e_teacher_a',
        'e2e_teacher_b',
        'e2e_student',
        'e2e_parent',
        'e2e_teacher_must_change',
        'e2e_inactive_user',
        'e2e_inactive_institution_user',
    ];

    public function run(): void
    {
        $this->assertSafeRuntime();

        $password = $this->requiredSecret('STAGE1_E2E_PASSWORD');

        DB::transaction(function () use ($password): void {
            $this->resetStage1Fixtures();

            $activeInstitution = Institution::factory()->create([
                'name' => self::ACTIVE_INSTITUTION_NAME,
                'type' => InstitutionType::School,
                'status' => InstitutionStatus::Active,
                'contact_email' => null,
                'contact_phone' => null,
                'address' => null,
                'description' => 'Stage 1 E2E active fixture institution.',
                'created_by_user_id' => null,
                'deactivated_at' => null,
            ]);
            InstitutionSetting::factory()
                ->configuredEducationalPolicy()
                ->create(['institution_id' => $activeInstitution->id]);

            $inactiveInstitution = Institution::factory()->inactive()->create([
                'name' => self::INACTIVE_INSTITUTION_NAME,
                'type' => InstitutionType::School,
                'contact_email' => null,
                'contact_phone' => null,
                'address' => null,
                'description' => 'Stage 1 E2E inactive fixture institution.',
                'created_by_user_id' => null,
            ]);
            InstitutionSetting::factory()
                ->configuredEducationalPolicy()
                ->create(['institution_id' => $inactiveInstitution->id]);

            $this->createUser(
                UserRole::PlatformOwner,
                null,
                'e2e_platform_owner',
                'E2E Platform Owner',
                $password,
            );
            $this->createUser(
                UserRole::InstitutionAdmin,
                $activeInstitution,
                'e2e_institution_admin',
                'E2E Institution Admin',
                $password,
            );
            $this->createUser(
                UserRole::Teacher,
                $activeInstitution,
                'e2e_teacher_a',
                'E2E Teacher A',
                $password,
            );
            $this->createUser(
                UserRole::Teacher,
                $activeInstitution,
                'e2e_teacher_b',
                'E2E Teacher B',
                $password,
            );
            $this->createUser(
                UserRole::Student,
                $activeInstitution,
                'e2e_student',
                'E2E Student',
                $password,
            );
            $this->createUser(
                UserRole::Parent,
                $activeInstitution,
                'e2e_parent',
                'E2E Parent',
                $password,
            );
            $this->createUser(
                UserRole::Teacher,
                $activeInstitution,
                'e2e_teacher_must_change',
                'E2E Teacher Must Change',
                $password,
                mustChangePassword: true,
            );
            $this->createUser(
                UserRole::Teacher,
                $activeInstitution,
                'e2e_inactive_user',
                'E2E Inactive User',
                $password,
                isActive: false,
            );
            $this->createUser(
                UserRole::Teacher,
                $inactiveInstitution,
                'e2e_inactive_institution_user',
                'E2E Inactive Institution User',
                $password,
            );
        });
    }

    private function assertSafeRuntime(): void
    {
        if (! app()->environment('testing')) {
            throw new RuntimeException('Stage1E2eSeeder may only run with APP_ENV=testing.');
        }

        $database = DB::scalar('select current_database()');

        if ($database !== self::TEST_DATABASE) {
            throw new RuntimeException('Stage1E2eSeeder may only run against testlabuz_testing.');
        }
    }

    private function requiredSecret(string $name): string
    {
        $value = env($name);

        if (! is_string($value) || trim($value) === '') {
            throw new RuntimeException($name.' must be provided by the local environment.');
        }

        return $value;
    }

    private function resetStage1Fixtures(): void
    {
        $userIds = User::query()
            ->whereIn('login_name', self::LOGIN_NAMES)
            ->pluck('id');

        if ($userIds->isNotEmpty()) {
            DB::table('personal_access_tokens')
                ->where('tokenable_type', User::class)
                ->whereIn('tokenable_id', $userIds)
                ->delete();
        }

        User::query()
            ->whereIn('login_name', self::LOGIN_NAMES)
            ->delete();

        $institutionIds = Institution::query()
            ->whereIn('name', [
                self::ACTIVE_INSTITUTION_NAME,
                self::INACTIVE_INSTITUTION_NAME,
            ])
            ->pluck('id');

        if ($institutionIds->isEmpty()) {
            return;
        }

        InstitutionSetting::query()
            ->whereIn('institution_id', $institutionIds)
            ->delete();

        Institution::query()
            ->whereIn('id', $institutionIds)
            ->delete();
    }

    private function createUser(
        UserRole $role,
        ?Institution $institution,
        string $loginName,
        string $fullName,
        string $password,
        bool $mustChangePassword = false,
        bool $isActive = true,
    ): void {
        $factory = match ($role) {
            UserRole::PlatformOwner => User::factory()->platformOwner(),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
        };

        $factory->withPassword($password)->create([
            'full_name' => $fullName,
            'login_name' => $loginName,
            'email' => null,
            'phone' => null,
            'is_active' => $isActive,
            'must_change_password' => $mustChangePassword,
            'deactivated_at' => $isActive ? null : now(),
            'created_by_user_id' => null,
        ]);
    }
}
