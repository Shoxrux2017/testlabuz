<?php

namespace Tests\Feature\Persistence;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class GroupRelationshipFactoryModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_models_cast_uuid_lifecycle_fields_and_expose_required_relationships(): void
    {
        $institution = Institution::factory()->create();
        $creator = User::factory()->institutionAdmin($institution)->create();
        $teacher = User::factory()->teacher($institution)->create();
        $groupStudent = User::factory()->student($institution)->create();
        $parent = User::factory()->parent($institution)->create();
        $child = User::factory()->student($institution)->create();
        $group = Group::factory()->archived()->create([
            'institution_id' => $institution,
            'created_by_user_id' => $creator,
        ]);
        $teacherMembership = GroupTeacherMembership::factory()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'teacher_id' => $teacher,
            'assigned_by_user_id' => $creator,
        ]);
        $studentMembership = GroupStudentMembership::factory()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'student_id' => $groupStudent,
            'assigned_by_user_id' => $creator,
        ]);
        $parentRelationship = ParentStudentRelationship::factory()->create([
            'institution_id' => $institution,
            'parent_id' => $parent,
            'student_id' => $child,
            'connected_by_user_id' => $creator,
        ]);

        foreach ([$group, $teacherMembership, $studentMembership, $parentRelationship] as $model) {
            $this->assertTrue(Str::isUuid($model->id));
        }

        $this->assertSame(GroupStatus::Archived, $group->status);
        $this->assertInstanceOf(CarbonInterface::class, $group->archived_at);
        foreach ([$teacherMembership, $studentMembership, $parentRelationship] as $relationship) {
            $this->assertInstanceOf(CarbonInterface::class, $relationship->started_at);
            $this->assertNull($relationship->ended_at);
        }

        $this->assertTrue($institution->is($group->institution));
        $this->assertTrue($creator->is($group->creator));
        $this->assertTrue($institution->groups->contains($group));

        $this->assertTrue($institution->is($teacherMembership->institution));
        $this->assertTrue($group->is($teacherMembership->group));
        $this->assertTrue($teacher->is($teacherMembership->teacher));
        $this->assertTrue($creator->is($teacherMembership->assigner));
        $this->assertTrue($group->teacherMemberships->contains($teacherMembership));
        $this->assertTrue($teacher->teacherGroupMemberships->contains($teacherMembership));

        $this->assertTrue($institution->is($studentMembership->institution));
        $this->assertTrue($group->is($studentMembership->group));
        $this->assertTrue($groupStudent->is($studentMembership->student));
        $this->assertTrue($creator->is($studentMembership->assigner));
        $this->assertTrue($group->studentMemberships->contains($studentMembership));
        $this->assertTrue($groupStudent->studentGroupMemberships->contains($studentMembership));

        $this->assertTrue($institution->is($parentRelationship->institution));
        $this->assertTrue($parent->is($parentRelationship->parent));
        $this->assertTrue($child->is($parentRelationship->student));
        $this->assertTrue($creator->is($parentRelationship->connector));
        $this->assertTrue($parent->parentStudentRelationships->contains($parentRelationship));
        $this->assertTrue($child->studentParentRelationships->contains($parentRelationship));
    }

    public function test_current_scopes_exclude_ended_relationships(): void
    {
        $currentTeacher = GroupTeacherMembership::factory()->create();
        $endedTeacher = GroupTeacherMembership::factory()->ended()->create();
        $currentStudent = GroupStudentMembership::factory()->create();
        $endedStudent = GroupStudentMembership::factory()->ended()->create();
        $currentParent = ParentStudentRelationship::factory()->create();
        $endedParent = ParentStudentRelationship::factory()->ended()->create();

        $this->assertEqualsCanonicalizing(
            [$currentTeacher->id],
            GroupTeacherMembership::current()->pluck('id')->all(),
        );
        $this->assertNotContains($endedTeacher->id, GroupTeacherMembership::current()->pluck('id')->all());
        $this->assertEqualsCanonicalizing(
            [$currentStudent->id],
            GroupStudentMembership::current()->pluck('id')->all(),
        );
        $this->assertNotContains($endedStudent->id, GroupStudentMembership::current()->pluck('id')->all());
        $this->assertEqualsCanonicalizing(
            [$currentParent->id],
            ParentStudentRelationship::current()->pluck('id')->all(),
        );
        $this->assertNotContains($endedParent->id, ParentStudentRelationship::current()->pluck('id')->all());
    }

    public function test_default_factories_create_role_correct_same_institution_records_and_valid_states(): void
    {
        $group = Group::factory()->create();
        $archivedGroup = Group::factory()->archived()->create();
        $teacherMembership = GroupTeacherMembership::factory()->create();
        $endedTeacherMembership = GroupTeacherMembership::factory()->ended()->create();
        $studentMembership = GroupStudentMembership::factory()->create();
        $endedStudentMembership = GroupStudentMembership::factory()->ended()->create();
        $parentRelationship = ParentStudentRelationship::factory()->create();
        $endedParentRelationship = ParentStudentRelationship::factory()->ended()->create();

        $this->assertSame(GroupStatus::Active, $group->status);
        $this->assertNull($group->archived_at);
        $this->assertSame($group->institution_id, $group->creator->institution_id);
        $this->assertSame(UserRole::InstitutionAdmin, $group->creator->role);
        $this->assertSame(GroupStatus::Archived, $archivedGroup->status);
        $this->assertNotNull($archivedGroup->archived_at);

        $this->assertMembershipFactoryDefaults($teacherMembership, 'teacher', UserRole::Teacher);
        $this->assertMembershipFactoryDefaults($studentMembership, 'student', UserRole::Student);

        $this->assertSame($parentRelationship->institution_id, $parentRelationship->parent->institution_id);
        $this->assertSame($parentRelationship->institution_id, $parentRelationship->student->institution_id);
        $this->assertSame($parentRelationship->institution_id, $parentRelationship->connector->institution_id);
        $this->assertSame(UserRole::Parent, $parentRelationship->parent->role);
        $this->assertSame(UserRole::Student, $parentRelationship->student->role);
        $this->assertSame(UserRole::InstitutionAdmin, $parentRelationship->connector->role);
        $this->assertNull($parentRelationship->ended_at);

        foreach ([$endedTeacherMembership, $endedStudentMembership, $endedParentRelationship] as $endedRelationship) {
            $this->assertNotNull($endedRelationship->ended_at);
            $this->assertTrue($endedRelationship->ended_at->greaterThanOrEqualTo($endedRelationship->started_at));
        }
    }

    public function test_explicit_same_institution_factory_overrides_are_preserved(): void
    {
        $institution = Institution::factory()->create();
        $actor = User::factory()->institutionAdmin($institution)->create();
        $group = Group::factory()->create([
            'institution_id' => $institution,
            'created_by_user_id' => $actor,
            'name' => 'Explicit Group',
        ]);
        $teacher = User::factory()->teacher($institution)->create();
        $student = User::factory()->student($institution)->create();
        $parent = User::factory()->parent($institution)->create();

        $teacherMembership = GroupTeacherMembership::factory()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'teacher_id' => $teacher,
            'assigned_by_user_id' => $actor,
        ]);
        $studentMembership = GroupStudentMembership::factory()->create([
            'institution_id' => $institution,
            'group_id' => $group,
            'student_id' => $student,
            'assigned_by_user_id' => $actor,
        ]);
        $parentRelationship = ParentStudentRelationship::factory()->create([
            'institution_id' => $institution,
            'parent_id' => $parent,
            'student_id' => $student,
            'connected_by_user_id' => $actor,
        ]);

        $this->assertSame($institution->id, $group->institution_id);
        $this->assertSame($actor->id, $group->created_by_user_id);
        $this->assertSame($group->id, $teacherMembership->group_id);
        $this->assertSame($teacher->id, $teacherMembership->teacher_id);
        $this->assertSame($actor->id, $teacherMembership->assigned_by_user_id);
        $this->assertSame($group->id, $studentMembership->group_id);
        $this->assertSame($student->id, $studentMembership->student_id);
        $this->assertSame($actor->id, $studentMembership->assigned_by_user_id);
        $this->assertSame($parent->id, $parentRelationship->parent_id);
        $this->assertSame($student->id, $parentRelationship->student_id);
        $this->assertSame($actor->id, $parentRelationship->connected_by_user_id);
    }

    private function assertMembershipFactoryDefaults(
        GroupTeacherMembership|GroupStudentMembership $membership,
        string $memberRelationship,
        UserRole $expectedRole,
    ): void {
        $member = $membership->{$memberRelationship};

        $this->assertSame($membership->institution_id, $membership->group->institution_id);
        $this->assertSame($membership->institution_id, $member->institution_id);
        $this->assertSame($membership->institution_id, $membership->assigner->institution_id);
        $this->assertSame($expectedRole, $member->role);
        $this->assertSame(UserRole::InstitutionAdmin, $membership->assigner->role);
        $this->assertNull($membership->ended_at);
    }
}
