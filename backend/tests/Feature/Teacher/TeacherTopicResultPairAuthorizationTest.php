<?php

namespace Tests\Feature\Teacher;

use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Teacher\Concerns\BuildsTeacherTopicResultPairContext;
use Tests\TestCase;

class TeacherTopicResultPairAuthorizationTest extends TestCase
{
    use BuildsTeacherTopicResultPairContext;
    use RefreshDatabase;

    public function test_both_endpoints_hide_malformed_foreign_other_teacher_and_lost_membership_topics(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $candidate = $this->persistedHomework($institution, $teacher, $topic);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->homeworkContext();
        $foreignCandidate = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);
        $sameTenantOtherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $sameTenantContext = $this->homeworkContextForTeacher($institution, $sameTenantOtherTeacher);
        $sameTenantOtherTopic = $sameTenantContext['topic'];
        $sameTenantOtherCandidate = $this->persistedHomework(
            $institution,
            $sameTenantOtherTeacher,
            $sameTenantOtherTopic,
        );

        foreach ([
            ['not-a-uuid', $candidate->id],
            [$foreignTopic->id, $foreignCandidate->id],
            [$sameTenantOtherTopic->id, $sameTenantOtherCandidate->id],
        ] as [$topicId, $candidateId]) {
            $uri = "/api/v1/teacher/topics/{$topicId}/result-pair";
            $this->homeworkRaw($teacher, 'GET', $uri, '')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->homeworkJson($teacher, 'PUT', $uri, ['homework_assessment_id' => $candidateId])
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        GroupTeacherMembership::query()
            ->where('group_id', $topic->group_id)
            ->where('teacher_id', $teacher->id)
            ->update(['ended_at' => now()]);
        $uri = "/api/v1/teacher/topics/{$topic->id}/result-pair";
        $this->homeworkRaw($teacher, 'GET', $uri, '')
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->homeworkJson($teacher, 'PUT', $uri, ['homework_assessment_id' => $candidate->id])
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    public function test_candidate_resolution_is_topic_teacher_type_and_tenant_scoped_without_existence_disclosure(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $valid = $this->persistedHomework($institution, $teacher, $topic);
        $otherTopic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $otherTopicCandidate = $this->persistedHomework($institution, $teacher, $otherTopic);
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $otherTeacherCandidate = $this->persistedHomework($institution, $otherTeacher, $topic);
        $blitz = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->homeworkContext();
        $foreignCandidate = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);
        $uri = "/api/v1/teacher/topics/{$topic->id}/result-pair";

        foreach ([$otherTopicCandidate, $otherTeacherCandidate, $blitz, $foreignCandidate] as $candidate) {
            $this->homeworkJson($teacher, 'PUT', $uri, ['homework_assessment_id' => $candidate->id])
                ->assertNotFound()
                ->assertExactJson([
                    'message' => 'The requested resource was not found.',
                    'code' => 'resource_not_found',
                    'errors' => [],
                ]);
        }

        $this->homeworkJson($teacher, 'PUT', $uri, ['homework_assessment_id' => $valid->id])
            ->assertOk();
        $this->assertDatabaseCount('topic_result_pairs', 1);
    }

    public function test_get_allows_every_topic_state_but_put_rejects_closed_and_archived_topics(): void
    {
        foreach (TopicStatus::cases() as $status) {
            [$institution, $teacher, , , $topic] = $this->homeworkContext($status);
            $candidate = $this->persistedHomework($institution, $teacher, $topic);
            $uri = "/api/v1/teacher/topics/{$topic->id}/result-pair";

            $this->homeworkRaw($teacher, 'GET', $uri, '')
                ->assertOk()->assertExactJson(['data' => null]);
            $response = $this->homeworkJson($teacher, 'PUT', $uri, [
                'homework_assessment_id' => $candidate->id,
            ]);

            if (in_array($status, [TopicStatus::Draft, TopicStatus::Active], true)) {
                $response->assertOk();
            } else {
                $response->assertConflict()
                    ->assertJsonPath('code', 'topic_not_editable')
                    ->assertJsonPath('message', 'The topic is not editable.');
            }
        }
    }

    public function test_existing_teacher_middleware_precedes_result_pair_actions(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $candidate = $this->persistedHomework($institution, $teacher, $topic);
        $uri = "/api/v1/teacher/topics/{$topic->id}/result-pair";

        $this->getJson($uri)
            ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $this->putJson($uri, ['homework_assessment_id' => $candidate->id])
            ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');

        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $this->homeworkRaw($student, 'GET', $uri, '')
            ->assertForbidden()->assertJsonPath('code', 'forbidden');

        $teacher->forceFill(['must_change_password' => true])->save();
        $this->homeworkJson($teacher, 'PUT', $uri, ['homework_assessment_id' => $candidate->id])
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');
        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    /** @return array{topic: Topic} */
    private function homeworkContextForTeacher(Institution $institution, User $teacher): array
    {
        $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $topic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);

        return compact('topic');
    }
}
