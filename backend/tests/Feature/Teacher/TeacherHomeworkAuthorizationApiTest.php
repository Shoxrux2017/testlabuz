<?php

namespace Tests\Feature\Teacher;

use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class TeacherHomeworkAuthorizationApiTest extends TestCase
{
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    public function test_all_homework_routes_keep_the_teacher_middleware_chain(): void
    {
        [, , , $group, $topic] = $this->homeworkContext();
        $homeworkId = '00000000-0000-0000-0000-000000000001';

        foreach ([
            ['GET', "/api/v1/teacher/groups/{$group->id}/students", null],
            ['GET', "/api/v1/teacher/topics/{$topic->id}/homework", null],
            ['POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload()],
            ['GET', "/api/v1/teacher/homework/{$homeworkId}", null],
            ['PATCH', "/api/v1/teacher/homework/{$homeworkId}", ['title' => 'Updated']],
        ] as [$method, $uri, $payload]) {
            $response = $payload === null
                ? $this->json($method, $uri)
                : $this->json($method, $uri, $payload);
            $response->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        }
    }

    public function test_roster_hides_malformed_foreign_inactive_unassigned_and_formerly_assigned_groups(): void
    {
        [$institution, $teacher, $admin, $group] = $this->homeworkContext();
        $foreignInstitution = Institution::factory()->create();
        $foreignAdmin = User::factory()->institutionAdmin($foreignInstitution)->create(['must_change_password' => false]);
        $foreignGroup = Group::factory()->create([
            'institution_id' => $foreignInstitution->id,
            'created_by_user_id' => $foreignAdmin->id,
        ]);
        $unassigned = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
        $archived = Group::factory()->archived()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $archived->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        GroupTeacherMembership::query()->where('group_id', $group->id)->update(['ended_at' => now()]);

        foreach (['bad-id', $foreignGroup->id, $unassigned->id, $archived->id, $group->id] as $hiddenGroup) {
            $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/groups/{$hiddenGroup}/students", '')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_topic_status_allows_reads_but_only_draft_and_active_allow_create_and_mutation(): void
    {
        foreach ([TopicStatus::Draft, TopicStatus::Active] as $status) {
            [, $teacher, , , $topic] = $this->homeworkContext($status);
            $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload())
                ->assertCreated();
        }

        foreach ([TopicStatus::Closed, TopicStatus::Archived] as $status) {
            [$institution, $teacher, , , $topic] = $this->homeworkContext($status);
            $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload())
                ->assertConflict()->assertJsonPath('code', 'topic_not_editable');
            $homework = $this->persistedHomework($institution, $teacher, $topic);
            $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/topics/{$topic->id}/homework", '')
                ->assertOk()->assertJsonPath('data.0.id', $homework->id);
            $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/homework/{$homework->id}", '')
                ->assertOk()->assertJsonPath('data.id', $homework->id);
            $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", ['title' => 'No'])
                ->assertConflict()->assertJsonPath('code', 'topic_not_editable');
        }
    }

    public function test_homework_list_hides_foreign_and_other_teacher_topics_with_the_same_not_found_response(): void
    {
        [$institution, $teacher, $admin, $group] = $this->homeworkContext();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $otherTeacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $otherTeacherTopic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $otherTeacher->id,
        ]);
        [, , , , $foreignTopic] = $this->homeworkContext();

        $responses = [];

        foreach ([$foreignTopic->id, $otherTeacherTopic->id] as $hiddenTopicId) {
            $responses[] = $this->homeworkRaw(
                $teacher,
                'GET',
                "/api/v1/teacher/topics/{$hiddenTopicId}/homework",
                '',
            )->assertNotFound()
                ->assertJsonPath('code', 'resource_not_found')
                ->assertJsonPath('message', 'The requested resource was not found.');
        }

        $this->assertSame($responses[0]->getContent(), $responses[1]->getContent());
    }

    public function test_homework_detail_is_privacy_safe_for_foreign_other_teacher_non_homework_and_lost_membership(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $visible = $this->persistedHomework($institution, $teacher, $topic);
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $otherTeacherHomework = $this->persistedHomework($institution, $otherTeacher, $topic);
        $blitz = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);

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
        $foreignTopic = Topic::factory()->create([
            'institution_id' => $foreignInstitution->id,
            'group_id' => $foreignGroup->id,
            'teacher_id' => $foreignTeacher->id,
        ]);
        $foreignHomework = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);

        $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/homework/{$visible->id}", '')
            ->assertOk()->assertJsonPath('data.id', $visible->id);

        foreach (['bad-id', $otherTeacherHomework->id, $blitz->id, $foreignHomework->id] as $hiddenHomework) {
            $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/homework/{$hiddenHomework}", '')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        GroupTeacherMembership::query()
            ->where('group_id', $group->id)
            ->where('teacher_id', $teacher->id)
            ->update(['ended_at' => now()]);
        $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/homework/{$visible->id}", '')
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
    }

    public function test_archived_group_does_not_invent_an_extra_homework_mutation_prohibition(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $group->forceFill(['status' => GroupStatus::Archived, 'archived_at' => now()])->save();

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", ['title' => 'Still editable'])
            ->assertOk()->assertJsonPath('data.title', 'Still editable');
    }
}
