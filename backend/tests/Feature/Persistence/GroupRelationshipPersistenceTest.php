<?php

namespace Tests\Feature\Persistence;

use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class GroupRelationshipPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_valid_groups_and_relationships_persist_while_group_names_remain_non_unique(): void
    {
        $firstInstitution = Institution::factory()->create();
        $secondInstitution = Institution::factory()->create();
        $firstAdmin = User::factory()->institutionAdmin($firstInstitution)->create();
        $secondAdmin = User::factory()->institutionAdmin($secondInstitution)->create();

        $group = Group::factory()->create([
            'institution_id' => $firstInstitution,
            'created_by_user_id' => $firstAdmin,
            'name' => 'Repeated Group Name',
        ]);
        Group::factory()->create([
            'institution_id' => $firstInstitution,
            'created_by_user_id' => $firstAdmin,
            'name' => 'Repeated Group Name',
        ]);
        Group::factory()->create([
            'institution_id' => $secondInstitution,
            'created_by_user_id' => $secondAdmin,
            'name' => 'Repeated Group Name',
        ]);

        $teacherMembership = GroupTeacherMembership::factory()->create([
            'institution_id' => $firstInstitution,
            'group_id' => $group,
        ]);
        $studentMembership = GroupStudentMembership::factory()->create([
            'institution_id' => $firstInstitution,
            'group_id' => $group,
        ]);
        $parentRelationship = ParentStudentRelationship::factory()->create([
            'institution_id' => $firstInstitution,
        ]);

        $this->assertDatabaseCount('groups', 3);
        $this->assertDatabaseHas('group_teacher_memberships', ['id' => $teacherMembership->id]);
        $this->assertDatabaseHas('group_student_memberships', ['id' => $studentMembership->id]);
        $this->assertDatabaseHas('parent_student_relationships', ['id' => $parentRelationship->id]);
    }

    public function test_group_checks_reject_blank_names_invalid_statuses_and_inconsistent_archive_state(): void
    {
        $institution = Institution::factory()->create();
        $creator = User::factory()->institutionAdmin($institution)->create();
        $validAttributes = [
            'institution_id' => $institution,
            'created_by_user_id' => $creator,
        ];
        $validGroup = Group::factory()->create($validAttributes);

        $this->assertDatabaseRejects(fn () => Group::factory()->create($validAttributes + ['name' => '   ']));
        $this->assertDatabaseRejects(fn () => DB::table('groups')
            ->where('id', $validGroup->id)
            ->update(['status' => 'disabled']));
        $this->assertDatabaseRejects(fn () => Group::factory()->create($validAttributes + [
            'status' => GroupStatus::Active,
            'archived_at' => now(),
        ]));
        $this->assertDatabaseRejects(fn () => Group::factory()->create($validAttributes + [
            'status' => GroupStatus::Archived,
            'archived_at' => null,
        ]));
    }

    public function test_postgresql_rejects_every_cross_institution_group_and_relationship_reference(): void
    {
        $firstInstitution = Institution::factory()->create();
        $secondInstitution = Institution::factory()->create();
        $firstAdmin = User::factory()->institutionAdmin($firstInstitution)->create();
        $secondAdmin = User::factory()->institutionAdmin($secondInstitution)->create();
        $firstGroup = Group::factory()->create([
            'institution_id' => $firstInstitution,
            'created_by_user_id' => $firstAdmin,
        ]);
        $secondGroup = Group::factory()->create([
            'institution_id' => $secondInstitution,
            'created_by_user_id' => $secondAdmin,
        ]);
        $firstTeacher = User::factory()->teacher($firstInstitution)->create();
        $secondTeacher = User::factory()->teacher($secondInstitution)->create();
        $firstStudent = User::factory()->student($firstInstitution)->create();
        $secondStudent = User::factory()->student($secondInstitution)->create();
        $firstParent = User::factory()->parent($firstInstitution)->create();
        $secondParent = User::factory()->parent($secondInstitution)->create();

        $this->assertDatabaseRejects(fn () => Group::factory()->create([
            'institution_id' => $firstInstitution,
            'created_by_user_id' => $secondAdmin,
        ]));

        $teacherAttributes = [
            'institution_id' => $firstInstitution,
            'group_id' => $firstGroup,
            'teacher_id' => $firstTeacher,
            'assigned_by_user_id' => $firstAdmin,
        ];
        $this->assertCrossTenantReferenceRejected(
            GroupTeacherMembership::factory(),
            $teacherAttributes,
            'group_id',
            $secondGroup,
        );
        $this->assertCrossTenantReferenceRejected(
            GroupTeacherMembership::factory(),
            $teacherAttributes,
            'teacher_id',
            $secondTeacher,
        );
        $this->assertCrossTenantReferenceRejected(
            GroupTeacherMembership::factory(),
            $teacherAttributes,
            'assigned_by_user_id',
            $secondAdmin,
        );

        $studentAttributes = [
            'institution_id' => $firstInstitution,
            'group_id' => $firstGroup,
            'student_id' => $firstStudent,
            'assigned_by_user_id' => $firstAdmin,
        ];
        $this->assertCrossTenantReferenceRejected(
            GroupStudentMembership::factory(),
            $studentAttributes,
            'group_id',
            $secondGroup,
        );
        $this->assertCrossTenantReferenceRejected(
            GroupStudentMembership::factory(),
            $studentAttributes,
            'student_id',
            $secondStudent,
        );
        $this->assertCrossTenantReferenceRejected(
            GroupStudentMembership::factory(),
            $studentAttributes,
            'assigned_by_user_id',
            $secondAdmin,
        );

        $parentAttributes = [
            'institution_id' => $firstInstitution,
            'parent_id' => $firstParent,
            'student_id' => $firstStudent,
            'connected_by_user_id' => $firstAdmin,
        ];
        $this->assertCrossTenantReferenceRejected(
            ParentStudentRelationship::factory(),
            $parentAttributes,
            'parent_id',
            $secondParent,
        );
        $this->assertCrossTenantReferenceRejected(
            ParentStudentRelationship::factory(),
            $parentAttributes,
            'student_id',
            $secondStudent,
        );
        $this->assertCrossTenantReferenceRejected(
            ParentStudentRelationship::factory(),
            $parentAttributes,
            'connected_by_user_id',
            $secondAdmin,
        );
    }

    public function test_historical_relationships_allow_ended_rows_and_only_one_current_pair(): void
    {
        $institution = Institution::factory()->create();
        $assigner = User::factory()->institutionAdmin($institution)->create();
        $group = Group::factory()->create([
            'institution_id' => $institution,
            'created_by_user_id' => $assigner,
        ]);

        $this->assertRelationshipHistory(
            GroupTeacherMembership::class,
            [
                'institution_id' => $institution,
                'group_id' => $group,
                'teacher_id' => User::factory()->teacher($institution)->create(),
                'assigned_by_user_id' => $assigner,
            ],
            ['group_id', 'teacher_id'],
        );
        $this->assertRelationshipHistory(
            GroupStudentMembership::class,
            [
                'institution_id' => $institution,
                'group_id' => $group,
                'student_id' => User::factory()->student($institution)->create(),
                'assigned_by_user_id' => $assigner,
            ],
            ['group_id', 'student_id'],
        );
        $this->assertRelationshipHistory(
            ParentStudentRelationship::class,
            [
                'institution_id' => $institution,
                'parent_id' => User::factory()->parent($institution)->create(),
                'student_id' => User::factory()->student($institution)->create(),
                'connected_by_user_id' => $assigner,
            ],
            ['parent_id', 'student_id'],
        );
    }

    public function test_relationship_time_checks_reject_an_end_before_the_start(): void
    {
        $institution = Institution::factory()->create();

        foreach ([
            GroupTeacherMembership::factory(),
            GroupStudentMembership::factory(),
            ParentStudentRelationship::factory(),
        ] as $factory) {
            $this->assertDatabaseRejects(fn () => $factory->create([
                'institution_id' => $institution,
                'started_at' => now(),
                'ended_at' => now()->subMinute(),
            ]));
        }
    }

    public function test_restrictive_foreign_keys_preserve_historical_relationship_references(): void
    {
        $institution = Institution::factory()->create();
        $actor = User::factory()->institutionAdmin($institution)->create();
        $group = Group::factory()->create([
            'institution_id' => $institution,
            'created_by_user_id' => $actor,
        ]);
        $teacher = User::factory()->teacher($institution)->create();
        $groupStudent = User::factory()->student($institution)->create();
        $parent = User::factory()->parent($institution)->create();
        $child = User::factory()->student($institution)->create();

        GroupTeacherMembership::factory()->ended()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'teacher_id' => $teacher,
            'assigned_by_user_id' => $actor,
        ]);
        GroupStudentMembership::factory()->ended()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'student_id' => $groupStudent,
            'assigned_by_user_id' => $actor,
        ]);
        ParentStudentRelationship::factory()->ended()->create([
            'institution_id' => $institution,
            'parent_id' => $parent,
            'student_id' => $child,
            'connected_by_user_id' => $actor,
        ]);

        foreach ([$group, $teacher, $groupStudent, $parent, $child, $actor, $institution] as $referencedModel) {
            $this->assertDatabaseRejects(fn () => $referencedModel->delete());
        }
    }

    /**
     * @param  Factory<*>  $factory
     * @param  array<string, mixed>  $validAttributes
     */
    private function assertCrossTenantReferenceRejected(
        Factory $factory,
        array $validAttributes,
        string $foreignKey,
        mixed $crossTenantModel,
    ): void {
        $this->assertDatabaseRejects(
            fn () => $factory->create(array_merge($validAttributes, [$foreignKey => $crossTenantModel])),
        );
    }

    /**
     * @param  class-string<GroupTeacherMembership|GroupStudentMembership|ParentStudentRelationship>  $modelClass
     * @param  array<string, mixed>  $attributes
     * @param  list<string>  $pairColumns
     */
    private function assertRelationshipHistory(string $modelClass, array $attributes, array $pairColumns): void
    {
        $startedAt = now()->subDays(10);
        $current = $modelClass::factory()->create($attributes + [
            'started_at' => $startedAt,
            'ended_at' => null,
        ]);

        $this->assertDatabaseRejects(fn () => $modelClass::factory()->create($attributes + [
            'started_at' => $startedAt->copy()->addDay(),
            'ended_at' => null,
        ]));

        $current->update(['ended_at' => $startedAt->copy()->addDay()]);

        $modelClass::factory()->create($attributes + [
            'started_at' => $startedAt->copy()->addDays(2),
            'ended_at' => null,
        ]);
        $modelClass::factory()->create($attributes + [
            'started_at' => $startedAt->copy()->subDays(4),
            'ended_at' => $startedAt->copy()->subDays(3),
        ]);
        $modelClass::factory()->create($attributes + [
            'started_at' => $startedAt->copy()->subDays(2),
            'ended_at' => $startedAt->copy()->subDay(),
        ]);

        $pair = collect($pairColumns)
            ->mapWithKeys(fn (string $column) => [
                $column => $attributes[$column] instanceof Model
                    ? $attributes[$column]->getKey()
                    : $attributes[$column],
            ])
            ->all();

        $this->assertSame(1, $modelClass::current()->where($pair)->count());
        $this->assertSame(3, $modelClass::query()->where($pair)->whereNotNull('ended_at')->count());
    }
}
