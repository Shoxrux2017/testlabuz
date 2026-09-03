<?php

namespace Tests\Feature\Teacher;

use App\Enums\GroupStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Models\Assessment;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\Question;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class TeacherHomeworkLifecycleAuthorizationTest extends TestCase
{
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    public function test_lifecycle_routes_enforce_authentication_account_institution_password_and_role_gates(): void
    {
        $homeworkId = '00000000-0000-0000-0000-000000000099';

        foreach (['activate', 'close', 'archive'] as $operation) {
            $uri = $this->uri($homeworkId, $operation);
            $this->postJson($uri)
                ->assertUnauthorized()
                ->assertJsonPath('code', 'authentication_required');
        }

        $institution = Institution::factory()->create();
        $inactiveTeacher = User::factory()->teacher($institution)->create([
            'is_active' => false,
            'must_change_password' => false,
        ]);
        $this->requestAs($inactiveTeacher, $this->uri($homeworkId, 'activate'))
            ->assertForbidden()->assertJsonPath('code', 'user_inactive');

        $passwordTeacher = User::factory()->teacher($institution)->create(['must_change_password' => true]);
        $this->requestAs($passwordTeacher, $this->uri($homeworkId, 'activate'))
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $institutionTeacher = User::factory()->teacher($inactiveInstitution)->create(['must_change_password' => false]);
        $this->requestAs($institutionTeacher, $this->uri($homeworkId, 'activate'))
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::InstitutionAdmin, UserRole::Student, UserRole::Parent] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
            $this->requestAs($actor, $this->uri($homeworkId, 'activate'))
                ->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
    }

    public function test_lifecycle_resolution_is_privacy_safe_for_every_inaccessible_identifier(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $otherTeacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $otherTopic = Topic::factory()->active()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $otherTeacher->id,
        ]);
        $otherHomework = $this->persistedHomework($institution, $otherTeacher, $otherTopic);

        $foreignInstitution = Institution::factory()->create();
        $foreignTeacher = User::factory()->teacher($foreignInstitution)->create(['must_change_password' => false]);
        $foreignAdmin = User::factory()->institutionAdmin($foreignInstitution)->create(['must_change_password' => false]);
        $foreignGroup = Group::factory()->create([
            'institution_id' => $foreignInstitution->id,
            'created_by_user_id' => $foreignAdmin->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $foreignInstitution->id,
            'group_id' => $foreignGroup->id,
            'teacher_id' => $foreignTeacher->id,
            'assigned_by_user_id' => $foreignAdmin->id,
        ]);
        $foreignTopic = Topic::factory()->active()->create([
            'institution_id' => $foreignInstitution->id,
            'group_id' => $foreignGroup->id,
            'teacher_id' => $foreignTeacher->id,
        ]);
        $foreignHomework = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);

        $blitz = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'teacher_id' => $teacher->id,
        ]);
        $lostMembershipHomework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Archived);
        GroupTeacherMembership::query()
            ->where('group_id', $group->id)
            ->where('teacher_id', $teacher->id)
            ->update(['ended_at' => now()]);

        foreach (['activate', 'close', 'archive'] as $operation) {
            foreach ([
                'not-a-uuid',
                '00000000-0000-0000-0000-000000000098',
                $otherHomework->id,
                $foreignHomework->id,
                $blitz->id,
                $lostMembershipHomework->id,
            ] as $homeworkId) {
                $response = $this->requestAs($teacher, $this->uri($homeworkId, $operation));
                $this->assertSame([
                    'message' => 'The requested resource was not found.',
                    'code' => 'resource_not_found',
                    'errors' => [],
                ], $response->assertNotFound()->json());
            }
        }
    }

    public function test_close_and_archive_do_not_invent_group_or_topic_status_restrictions(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->homeworkContext(TopicStatus::Closed);
        $group->forceFill(['status' => GroupStatus::Archived, 'archived_at' => now()])->save();
        $active = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $this->scoreableQuestion($active);

        $this->requestAs($teacher, $this->uri($active->id, 'close'))
            ->assertOk()->assertJsonPath('data.status', 'closed');

        $topic->forceFill(['status' => TopicStatus::Archived, 'archived_at' => now()])->save();
        $draft = $this->persistedHomework($institution, $teacher, $topic);
        $this->scoreableQuestion($draft);
        $this->requestAs($teacher, $this->uri($draft->id, 'archive'))
            ->assertOk()->assertJsonPath('data.status', 'archived');
    }

    private function scoreableQuestion(Assessment $assessment): void
    {
        Question::factory()->openWritten()->create([
            'institution_id' => $assessment->institution_id,
            'assessment_id' => $assessment->id,
        ]);
    }

    private function uri(string $homeworkId, string $operation): string
    {
        return '/api/v1/teacher/homework/'.$homeworkId.'/'.$operation;
    }

    private function requestAs(User $actor, string $uri): TestResponse
    {
        return $this->homeworkRaw($actor, 'POST', $uri, '');
    }
}
