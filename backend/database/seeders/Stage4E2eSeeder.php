<?php

namespace Database\Seeders;

use App\Enums\GroupStatus;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\UserRole;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class Stage4E2eSeeder extends Seeder
{
    private const TEST_DATABASE = 'testlabuz_testing';

    private const PASSWORD_ENVIRONMENT_NAME = 'STAGE4_E2E_PASSWORD';

    private const TARGET_INSTITUTION_ID = '04000000-0000-4000-8000-000000000101';

    private const FOREIGN_INSTITUTION_ID = '04000000-0000-4000-8000-000000000102';

    private const TARGET_ADMIN_ID = '04000000-0000-4000-9000-000000000101';

    private const FOREIGN_ADMIN_ID = '04000000-0000-4000-9000-000000000102';

    private const TARGET_ACTIVE_TEACHER_ID = '04000000-0000-4000-9000-000000000201';

    private const TARGET_INACTIVE_TEACHER_ID = '04000000-0000-4000-9000-000000000202';

    private const TARGET_ACTIVE_STUDENT_ID = '04000000-0000-4000-9000-000000000203';

    private const TARGET_INACTIVE_STUDENT_ID = '04000000-0000-4000-9000-000000000204';

    private const TARGET_FLOW_STUDENT_ID = '04000000-0000-4000-9000-000000000205';

    private const TARGET_ACTIVE_PARENT_ID = '04000000-0000-4000-9000-000000000206';

    private const TARGET_INACTIVE_PARENT_ID = '04000000-0000-4000-9000-000000000207';

    private const TARGET_FLOW_PARENT_ID = '04000000-0000-4000-9000-000000000208';

    private const FOREIGN_ACTIVE_TEACHER_ID = '04000000-0000-4000-9000-000000000301';

    private const FOREIGN_ACTIVE_STUDENT_ID = '04000000-0000-4000-9000-000000000302';

    private const FOREIGN_ACTIVE_PARENT_ID = '04000000-0000-4000-9000-000000000303';

    private const TARGET_ACTIVE_GROUP_ID = '04000000-0000-4000-a000-000000000101';

    private const TARGET_ARCHIVED_GROUP_ID = '04000000-0000-4000-a000-000000000102';

    private const FOREIGN_ACTIVE_GROUP_ID = '04000000-0000-4000-a000-000000000103';

    private const TARGET_TEACHER_MEMBERSHIP_ID = '04000000-0000-4000-b000-000000000101';

    private const TARGET_STUDENT_MEMBERSHIP_ID = '04000000-0000-4000-b000-000000000102';

    private const FOREIGN_TEACHER_MEMBERSHIP_ID = '04000000-0000-4000-b000-000000000201';

    private const FOREIGN_STUDENT_MEMBERSHIP_ID = '04000000-0000-4000-b000-000000000202';

    private const TARGET_RELATIONSHIP_ID = '04000000-0000-4000-c000-000000000101';

    private const FOREIGN_RELATIONSHIP_ID = '04000000-0000-4000-c000-000000000102';

    private const UI_GROUP_NAMES = [
        'E2E S04 UI Group',
        'E2E S04 UI Group Edited',
    ];

    public function run(): void
    {
        $this->assertSafeRuntime();
        $password = $this->requiredPassword();

        DB::transaction(function () use ($password): void {
            $ownedGroupIds = $this->assertManifestCollisionsSafe();
            $this->resetOwnedFixtures($ownedGroupIds);
            $institutions = $this->createInstitutions();
            $users = $this->createUsers($institutions, $password);
            $this->createSettings($institutions);
            $groups = $this->createGroups($institutions, $users);
            $this->createMemberships($institutions, $users, $groups);
            $this->createRelationships($institutions, $users);
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

    protected function connectionDriver(): string
    {
        return DB::connection()->getDriverName();
    }

    protected function pdoDriver(): string
    {
        return (string) DB::connection()->getPdo()->getAttribute(\PDO::ATTR_DRIVER_NAME);
    }

    private function assertSafeRuntime(): void
    {
        if ($this->runtimeEnvironment() !== 'testing') {
            throw new RuntimeException('Stage4E2eSeeder may only run with APP_ENV=testing.');
        }

        if ($this->connectionDriver() !== 'pgsql' || $this->pdoDriver() !== 'pgsql') {
            throw new RuntimeException('Stage4E2eSeeder requires Laravel pgsql and PDO pgsql.');
        }

        if ($this->currentDatabase() !== self::TEST_DATABASE) {
            throw new RuntimeException('Stage4E2eSeeder may only run against testlabuz_testing.');
        }
    }

    private function requiredPassword(): string
    {
        $password = env(self::PASSWORD_ENVIRONMENT_NAME);
        if (! is_string($password) || trim($password) === '') {
            throw new RuntimeException(self::PASSWORD_ENVIRONMENT_NAME.' must be provided by the local environment.');
        }

        return $password;
    }

    /**
     * @return list<string>
     */
    private function assertManifestCollisionsSafe(): array
    {
        $this->assertInstitutionManifestSafe();
        $this->assertSettingManifestSafe();
        $this->assertUserManifestSafe();
        $ownedGroupIds = $this->assertGroupManifestSafe();
        $this->assertTeacherMembershipManifestSafe($ownedGroupIds);
        $this->assertStudentMembershipManifestSafe($ownedGroupIds);
        $this->assertRelationshipManifestSafe();

        return $ownedGroupIds;
    }

    private function assertInstitutionManifestSafe(): void
    {
        $manifest = $this->institutionManifest();
        $rows = Institution::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('name', array_column($manifest, 'name'))
            ->get();

        foreach ($rows as $institution) {
            $expected = $manifest[$institution->id] ?? null;
            if (
                $expected === null
                || $institution->name !== $expected['name']
                || $institution->type->value !== $expected['type']
                || $institution->status->value !== InstitutionStatus::Active->value
            ) {
                throw new RuntimeException('Stage 4 E2E Institution manifest collision detected.');
            }
        }
    }

    private function assertUserManifestSafe(): void
    {
        $manifest = $this->userManifest();
        $rows = User::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('login_name', array_column($manifest, 'login_name'))
            ->get();

        foreach ($rows as $user) {
            $expected = $manifest[$user->id] ?? null;
            if (
                $expected === null
                || $user->login_name !== $expected['login_name']
                || $user->role->value !== $expected['role']
                || $user->institution_id !== $expected['institution_id']
            ) {
                throw new RuntimeException('Stage 4 E2E User manifest collision detected.');
            }
        }
    }

    private function assertSettingManifestSafe(): void
    {
        $rows = InstitutionSetting::query()
            ->whereIn('institution_id', array_keys($this->institutionManifest()))
            ->get();

        foreach ($rows as $setting) {
            if (
                $setting->timezone !== 'Asia/Tashkent'
                || $setting->acceptable_score_difference !== null
                || $setting->blitz_timer_start_mode !== null
                || $setting->student_result_release_mode !== null
                || $setting->parent_result_release_mode !== null
                || $setting->learning_material_max_mb !== 25
                || $setting->student_submission_max_mb !== 15
                || $setting->updated_by_user_id !== null
            ) {
                throw new RuntimeException('Stage 4 E2E Institution setting manifest collision detected.');
            }
        }
    }

    /**
     * @return list<string>
     */
    private function assertGroupManifestSafe(): array
    {
        $manifest = $this->groupManifest();
        $rows = Group::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('name', [...array_column($manifest, 'name'), ...self::UI_GROUP_NAMES])
            ->orWhereIn('created_by_user_id', [self::TARGET_ADMIN_ID, self::FOREIGN_ADMIN_ID])
            ->get();
        $ownedGroupIds = [];
        $uiGroups = 0;

        foreach ($rows as $group) {
            $expected = $manifest[$group->id] ?? null;
            if ($expected !== null) {
                if (
                    $group->name !== $expected['name']
                    || $group->institution_id !== $expected['institution_id']
                    || $group->created_by_user_id !== $expected['created_by_user_id']
                    || $group->status->value !== $expected['status']
                ) {
                    throw new RuntimeException('Stage 4 E2E Group manifest collision detected.');
                }
            } else {
                $uiGroups++;
                if (
                    ! in_array($group->name, self::UI_GROUP_NAMES, true)
                    || $group->institution_id !== self::TARGET_INSTITUTION_ID
                    || $group->created_by_user_id !== self::TARGET_ADMIN_ID
                    || ! in_array($group->status, [GroupStatus::Active, GroupStatus::Archived], true)
                ) {
                    throw new RuntimeException('Stage 4 E2E reserved UI Group collision detected.');
                }
            }

            $ownedGroupIds[] = $group->id;
        }

        if ($uiGroups > 1) {
            throw new RuntimeException('Stage 4 E2E reserved UI Group ownership is ambiguous.');
        }

        return array_values(array_unique([...array_keys($manifest), ...$ownedGroupIds]));
    }

    /**
     * @param  list<string>  $ownedGroupIds
     */
    private function assertTeacherMembershipManifestSafe(array $ownedGroupIds): void
    {
        $manifest = $this->teacherMembershipManifest();
        $rows = GroupTeacherMembership::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('group_id', $ownedGroupIds)
            ->orWhereIn('teacher_id', [self::TARGET_ACTIVE_TEACHER_ID, self::TARGET_INACTIVE_TEACHER_ID, self::FOREIGN_ACTIVE_TEACHER_ID])
            ->orWhereIn('assigned_by_user_id', [self::TARGET_ADMIN_ID, self::FOREIGN_ADMIN_ID])
            ->get();

        foreach ($rows as $membership) {
            $expected = $manifest[$membership->id] ?? null;
            $dynamicUiMembership = ! isset($this->groupManifest()[$membership->group_id])
                && in_array($membership->group_id, $ownedGroupIds, true)
                && $membership->institution_id === self::TARGET_INSTITUTION_ID
                && $membership->teacher_id === self::TARGET_ACTIVE_TEACHER_ID
                && $membership->assigned_by_user_id === self::TARGET_ADMIN_ID;

            if ($expected === null && ! $dynamicUiMembership) {
                throw new RuntimeException('Stage 4 E2E Teacher membership manifest collision detected.');
            }
            if ($expected !== null && ! $this->membershipMatches($membership, $expected, 'teacher_id')) {
                throw new RuntimeException('Stage 4 E2E Teacher membership manifest collision detected.');
            }
        }
    }

    /**
     * @param  list<string>  $ownedGroupIds
     */
    private function assertStudentMembershipManifestSafe(array $ownedGroupIds): void
    {
        $manifest = $this->studentMembershipManifest();
        $rows = GroupStudentMembership::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('group_id', $ownedGroupIds)
            ->orWhereIn('student_id', [self::TARGET_ACTIVE_STUDENT_ID, self::TARGET_INACTIVE_STUDENT_ID, self::TARGET_FLOW_STUDENT_ID, self::FOREIGN_ACTIVE_STUDENT_ID])
            ->orWhereIn('assigned_by_user_id', [self::TARGET_ADMIN_ID, self::FOREIGN_ADMIN_ID])
            ->get();

        foreach ($rows as $membership) {
            $expected = $manifest[$membership->id] ?? null;
            $dynamicUiMembership = ! isset($this->groupManifest()[$membership->group_id])
                && in_array($membership->group_id, $ownedGroupIds, true)
                && $membership->institution_id === self::TARGET_INSTITUTION_ID
                && $membership->student_id === self::TARGET_FLOW_STUDENT_ID
                && $membership->assigned_by_user_id === self::TARGET_ADMIN_ID;

            if ($expected === null && ! $dynamicUiMembership) {
                throw new RuntimeException('Stage 4 E2E Student membership manifest collision detected.');
            }
            if ($expected !== null && ! $this->membershipMatches($membership, $expected, 'student_id')) {
                throw new RuntimeException('Stage 4 E2E Student membership manifest collision detected.');
            }
        }
    }

    private function assertRelationshipManifestSafe(): void
    {
        $manifest = $this->relationshipManifest();
        $rows = ParentStudentRelationship::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('parent_id', [self::TARGET_ACTIVE_PARENT_ID, self::TARGET_INACTIVE_PARENT_ID, self::TARGET_FLOW_PARENT_ID, self::FOREIGN_ACTIVE_PARENT_ID])
            ->orWhereIn('student_id', [self::TARGET_ACTIVE_STUDENT_ID, self::TARGET_INACTIVE_STUDENT_ID, self::TARGET_FLOW_STUDENT_ID, self::FOREIGN_ACTIVE_STUDENT_ID])
            ->orWhereIn('connected_by_user_id', [self::TARGET_ADMIN_ID, self::FOREIGN_ADMIN_ID])
            ->get();

        foreach ($rows as $relationship) {
            $expected = $manifest[$relationship->id] ?? null;
            $dynamicUiRelationship = $relationship->institution_id === self::TARGET_INSTITUTION_ID
                && $relationship->parent_id === self::TARGET_FLOW_PARENT_ID
                && $relationship->student_id === self::TARGET_FLOW_STUDENT_ID
                && $relationship->connected_by_user_id === self::TARGET_ADMIN_ID;

            if ($expected === null && ! $dynamicUiRelationship) {
                throw new RuntimeException('Stage 4 E2E Parent-Student relationship manifest collision detected.');
            }
            if ($expected !== null && ! $this->relationshipMatches($relationship, $expected)) {
                throw new RuntimeException('Stage 4 E2E Parent-Student relationship manifest collision detected.');
            }
        }
    }

    /**
     * @param  array{institution_id: string, group_id: string, member_id: string, actor_id: string}  $expected
     */
    private function membershipMatches(object $membership, array $expected, string $memberColumn): bool
    {
        return $membership->institution_id === $expected['institution_id']
            && $membership->group_id === $expected['group_id']
            && $membership->{$memberColumn} === $expected['member_id']
            && $membership->assigned_by_user_id === $expected['actor_id'];
    }

    /**
     * @param  array{institution_id: string, parent_id: string, student_id: string, actor_id: string}  $expected
     */
    private function relationshipMatches(ParentStudentRelationship $relationship, array $expected): bool
    {
        return $relationship->institution_id === $expected['institution_id']
            && $relationship->parent_id === $expected['parent_id']
            && $relationship->student_id === $expected['student_id']
            && $relationship->connected_by_user_id === $expected['actor_id'];
    }

    /**
     * @param  list<string>  $ownedGroupIds
     */
    private function resetOwnedFixtures(array $ownedGroupIds): void
    {
        GroupTeacherMembership::query()
            ->whereIn('id', array_keys($this->teacherMembershipManifest()))
            ->orWhereIn('group_id', $ownedGroupIds)
            ->delete();
        GroupStudentMembership::query()
            ->whereIn('id', array_keys($this->studentMembershipManifest()))
            ->orWhereIn('group_id', $ownedGroupIds)
            ->delete();
        ParentStudentRelationship::query()
            ->whereIn('id', array_keys($this->relationshipManifest()))
            ->orWhere(function ($query): void {
                $query
                    ->where('parent_id', self::TARGET_FLOW_PARENT_ID)
                    ->where('student_id', self::TARGET_FLOW_STUDENT_ID);
            })
            ->delete();
        Group::query()->whereIn('id', $ownedGroupIds)->delete();

        DB::table('personal_access_tokens')
            ->where('tokenable_type', User::class)
            ->whereIn('tokenable_id', array_keys($this->userManifest()))
            ->delete();
        InstitutionSetting::query()
            ->whereIn('institution_id', array_keys($this->institutionManifest()))
            ->delete();
        User::query()->whereIn('id', array_keys($this->userManifest()))->delete();
        Institution::query()->whereIn('id', array_keys($this->institutionManifest()))->delete();
    }

    /**
     * @return array<string, Institution>
     */
    private function createInstitutions(): array
    {
        $createdAt = Carbon::parse('2032-04-01 08:00:00+00');
        $institutions = [];
        foreach ($this->institutionManifest() as $id => $specification) {
            $key = $id === self::TARGET_INSTITUTION_ID ? 'target' : 'foreign';
            $institutions[$key] = Institution::factory()->create([
                'id' => $id,
                'name' => $specification['name'],
                'type' => $specification['type'],
                'status' => InstitutionStatus::Active,
                'contact_email' => "e2e_s04_$key@e2e-s04.invalid",
                'contact_phone' => $key === 'target' ? '+998904000101' : '+998904000102',
                'address' => "E2E S04 deterministic $key address",
                'description' => "E2E S04 deterministic $key Institution.",
                'created_by_user_id' => null,
                'deactivated_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }

        return $institutions;
    }

    /**
     * @param  array<string, Institution>  $institutions
     * @return array<string, User>
     */
    private function createUsers(array $institutions, string $password): array
    {
        $createdAt = Carbon::parse('2032-04-02 08:00:00+00');
        $users = [];
        foreach ($this->userManifest() as $id => $specification) {
            $institutionKey = $specification['institution_id'] === self::TARGET_INSTITUTION_ID ? 'target' : 'foreign';
            $institution = $institutions[$institutionKey];
            $role = UserRole::from($specification['role']);
            $factory = match ($role) {
                UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
                UserRole::Teacher => User::factory()->teacher($institution),
                UserRole::Student => User::factory()->student($institution),
                UserRole::Parent => User::factory()->parent($institution),
                UserRole::PlatformOwner => throw new RuntimeException('Stage 4 users must be Institution-scoped.'),
            };
            $active = $specification['active'];
            $user = $factory->withPassword($password)->create([
                'id' => $id,
                'full_name' => $specification['full_name'],
                'login_name' => $specification['login_name'],
                'email' => $specification['login_name'].'@e2e-s04.invalid',
                'phone' => '+998904'.substr(str_replace('-', '', $id), -6),
                'is_active' => $active,
                'must_change_password' => false,
                'last_login_at' => null,
                'deactivated_at' => $active ? null : $createdAt->copy()->addMinute(),
                'created_by_user_id' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $users[$specification['key']] = $user;
            $createdAt = $createdAt->copy()->addMinute();
        }

        return $users;
    }

    /**
     * @param  array<string, Institution>  $institutions
     */
    private function createSettings(array $institutions): void
    {
        $createdAt = Carbon::parse('2032-04-02 10:00:00+00');
        foreach ($institutions as $institution) {
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
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    /**
     * @param  array<string, Institution>  $institutions
     * @param  array<string, User>  $users
     * @return array<string, Group>
     */
    private function createGroups(array $institutions, array $users): array
    {
        $createdAt = Carbon::parse('2032-04-03 08:00:00+00');
        $groups = [];
        foreach ($this->groupManifest() as $id => $specification) {
            $archived = $specification['status'] === GroupStatus::Archived->value;
            $institutionKey = $specification['institution_id'] === self::TARGET_INSTITUTION_ID ? 'target' : 'foreign';
            $actorKey = $institutionKey.'_admin';
            $groups[$specification['key']] = Group::factory()->create([
                'id' => $id,
                'institution_id' => $institutions[$institutionKey]->id,
                'name' => $specification['name'],
                'level' => $archived ? 'Archived level' : 'Foundation',
                'subject_direction' => $institutionKey === 'target' ? 'Mathematics' : 'Physics',
                'description' => 'E2E S04 deterministic '.$specification['key'].' Group.',
                'status' => GroupStatus::from($specification['status']),
                'created_by_user_id' => $users[$actorKey]->id,
                'archived_at' => $archived ? $createdAt->copy()->addHour() : null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }

        return $groups;
    }

    /**
     * @param  array<string, Institution>  $institutions
     * @param  array<string, User>  $users
     * @param  array<string, Group>  $groups
     */
    private function createMemberships(array $institutions, array $users, array $groups): void
    {
        $startedAt = Carbon::parse('2032-04-04 08:00:00+00');
        GroupTeacherMembership::factory()->create([
            'id' => self::TARGET_TEACHER_MEMBERSHIP_ID,
            'institution_id' => $institutions['target']->id,
            'group_id' => $groups['target_active']->id,
            'teacher_id' => $users['target_active_teacher']->id,
            'assigned_by_user_id' => $users['target_admin']->id,
            'started_at' => $startedAt,
            'created_at' => $startedAt,
            'updated_at' => $startedAt,
        ]);
        GroupStudentMembership::factory()->create([
            'id' => self::TARGET_STUDENT_MEMBERSHIP_ID,
            'institution_id' => $institutions['target']->id,
            'group_id' => $groups['target_active']->id,
            'student_id' => $users['target_active_student']->id,
            'assigned_by_user_id' => $users['target_admin']->id,
            'started_at' => $startedAt->copy()->addMinute(),
            'created_at' => $startedAt->copy()->addMinute(),
            'updated_at' => $startedAt->copy()->addMinute(),
        ]);
        GroupTeacherMembership::factory()->create([
            'id' => self::FOREIGN_TEACHER_MEMBERSHIP_ID,
            'institution_id' => $institutions['foreign']->id,
            'group_id' => $groups['foreign_active']->id,
            'teacher_id' => $users['foreign_active_teacher']->id,
            'assigned_by_user_id' => $users['foreign_admin']->id,
            'started_at' => $startedAt->copy()->addMinutes(2),
            'created_at' => $startedAt->copy()->addMinutes(2),
            'updated_at' => $startedAt->copy()->addMinutes(2),
        ]);
        GroupStudentMembership::factory()->create([
            'id' => self::FOREIGN_STUDENT_MEMBERSHIP_ID,
            'institution_id' => $institutions['foreign']->id,
            'group_id' => $groups['foreign_active']->id,
            'student_id' => $users['foreign_active_student']->id,
            'assigned_by_user_id' => $users['foreign_admin']->id,
            'started_at' => $startedAt->copy()->addMinutes(3),
            'created_at' => $startedAt->copy()->addMinutes(3),
            'updated_at' => $startedAt->copy()->addMinutes(3),
        ]);
    }

    /**
     * @param  array<string, Institution>  $institutions
     * @param  array<string, User>  $users
     */
    private function createRelationships(array $institutions, array $users): void
    {
        $startedAt = Carbon::parse('2032-04-05 08:00:00+00');
        ParentStudentRelationship::factory()->create([
            'id' => self::TARGET_RELATIONSHIP_ID,
            'institution_id' => $institutions['target']->id,
            'parent_id' => $users['target_active_parent']->id,
            'student_id' => $users['target_active_student']->id,
            'connected_by_user_id' => $users['target_admin']->id,
            'started_at' => $startedAt,
            'created_at' => $startedAt,
            'updated_at' => $startedAt,
        ]);
        ParentStudentRelationship::factory()->create([
            'id' => self::FOREIGN_RELATIONSHIP_ID,
            'institution_id' => $institutions['foreign']->id,
            'parent_id' => $users['foreign_active_parent']->id,
            'student_id' => $users['foreign_active_student']->id,
            'connected_by_user_id' => $users['foreign_admin']->id,
            'started_at' => $startedAt->copy()->addMinute(),
            'created_at' => $startedAt->copy()->addMinute(),
            'updated_at' => $startedAt->copy()->addMinute(),
        ]);
    }

    /**
     * @return array<string, array{name: string, type: string}>
     */
    private function institutionManifest(): array
    {
        return [
            self::TARGET_INSTITUTION_ID => [
                'name' => 'E2E S04 Target Institution',
                'type' => InstitutionType::School->value,
            ],
            self::FOREIGN_INSTITUTION_ID => [
                'name' => 'E2E S04 Foreign Institution',
                'type' => InstitutionType::University->value,
            ],
        ];
    }

    /**
     * @return array<string, array{key: string, login_name: string, full_name: string, role: string, institution_id: string, active: bool}>
     */
    private function userManifest(): array
    {
        return [
            self::TARGET_ADMIN_ID => $this->userSpecification('target_admin', 'e2e_s04_target_admin', 'E2E S04 Target Admin', UserRole::InstitutionAdmin, self::TARGET_INSTITUTION_ID),
            self::FOREIGN_ADMIN_ID => $this->userSpecification('foreign_admin', 'e2e_s04_foreign_admin', 'E2E S04 Foreign Admin', UserRole::InstitutionAdmin, self::FOREIGN_INSTITUTION_ID),
            self::TARGET_ACTIVE_TEACHER_ID => $this->userSpecification('target_active_teacher', 'e2e_s04_target_teacher', 'E2E S04 Target Teacher', UserRole::Teacher, self::TARGET_INSTITUTION_ID),
            self::TARGET_INACTIVE_TEACHER_ID => $this->userSpecification('target_inactive_teacher', 'e2e_s04_target_inactive_teacher', 'E2E S04 Target Inactive Teacher', UserRole::Teacher, self::TARGET_INSTITUTION_ID, false),
            self::TARGET_ACTIVE_STUDENT_ID => $this->userSpecification('target_active_student', 'e2e_s04_target_student', 'E2E S04 Target Student', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::TARGET_INACTIVE_STUDENT_ID => $this->userSpecification('target_inactive_student', 'e2e_s04_target_inactive_student', 'E2E S04 Target Inactive Student', UserRole::Student, self::TARGET_INSTITUTION_ID, false),
            self::TARGET_FLOW_STUDENT_ID => $this->userSpecification('target_flow_student', 'e2e_s04_flow_student', 'E2E S04 Flow Student', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::TARGET_ACTIVE_PARENT_ID => $this->userSpecification('target_active_parent', 'e2e_s04_target_parent', 'E2E S04 Target Parent', UserRole::Parent, self::TARGET_INSTITUTION_ID),
            self::TARGET_INACTIVE_PARENT_ID => $this->userSpecification('target_inactive_parent', 'e2e_s04_target_inactive_parent', 'E2E S04 Target Inactive Parent', UserRole::Parent, self::TARGET_INSTITUTION_ID, false),
            self::TARGET_FLOW_PARENT_ID => $this->userSpecification('target_flow_parent', 'e2e_s04_flow_parent', 'E2E S04 Flow Parent', UserRole::Parent, self::TARGET_INSTITUTION_ID),
            self::FOREIGN_ACTIVE_TEACHER_ID => $this->userSpecification('foreign_active_teacher', 'e2e_s04_foreign_teacher', 'E2E S04 Foreign Teacher', UserRole::Teacher, self::FOREIGN_INSTITUTION_ID),
            self::FOREIGN_ACTIVE_STUDENT_ID => $this->userSpecification('foreign_active_student', 'e2e_s04_foreign_student', 'E2E S04 Foreign Student', UserRole::Student, self::FOREIGN_INSTITUTION_ID),
            self::FOREIGN_ACTIVE_PARENT_ID => $this->userSpecification('foreign_active_parent', 'e2e_s04_foreign_parent', 'E2E S04 Foreign Parent', UserRole::Parent, self::FOREIGN_INSTITUTION_ID),
        ];
    }

    /**
     * @return array{key: string, login_name: string, full_name: string, role: string, institution_id: string, active: bool}
     */
    private function userSpecification(string $key, string $loginName, string $fullName, UserRole $role, string $institutionId, bool $active = true): array
    {
        return [
            'key' => $key,
            'login_name' => $loginName,
            'full_name' => $fullName,
            'role' => $role->value,
            'institution_id' => $institutionId,
            'active' => $active,
        ];
    }

    /**
     * @return array<string, array{key: string, name: string, institution_id: string, created_by_user_id: string, status: string}>
     */
    private function groupManifest(): array
    {
        return [
            self::TARGET_ACTIVE_GROUP_ID => [
                'key' => 'target_active',
                'name' => 'E2E S04 Target Active Group',
                'institution_id' => self::TARGET_INSTITUTION_ID,
                'created_by_user_id' => self::TARGET_ADMIN_ID,
                'status' => GroupStatus::Active->value,
            ],
            self::TARGET_ARCHIVED_GROUP_ID => [
                'key' => 'target_archived',
                'name' => 'E2E S04 Target Archived Group',
                'institution_id' => self::TARGET_INSTITUTION_ID,
                'created_by_user_id' => self::TARGET_ADMIN_ID,
                'status' => GroupStatus::Archived->value,
            ],
            self::FOREIGN_ACTIVE_GROUP_ID => [
                'key' => 'foreign_active',
                'name' => 'E2E S04 Foreign Active Group',
                'institution_id' => self::FOREIGN_INSTITUTION_ID,
                'created_by_user_id' => self::FOREIGN_ADMIN_ID,
                'status' => GroupStatus::Active->value,
            ],
        ];
    }

    /**
     * @return array<string, array{institution_id: string, group_id: string, member_id: string, actor_id: string}>
     */
    private function teacherMembershipManifest(): array
    {
        return [
            self::TARGET_TEACHER_MEMBERSHIP_ID => [
                'institution_id' => self::TARGET_INSTITUTION_ID,
                'group_id' => self::TARGET_ACTIVE_GROUP_ID,
                'member_id' => self::TARGET_ACTIVE_TEACHER_ID,
                'actor_id' => self::TARGET_ADMIN_ID,
            ],
            self::FOREIGN_TEACHER_MEMBERSHIP_ID => [
                'institution_id' => self::FOREIGN_INSTITUTION_ID,
                'group_id' => self::FOREIGN_ACTIVE_GROUP_ID,
                'member_id' => self::FOREIGN_ACTIVE_TEACHER_ID,
                'actor_id' => self::FOREIGN_ADMIN_ID,
            ],
        ];
    }

    /**
     * @return array<string, array{institution_id: string, group_id: string, member_id: string, actor_id: string}>
     */
    private function studentMembershipManifest(): array
    {
        return [
            self::TARGET_STUDENT_MEMBERSHIP_ID => [
                'institution_id' => self::TARGET_INSTITUTION_ID,
                'group_id' => self::TARGET_ACTIVE_GROUP_ID,
                'member_id' => self::TARGET_ACTIVE_STUDENT_ID,
                'actor_id' => self::TARGET_ADMIN_ID,
            ],
            self::FOREIGN_STUDENT_MEMBERSHIP_ID => [
                'institution_id' => self::FOREIGN_INSTITUTION_ID,
                'group_id' => self::FOREIGN_ACTIVE_GROUP_ID,
                'member_id' => self::FOREIGN_ACTIVE_STUDENT_ID,
                'actor_id' => self::FOREIGN_ADMIN_ID,
            ],
        ];
    }

    /**
     * @return array<string, array{institution_id: string, parent_id: string, student_id: string, actor_id: string}>
     */
    private function relationshipManifest(): array
    {
        return [
            self::TARGET_RELATIONSHIP_ID => [
                'institution_id' => self::TARGET_INSTITUTION_ID,
                'parent_id' => self::TARGET_ACTIVE_PARENT_ID,
                'student_id' => self::TARGET_ACTIVE_STUDENT_ID,
                'actor_id' => self::TARGET_ADMIN_ID,
            ],
            self::FOREIGN_RELATIONSHIP_ID => [
                'institution_id' => self::FOREIGN_INSTITUTION_ID,
                'parent_id' => self::FOREIGN_ACTIVE_PARENT_ID,
                'student_id' => self::FOREIGN_ACTIVE_STUDENT_ID,
                'actor_id' => self::FOREIGN_ADMIN_ID,
            ],
        ];
    }
}
