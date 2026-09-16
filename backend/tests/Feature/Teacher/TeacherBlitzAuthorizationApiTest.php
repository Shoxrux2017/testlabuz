<?php

namespace Tests\Feature\Teacher;

use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\TestCase;

class TeacherBlitzAuthorizationApiTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(now()->setDate(2026, 9, 16)->setTime(8, 0));
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        parent::tearDown();
    }

    public function test_all_six_routes_require_authentication_and_teacher_role(): void
    {
        [$institution, $teacher, $admin, , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        foreach ($this->blitzRoutes($topic->id, $assessment->id) as [$method, $uri, $payload]) {
            $this->json($method, $uri, $payload ?? [])->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
            foreach ([$admin, $student] as $nonTeacher) {
                $response = $payload === null
                    ? $this->blitzRaw($nonTeacher, $method, $uri)
                    : $this->blitzJson($nonTeacher, $method, $uri, $payload);
                $response->assertForbidden()->assertJsonPath('code', 'forbidden');
            }
        }
    }

    public function test_list_excludes_homework_foreign_other_teacher_and_formerly_assigned_blitz(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $visible = $this->persistedBlitz($institution, $teacher, $topic);
        Assessment::factory()->homework()->create(['institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id]);
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $this->persistedBlitz($institution, $otherTeacher, $topic);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->blitzContext();
        $this->persistedBlitz($foreignInstitution, $foreignTeacher, $foreignTopic);
        $formerGroup = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id, 'group_id' => $formerGroup->id, 'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id, 'started_at' => now()->subDay(), 'ended_at' => now(),
        ]);
        $formerTopic = Topic::factory()->create(['institution_id' => $institution->id, 'group_id' => $formerGroup->id, 'teacher_id' => $teacher->id]);
        $this->persistedBlitz($institution, $teacher, $formerTopic);
        $otherTeacherTopic = Topic::factory()->create(['institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $otherTeacher->id]);
        $this->persistedBlitz($institution, $teacher, $otherTeacherTopic);
        Assessment::factory()->blitz()->create(['institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id]);

        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $visible->id)->assertJsonPath('meta.pagination.total', 1);
    }

    public function test_direct_id_probes_and_foreign_or_other_teacher_mutations_share_privacy_safe_not_found(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $other = $this->persistedBlitz($institution, $otherTeacher, $topic);
        $homework = Assessment::factory()->homework()->create(['institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id]);
        $missingTask = Assessment::factory()->blitz()->create(['institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id]);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->blitzContext();
        $foreign = $this->persistedBlitz($foreignInstitution, $foreignTeacher, $foreignTopic);
        $expected = null;
        foreach (['bad-id', '00000000-0000-0000-0000-000000000099', $other->id, $homework->id, $missingTask->id, $foreign->id] as $id) {
            foreach (array_slice($this->blitzRoutes($topic->id, $id), 2) as [$method, $uri, $payload]) {
                $response = $payload === null ? $this->blitzRaw($teacher, $method, $uri) : $this->blitzJson($teacher, $method, $uri, $payload);
                $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
                $expected ??= $response->json();
                $this->assertSame($expected, $response->json());
            }
        }
    }

    public function test_create_and_filters_hide_malformed_foreign_other_teacher_and_unassigned_topics_and_groups(): void
    {
        [$institution, $teacher, $admin, $group] = $this->blitzContext();
        [, , , $foreignGroup, $foreignTopic] = $this->blitzContext();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $otherTopic = Topic::factory()->create(['institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $otherTeacher->id]);
        $unassignedGroup = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        $unassignedTopic = Topic::factory()->create(['institution_id' => $institution->id, 'group_id' => $unassignedGroup->id, 'teacher_id' => $teacher->id]);
        foreach (['bad-id', '00000000-0000-0000-0000-000000000099', $foreignTopic->id, $otherTopic->id, $unassignedTopic->id] as $id) {
            $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$id}/blitz", $this->validBlitzPayload())
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: ['topic_id' => $id])
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        foreach (['bad-id', '00000000-0000-0000-0000-000000000099', $foreignGroup->id, $unassignedGroup->id] as $id) {
            $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: ['group_id' => $id])
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->assertDatabaseCount('assessments', 0);
    }

    public function test_ended_teacher_membership_removes_list_create_detail_update_schedule_and_archive_access(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        GroupTeacherMembership::query()->where('teacher_id', $teacher->id)->where('group_id', $group->id)->update(['ended_at' => now()]);
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz')->assertOk()->assertJsonPath('data', []);
        foreach (array_slice($this->blitzRoutes($topic->id, $assessment->id), 1) as [$method, $uri, $payload]) {
            $response = $payload === null ? $this->blitzRaw($teacher, $method, $uri) : $this->blitzJson($teacher, $method, $uri, $payload);
            $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        foreach ([['group_id' => $group->id], ['topic_id' => $topic->id]] as $filter) {
            $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: $filter)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_historical_topics_remain_readable_but_closed_and_archived_topics_reject_create_patch_and_schedule(): void
    {
        foreach ([TopicStatus::Draft, TopicStatus::Active] as $status) {
            [, $teacher, , , $topic] = $this->blitzContext($status);
            $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload())->assertCreated();
        }
        foreach ([TopicStatus::Closed, TopicStatus::Archived] as $status) {
            [$institution, $teacher, , , $topic] = $this->blitzContext($status);
            $assessment = $this->persistedBlitz($institution, $teacher, $topic);
            $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: ['topic_id' => $topic->id])->assertOk()->assertJsonPath('data.0.id', $assessment->id);
            $this->blitzRaw($teacher, 'GET', "/api/v1/teacher/blitz/{$assessment->id}")->assertOk();
            foreach ([['POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload()],
                ['PATCH', "/api/v1/teacher/blitz/{$assessment->id}", ['title' => 'Forbidden']],
                ['POST', "/api/v1/teacher/blitz/{$assessment->id}/schedule", ['scheduled_at' => '2026-09-17T14:00:00+05:00']]] as [$method, $uri, $payload]) {
                $this->blitzJson($teacher, $method, $uri, $payload)->assertConflict()->assertJsonPath('code', 'topic_not_editable');
            }
            $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/archive")->assertOk()->assertJsonPath('data.status', 'archived');
        }
    }

    public function test_selected_student_ineligibility_is_private_and_create_or_update_rolls_back_the_entire_set(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $eligible = $this->eligibleBlitzStudent($institution, $admin, $group);
        $inactive = $this->eligibleBlitzStudent($institution, $admin, $group, ['is_active' => false]);
        $former = $this->eligibleBlitzStudent($institution, $admin, $group);
        GroupStudentMembership::query()->where('student_id', $former->id)->update(['ended_at' => now()]);
        $nonMember = User::factory()->student($institution)->create();
        [$foreignInstitution] = $this->blitzContext();
        $foreign = User::factory()->student($foreignInstitution)->create();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $expectedErrors = null;
        foreach (['00000000-0000-0000-0000-000000000099', $inactive->id, $former->id, $nonMember->id, $foreign->id, $teacher->id] as $id) {
            $assignment = ['assignment_mode' => 'selected_students', 'student_ids' => [$eligible->id, $id]];
            foreach ([['POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload($assignment)],
                ['PATCH', "/api/v1/teacher/blitz/{$assessment->id}", $assignment]] as [$method, $uri, $payload]) {
                $response = $this->blitzJson($teacher, $method, $uri, $payload)->assertUnprocessable()
                    ->assertJsonPath('code', 'validation_failed')->assertJsonStructure(['errors' => ['student_ids']]);
                $expectedErrors ??= $response->json('errors');
                $this->assertSame($expectedErrors, $response->json('errors'));
                $this->assertCount(1, $response->json('errors.student_ids'));
                $this->assertStringNotContainsString($id, $response->getContent());
            }
        }
        $this->assertDatabaseCount('assessments', 1);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseHas('assessments', ['id' => $assessment->id, 'assignment_mode' => 'group']);
    }

    /** @return list<array{string, string, ?array}> */
    private function blitzRoutes(string $topicId, string $assessmentId): array
    {
        return [
            ['GET', '/api/v1/teacher/blitz', null],
            ['POST', "/api/v1/teacher/topics/{$topicId}/blitz", $this->validBlitzPayload()],
            ['GET', "/api/v1/teacher/blitz/{$assessmentId}", null],
            ['PATCH', "/api/v1/teacher/blitz/{$assessmentId}", ['title' => 'Updated']],
            ['POST', "/api/v1/teacher/blitz/{$assessmentId}/schedule", ['scheduled_at' => '2026-09-17T14:00:00+05:00']],
            ['POST', "/api/v1/teacher/blitz/{$assessmentId}/archive", null],
        ];
    }
}
