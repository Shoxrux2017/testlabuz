<?php

namespace Tests\Feature\Teacher;

use App\Models\Assessment;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Teacher\Concerns\BuildsTeacherQuestionMutationContext;
use Tests\TestCase;

class TeacherQuestionMutationAuthorizationTest extends TestCase
{
    use BuildsTeacherQuestionMutationContext;
    use RefreshDatabase;

    public function test_all_question_mutation_routes_require_the_teacher_middleware_chain(): void
    {
        $assessmentId = '00000000-0000-0000-0000-000000000001';
        $questionId = '00000000-0000-0000-0000-000000000002';

        foreach ([
            ['POST', "/api/v1/teacher/assessments/{$assessmentId}/questions", $this->questionPayload()],
            ['PATCH', "/api/v1/teacher/questions/{$questionId}", ['prompt' => 'Updated']],
            ['DELETE', "/api/v1/teacher/questions/{$questionId}", null],
            ['POST', "/api/v1/teacher/assessments/{$assessmentId}/questions/reorder", ['question_ids' => []]],
        ] as [$method, $uri, $payload]) {
            $response = $payload === null
                ? $this->json($method, $uri)
                : $this->json($method, $uri, $payload);
            $response->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        }
    }

    public function test_assessment_routes_hide_malformed_foreign_other_teacher_non_homework_and_lost_membership(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $visible = $this->persistedHomework($institution, $teacher, $topic);
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
        $otherTeacherHomework = $this->persistedHomework($institution, $otherTeacher, $otherTeacherTopic);
        $blitz = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->homeworkContext();
        $foreignHomework = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);

        foreach (['bad-id', $foreignHomework->id, $otherTeacherHomework->id, $blitz->id] as $hiddenAssessment) {
            $this->assertAssessmentMutationNotFound($teacher, $hiddenAssessment);
        }

        GroupTeacherMembership::query()
            ->where('group_id', $group->id)
            ->where('teacher_id', $teacher->id)
            ->update(['ended_at' => now()]);
        $this->assertAssessmentMutationNotFound($teacher, $visible->id);
        $this->assertDatabaseCount('questions', 0);
    }

    public function test_question_routes_resolve_only_through_teacher_scoped_homework(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $visibleHomework = $this->persistedHomework($institution, $teacher, $topic);
        $visibleQuestion = $this->persistedQuestion($visibleHomework);
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
        $otherHomework = $this->persistedHomework($institution, $otherTeacher, $otherTeacherTopic);
        $otherQuestion = $this->persistedQuestion($otherHomework);
        $blitz = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);
        $blitzQuestion = app(QuestionConfigurationWriter::class)->create($blitz, $this->questionPayload());
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->homeworkContext();
        $foreignHomework = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);
        $foreignQuestion = $this->persistedQuestion($foreignHomework);

        foreach (['bad-id', $otherQuestion->id, $blitzQuestion->id, $foreignQuestion->id] as $hiddenQuestion) {
            $this->assertQuestionMutationNotFound($teacher, $hiddenQuestion);
        }

        GroupTeacherMembership::query()
            ->where('group_id', $group->id)
            ->where('teacher_id', $teacher->id)
            ->update(['ended_at' => now()]);
        $this->assertQuestionMutationNotFound($teacher, $visibleQuestion->id);
        $this->assertDatabaseHas('questions', ['id' => $visibleQuestion->id, 'prompt' => 'Is this statement true?']);
    }

    public function test_wrong_role_cannot_use_question_mutations(): void
    {
        [$institution, , $admin, , $topic] = $this->homeworkContext();
        $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $homework = $this->persistedHomework($institution, $teacher, $topic);

        $this->homeworkJson(
            $admin,
            'POST',
            "/api/v1/teacher/assessments/{$homework->id}/questions",
            $this->questionPayload(),
        )->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->assertDatabaseCount('questions', 0);
    }

    private function assertAssessmentMutationNotFound(User $teacher, string $assessmentId): void
    {
        foreach ([
            ["/api/v1/teacher/assessments/{$assessmentId}/questions", $this->questionPayload()],
            ["/api/v1/teacher/assessments/{$assessmentId}/questions/reorder", ['question_ids' => []]],
        ] as [$uri, $payload]) {
            $this->homeworkJson($teacher, 'POST', $uri, $payload)
                ->assertNotFound()
                ->assertExactJson([
                    'message' => 'The requested resource was not found.',
                    'code' => 'resource_not_found',
                    'errors' => [],
                ]);
        }
    }

    private function assertQuestionMutationNotFound(User $teacher, string $questionId): void
    {
        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$questionId}", ['prompt' => 'Hidden'])
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
        $this->homeworkRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$questionId}", '')
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
    }
}
