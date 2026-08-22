<?php

namespace Tests\Feature\Seeders;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Database\Seeders\Stage4E2eSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;
use Tests\TestCase;

class Stage4E2eSeederTest extends TestCase
{
    use RefreshDatabase;

    private const TARGET_INSTITUTION_ID = '04000000-0000-4000-8000-000000000101';

    private const FOREIGN_INSTITUTION_ID = '04000000-0000-4000-8000-000000000102';

    private const TARGET_ADMIN_ID = '04000000-0000-4000-9000-000000000101';

    private const FOREIGN_ADMIN_ID = '04000000-0000-4000-9000-000000000102';

    private const TARGET_ACTIVE_TEACHER_ID = '04000000-0000-4000-9000-000000000201';

    private const TARGET_FLOW_STUDENT_ID = '04000000-0000-4000-9000-000000000205';

    private const TARGET_FLOW_PARENT_ID = '04000000-0000-4000-9000-000000000208';

    private const TARGET_ACTIVE_GROUP_ID = '04000000-0000-4000-a000-000000000101';

    public function test_stage_4_e2e_seeder_refuses_unsafe_runtime_facts_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Preserved runtime guard Institution']);
        $this->setPassword();

        $unsafeSeeders = [
            new class extends Stage4E2eSeeder
            {
                protected function runtimeEnvironment(): string
                {
                    return 'local';
                }
            },
            new class extends Stage4E2eSeeder
            {
                protected function connectionDriver(): string
                {
                    return 'sqlite';
                }
            },
            new class extends Stage4E2eSeeder
            {
                protected function pdoDriver(): string
                {
                    return 'mysql';
                }
            },
            new class extends Stage4E2eSeeder
            {
                protected function currentDatabase(): string
                {
                    return 'testlabuz';
                }
            },
        ];

        foreach ($unsafeSeeders as $seeder) {
            try {
                $seeder->run();
                self::fail('The Stage 4 E2E seeder accepted unsafe runtime facts.');
            } catch (RuntimeException) {
                $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
                $this->assertSame(0, Institution::query()->whereIn('id', $this->institutionIds())->count());
            }
        }
    }

    public function test_stage_4_e2e_seeder_requires_the_transient_password(): void
    {
        $this->clearPassword();

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('STAGE4_E2E_PASSWORD must be provided');

        $this->seed(Stage4E2eSeeder::class);
    }

    public function test_stage_4_e2e_seeder_creates_the_exact_world_and_preserves_unrelated_rows_byte_for_byte(): void
    {
        $unrelatedIds = $this->createUnrelatedRelationshipWorld();
        $before = $this->snapshotUnrelatedRows($unrelatedIds);
        $this->setPassword();

        $this->seed(Stage4E2eSeeder::class);

        $this->assertSame($before, $this->snapshotUnrelatedRows($unrelatedIds));
        $this->assertSame(2, Institution::query()->whereIn('id', $this->institutionIds())->count());
        $this->assertSame(13, User::query()->whereIn('id', $this->userIds())->count());
        $this->assertSame(2, InstitutionSetting::query()->whereIn('institution_id', $this->institutionIds())->count());
        $this->assertSame(3, Group::query()->whereIn('id', $this->groupIds())->count());
        $this->assertSame(2, GroupTeacherMembership::query()->whereIn('institution_id', $this->institutionIds())->count());
        $this->assertSame(2, GroupStudentMembership::query()->whereIn('institution_id', $this->institutionIds())->count());
        $this->assertSame(2, ParentStudentRelationship::query()->whereIn('institution_id', $this->institutionIds())->count());

        $this->assertDatabaseHas('users', [
            'id' => self::TARGET_ADMIN_ID,
            'login_name' => 'e2e_s04_target_admin',
            'role' => UserRole::InstitutionAdmin->value,
            'is_active' => true,
            'must_change_password' => false,
        ]);
        $this->assertDatabaseHas('institution_settings', [
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'timezone' => 'Asia/Tashkent',
            'learning_material_max_mb' => 25,
            'student_submission_max_mb' => 15,
            'updated_by_user_id' => null,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_s04_target_inactive_teacher',
            'role' => UserRole::Teacher->value,
            'is_active' => false,
        ]);
        $this->assertDatabaseHas('groups', [
            'id' => '04000000-0000-4000-a000-000000000102',
            'status' => GroupStatus::Archived->value,
        ]);
        $this->assertDatabaseHas('group_teacher_memberships', [
            'id' => '04000000-0000-4000-b000-000000000101',
            'group_id' => self::TARGET_ACTIVE_GROUP_ID,
            'teacher_id' => self::TARGET_ACTIVE_TEACHER_ID,
            'ended_at' => null,
        ]);
        $this->assertDatabaseHas('parent_student_relationships', [
            'id' => '04000000-0000-4000-c000-000000000102',
            'institution_id' => self::FOREIGN_INSTITUTION_ID,
            'ended_at' => null,
        ]);
        $this->assertDatabaseMissing('parent_student_relationships', [
            'parent_id' => self::TARGET_FLOW_PARENT_ID,
            'student_id' => self::TARGET_FLOW_STUDENT_ID,
        ]);
    }

    public function test_stage_4_e2e_seeder_is_repeatable_and_removes_only_manifest_owned_ui_history(): void
    {
        $this->setPassword();
        $this->seed(Stage4E2eSeeder::class);

        $target = Institution::query()->findOrFail(self::TARGET_INSTITUTION_ID);
        $admin = User::query()->findOrFail(self::TARGET_ADMIN_ID);
        $uiGroup = Group::factory()->create([
            'institution_id' => $target->id,
            'name' => 'E2E S04 UI Group Edited',
            'created_by_user_id' => $admin->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $target->id,
            'group_id' => $uiGroup->id,
            'teacher_id' => self::TARGET_ACTIVE_TEACHER_ID,
            'assigned_by_user_id' => $admin->id,
        ]);
        GroupStudentMembership::factory()->create([
            'institution_id' => $target->id,
            'group_id' => $uiGroup->id,
            'student_id' => self::TARGET_FLOW_STUDENT_ID,
            'assigned_by_user_id' => $admin->id,
        ]);
        $endedAt = Carbon::parse('2032-04-06 08:00:00+00');
        ParentStudentRelationship::factory()->ended()->create([
            'institution_id' => $target->id,
            'parent_id' => self::TARGET_FLOW_PARENT_ID,
            'student_id' => self::TARGET_FLOW_STUDENT_ID,
            'connected_by_user_id' => $admin->id,
            'ended_at' => $endedAt,
        ]);
        ParentStudentRelationship::factory()->create([
            'institution_id' => $target->id,
            'parent_id' => self::TARGET_FLOW_PARENT_ID,
            'student_id' => self::TARGET_FLOW_STUDENT_ID,
            'connected_by_user_id' => $admin->id,
            'started_at' => $endedAt->copy()->addMinute(),
        ]);
        $unrelated = Institution::factory()->create(['name' => 'Preserved across Stage 4 reseed']);

        $this->seed(Stage4E2eSeeder::class);

        $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
        $this->assertDatabaseMissing('groups', ['id' => $uiGroup->id]);
        $this->assertDatabaseMissing('parent_student_relationships', [
            'parent_id' => self::TARGET_FLOW_PARENT_ID,
            'student_id' => self::TARGET_FLOW_STUDENT_ID,
        ]);
        $this->assertSame(3, Group::query()->whereIn('id', $this->groupIds())->count());
        $this->assertSame(2, GroupTeacherMembership::query()->whereIn('institution_id', $this->institutionIds())->count());
        $this->assertSame(2, GroupStudentMembership::query()->whereIn('institution_id', $this->institutionIds())->count());
        $this->assertSame(2, ParentStudentRelationship::query()->whereIn('institution_id', $this->institutionIds())->count());
    }

    public function test_stage_4_e2e_seeder_refuses_cross_tenant_reserved_group_ownership_before_mutation(): void
    {
        $this->setPassword();
        $this->seed(Stage4E2eSeeder::class);
        $foreign = Institution::query()->findOrFail(self::FOREIGN_INSTITUTION_ID);
        $foreignAdmin = User::query()->findOrFail(self::FOREIGN_ADMIN_ID);
        $collision = Group::factory()->create([
            'institution_id' => $foreign->id,
            'name' => 'E2E S04 UI Group',
            'created_by_user_id' => $foreignAdmin->id,
        ]);

        try {
            $this->seed(Stage4E2eSeeder::class);
            self::fail('The Stage 4 E2E seeder accepted a cross-tenant reserved Group.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('reserved UI Group collision', $exception->getMessage());
        }

        $this->assertDatabaseHas('groups', ['id' => $collision->id]);
        $this->assertDatabaseHas('groups', ['id' => self::TARGET_ACTIVE_GROUP_ID]);
    }

    public function test_stage_4_e2e_seeder_refuses_unmanifested_relationships_using_reserved_users(): void
    {
        $this->setPassword();
        $this->seed(Stage4E2eSeeder::class);
        $collision = ParentStudentRelationship::factory()->create([
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'parent_id' => self::TARGET_FLOW_PARENT_ID,
            'student_id' => '04000000-0000-4000-9000-000000000203',
            'connected_by_user_id' => self::TARGET_ADMIN_ID,
        ]);

        try {
            $this->seed(Stage4E2eSeeder::class);
            self::fail('The Stage 4 E2E seeder accepted an unmanifested reserved relationship.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('relationship manifest collision', $exception->getMessage());
        }

        $this->assertDatabaseHas('parent_student_relationships', ['id' => $collision->id]);
        $this->assertDatabaseHas('groups', ['id' => self::TARGET_ACTIVE_GROUP_ID]);
    }

    protected function tearDown(): void
    {
        $this->clearPassword();
        parent::tearDown();
    }

    /**
     * @return array{institution: string, users: list<string>, group: string, teacher_membership: string, student_membership: string, relationship: string}
     */
    private function createUnrelatedRelationshipWorld(): array
    {
        $institution = Institution::factory()->create(['name' => 'Manual unrelated Stage 4 Institution']);
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $admin = User::factory()->institutionAdmin($institution)->create();
        $teacher = User::factory()->teacher($institution)->create();
        $student = User::factory()->student($institution)->create();
        $parent = User::factory()->parent($institution)->create();
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
        $teacherMembership = GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $studentMembership = GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $relationship = ParentStudentRelationship::factory()->create([
            'institution_id' => $institution->id,
            'parent_id' => $parent->id,
            'student_id' => $student->id,
            'connected_by_user_id' => $admin->id,
        ]);

        return [
            'institution' => $institution->id,
            'users' => [$admin->id, $teacher->id, $student->id, $parent->id],
            'group' => $group->id,
            'teacher_membership' => $teacherMembership->id,
            'student_membership' => $studentMembership->id,
            'relationship' => $relationship->id,
        ];
    }

    /**
     * @param  array{institution: string, users: list<string>, group: string, teacher_membership: string, student_membership: string, relationship: string}  $ids
     */
    private function snapshotUnrelatedRows(array $ids): string
    {
        return json_encode([
            'institution' => DB::table('institutions')->where('id', $ids['institution'])->first(),
            'institution_setting' => DB::table('institution_settings')->where('institution_id', $ids['institution'])->first(),
            'users' => DB::table('users')->whereIn('id', $ids['users'])->orderBy('id')->get()->all(),
            'group' => DB::table('groups')->where('id', $ids['group'])->first(),
            'teacher_membership' => DB::table('group_teacher_memberships')->where('id', $ids['teacher_membership'])->first(),
            'student_membership' => DB::table('group_student_memberships')->where('id', $ids['student_membership'])->first(),
            'relationship' => DB::table('parent_student_relationships')->where('id', $ids['relationship'])->first(),
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
    }

    private function setPassword(): void
    {
        $password = 'Stage4-'.Str::random(32).'Aa1!';
        putenv('STAGE4_E2E_PASSWORD='.$password);
        $_ENV['STAGE4_E2E_PASSWORD'] = $password;
        $_SERVER['STAGE4_E2E_PASSWORD'] = $password;
    }

    private function clearPassword(): void
    {
        putenv('STAGE4_E2E_PASSWORD');
        unset($_ENV['STAGE4_E2E_PASSWORD'], $_SERVER['STAGE4_E2E_PASSWORD']);
    }

    /** @return list<string> */
    private function institutionIds(): array
    {
        return [self::TARGET_INSTITUTION_ID, self::FOREIGN_INSTITUTION_ID];
    }

    /** @return list<string> */
    private function userIds(): array
    {
        return [
            self::TARGET_ADMIN_ID,
            self::FOREIGN_ADMIN_ID,
            self::TARGET_ACTIVE_TEACHER_ID,
            '04000000-0000-4000-9000-000000000202',
            '04000000-0000-4000-9000-000000000203',
            '04000000-0000-4000-9000-000000000204',
            self::TARGET_FLOW_STUDENT_ID,
            '04000000-0000-4000-9000-000000000206',
            '04000000-0000-4000-9000-000000000207',
            self::TARGET_FLOW_PARENT_ID,
            '04000000-0000-4000-9000-000000000301',
            '04000000-0000-4000-9000-000000000302',
            '04000000-0000-4000-9000-000000000303',
        ];
    }

    /** @return list<string> */
    private function groupIds(): array
    {
        return [
            self::TARGET_ACTIVE_GROUP_ID,
            '04000000-0000-4000-a000-000000000102',
            '04000000-0000-4000-a000-000000000103',
        ];
    }
}
