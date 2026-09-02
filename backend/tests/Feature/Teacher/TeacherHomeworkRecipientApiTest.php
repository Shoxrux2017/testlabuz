<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\HomeworkStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\Institution;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class TeacherHomeworkRecipientApiTest extends TestCase
{
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    public function test_roster_returns_only_current_active_students_with_literal_search_and_standard_pagination(): void
    {
        [$institution, $teacher, $admin, $group] = $this->homeworkContext();
        $matching = $this->eligibleStudent($institution, $admin, $group, [
            'full_name' => 'Alpha_Student',
            'login_name' => 'alpha_01',
        ]);
        $this->eligibleStudent($institution, $admin, $group, ['full_name' => 'Beta Student']);
        $inactive = $this->eligibleStudent($institution, $admin, $group, ['is_active' => false]);
        $former = $this->eligibleStudent($institution, $admin, $group);
        GroupStudentMembership::query()->where('student_id', $former->id)->update(['ended_at' => now()]);

        $response = $this->homeworkRaw(
            $teacher,
            'GET',
            "/api/v1/teacher/groups/{$group->id}/students",
            '',
            ['search' => 'Alpha_', 'per_page' => 1],
        );

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $matching->id)
            ->assertJsonPath('meta.pagination.page', 1)
            ->assertJsonPath('meta.pagination.per_page', 1)
            ->assertJsonPath('meta.pagination.total', 1);
        $this->assertSame(['id', 'full_name', 'login_name'], array_keys($response->json('data.0')));
        $this->assertStringNotContainsString($inactive->id, $response->getContent());
        $this->assertStringNotContainsString($former->id, $response->getContent());

        $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/groups/{$group->id}/students", '', ['unknown' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_selected_create_uses_set_semantics_and_rejects_every_ineligible_id_privately(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $first = $this->eligibleStudent($institution, $admin, $group);
        $second = $this->eligibleStudent($institution, $admin, $group);
        $uri = "/api/v1/teacher/topics/{$topic->id}/homework";

        $response = $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload([
            'assignment_mode' => 'selected_students',
            'student_ids' => [$second->id, $first->id],
        ]));

        $response->assertCreated();
        $expectedIds = [$first->id, $second->id];
        sort($expectedIds, SORT_STRING);
        $this->assertSame($expectedIds, $response->json('data.student_ids'));
        $assessmentId = $response->json('data.id');

        foreach ($expectedIds as $studentId) {
            $this->assertDatabaseHas('assessment_students', [
                'assessment_id' => $assessmentId,
                'student_id' => $studentId,
                'assignment_source' => 'direct',
                'assigned_by_user_id' => $teacher->id,
            ]);
        }

        $foreignInstitution = Institution::factory()->create();
        $foreignStudent = User::factory()->student($foreignInstitution)->create();
        $inactive = $this->eligibleStudent($institution, $admin, $group, ['is_active' => false]);
        $otherGroup = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
        $otherMember = $this->eligibleStudent($institution, $admin, $otherGroup);

        foreach (['00000000-0000-0000-0000-000000000099', $foreignStudent->id, $inactive->id, $otherMember->id] as $invalidId) {
            $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload([
                'title' => 'Invalid recipient',
                'assignment_mode' => 'selected_students',
                'student_ids' => [$invalidId],
            ]))->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->assertSame(1, Assessment::query()->count());
    }

    public function test_draft_group_to_selected_transition_persists_the_exact_current_eligible_direct_set(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $retained = $this->eligibleStudent($institution, $admin, $group);
        $removed = $this->eligibleStudent($institution, $admin, $group);
        $added = $this->eligibleStudent($institution, $admin, $group);
        $assessment = $this->persistedHomework($institution, $teacher, $topic);
        CarbonImmutable::setTestNow('2026-09-02 08:00:00 UTC');

        try {
            $retainedRecipient = AssessmentStudent::factory()->create([
                'institution_id' => $institution->id,
                'assessment_id' => $assessment->id,
                'student_id' => $retained->id,
                'assignment_source' => AssessmentAssignmentSource::Group,
                'assigned_by_user_id' => $teacher->id,
            ]);
            AssessmentStudent::factory()->create([
                'institution_id' => $institution->id,
                'assessment_id' => $assessment->id,
                'student_id' => $removed->id,
                'assignment_source' => AssessmentAssignmentSource::Group,
                'assigned_by_user_id' => $teacher->id,
            ]);

            CarbonImmutable::setTestNow('2026-09-02 09:00:00 UTC');
            $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", [
                'assignment_mode' => 'selected_students',
                'student_ids' => [$added->id, $retained->id],
            ]);

            $expectedStudentIds = [$added->id, $retained->id];
            sort($expectedStudentIds, SORT_STRING);
            $response->assertOk()
                ->assertJsonPath('data.assignment_mode', 'selected_students')
                ->assertJsonPath('data.student_ids', $expectedStudentIds);

            $this->assertEqualsCanonicalizing($expectedStudentIds, AssessmentStudent::query()
                ->where('assessment_id', $assessment->id)
                ->pluck('student_id')
                ->all());
            $this->assertDatabaseMissing('assessment_students', [
                'assessment_id' => $assessment->id,
                'student_id' => $removed->id,
            ]);
            $this->assertDatabaseMissing('assessment_students', [
                'assessment_id' => $assessment->id,
                'assignment_source' => AssessmentAssignmentSource::Group->value,
            ]);

            $retainedAfter = AssessmentStudent::query()
                ->where('assessment_id', $assessment->id)
                ->where('student_id', $retained->id)
                ->firstOrFail();
            $this->assertSame($retainedRecipient->id, $retainedAfter->id);
            $this->assertSame($retainedRecipient->assigned_at->toJSON(), $retainedAfter->assigned_at->toJSON());
            $this->assertDatabaseHas('assessment_students', [
                'assessment_id' => $assessment->id,
                'student_id' => $added->id,
                'assignment_source' => AssessmentAssignmentSource::Direct->value,
                'assigned_by_user_id' => $teacher->id,
            ]);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_draft_recipient_updates_are_delta_based_and_exact_no_op_preserves_all_timestamps(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $first = $this->eligibleStudent($institution, $admin, $group);
        $unchanged = $this->eligibleStudent($institution, $admin, $group);
        $added = $this->eligibleStudent($institution, $admin, $group);
        CarbonImmutable::setTestNow('2026-09-02 08:00:00 UTC');

        try {
            $created = $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload([
                'assignment_mode' => 'selected_students',
                'student_ids' => [$first->id, $unchanged->id],
            ]));
            $created->assertCreated();
            $assessmentId = $created->json('data.id');
            $assessmentBefore = Assessment::query()->findOrFail($assessmentId);
            $homeworkBefore = $assessmentBefore->homeworkAssignment;
            $unchangedBefore = AssessmentStudent::query()
                ->where('assessment_id', $assessmentId)
                ->where('student_id', $unchanged->id)
                ->firstOrFail();

            CarbonImmutable::setTestNow('2026-09-02 09:00:00 UTC');
            $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessmentId}", [
                'title' => 'Homework 1',
                'assignment_mode' => 'selected_students',
                'student_ids' => [$unchanged->id, $first->id],
                'deadline_at' => null,
            ])->assertOk()->assertJsonPath('data.updated_at', '2026-09-02T08:00:00Z');

            $this->assertSame($assessmentBefore->updated_at->toJSON(), $assessmentBefore->fresh()?->updated_at->toJSON());
            $this->assertSame($homeworkBefore->updated_at->toJSON(), $homeworkBefore->fresh()?->updated_at->toJSON());
            $this->assertSame($unchangedBefore->assigned_at->toJSON(), $unchangedBefore->fresh()?->assigned_at->toJSON());
            $this->assertSame($unchangedBefore->updated_at->toJSON(), $unchangedBefore->fresh()?->updated_at->toJSON());

            CarbonImmutable::setTestNow('2026-09-02 10:00:00 UTC');
            $updated = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessmentId}", [
                'student_ids' => [$added->id, $unchanged->id],
            ]);
            $updated->assertOk();
            $this->assertDatabaseMissing('assessment_students', ['assessment_id' => $assessmentId, 'student_id' => $first->id]);
            $this->assertDatabaseHas('assessment_students', ['assessment_id' => $assessmentId, 'student_id' => $added->id]);
            $this->assertSame($unchangedBefore->id, AssessmentStudent::query()
                ->where('assessment_id', $assessmentId)->where('student_id', $unchanged->id)->value('id'));
            $this->assertSame($unchangedBefore->assigned_at->toJSON(), $unchangedBefore->fresh()?->assigned_at->toJSON());

            $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessmentId}", [
                'assignment_mode' => 'group',
                'student_ids' => [],
            ])->assertOk()->assertJsonPath('data.student_ids', []);
            $this->assertDatabaseMissing('assessment_students', ['assessment_id' => $assessmentId]);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_active_before_activity_synchronizes_group_snapshot_and_activity_locks_only_fairness_fields(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $first = $this->eligibleStudent($institution, $admin, $group);
        $second = $this->eligibleStudent($institution, $admin, $group);
        $inactive = $this->eligibleStudent($institution, $admin, $group, ['is_active' => false]);
        $assessment = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            AssessmentAssignmentMode::Group,
            HomeworkStatus::Active,
        );

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", [
            'deadline_at' => '2026-09-10T18:00:00+05:00',
        ])->assertOk()->assertJsonPath('data.deadline_at', '2026-09-10T13:00:00Z');

        $this->assertEqualsCanonicalizing([$first->id, $second->id], AssessmentStudent::query()
            ->where('assessment_id', $assessment->id)->pluck('student_id')->all());
        $this->assertDatabaseMissing('assessment_students', ['assessment_id' => $assessment->id, 'student_id' => $inactive->id]);
        $this->assertDatabaseMissing('assessment_students', ['assessment_id' => $assessment->id, 'assignment_source' => 'direct']);

        $recipient = AssessmentStudent::query()->where('assessment_id', $assessment->id)->firstOrFail();
        AssessmentAttempt::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'assessment_student_id' => $recipient->id,
            'student_id' => $recipient->student_id,
            'possible_points' => $assessment->total_possible_points,
        ]);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", [
            'deadline_at' => null,
        ])->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", [
            'student_instructions' => $assessment->student_instructions,
            'assignment_mode' => 'group',
            'student_ids' => [],
            'deadline_at' => '2026-09-10T18:00:00+05:00',
            'title' => 'Safe title',
            'description' => 'Safe description',
        ])->assertOk()->assertJsonPath('data.title', 'Safe title');
    }

    public function test_patch_rejects_question_mutation_invalid_assignment_shapes_and_closed_archived_tasks(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $draft = $this->persistedHomework($institution, $teacher, $topic);
        $closed = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Closed);
        $archived = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Archived);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$draft->id}", ['questions' => []])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$draft->id}", ['student_ids' => ['00000000-0000-0000-0000-000000000001']])
            ->assertUnprocessable();
        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$closed->id}", ['title' => 'No'])
            ->assertConflict()->assertJsonPath('code', 'task_closed');
        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$archived->id}", ['title' => 'No'])
            ->assertConflict()->assertJsonPath('code', 'task_archived');
    }
}
