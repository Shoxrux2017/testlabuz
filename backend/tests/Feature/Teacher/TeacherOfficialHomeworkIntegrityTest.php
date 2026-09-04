<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\AssessmentStudent;
use App\Models\GroupStudentMembership;
use App\Models\TopicResultPair;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Teacher\Concerns\BuildsTeacherTopicResultPairContext;
use Tests\TestCase;

class TeacherOfficialHomeworkIntegrityTest extends TestCase
{
    use BuildsTeacherTopicResultPairContext;
    use RefreshDatabase;

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    public function test_designated_draft_activation_snapshots_the_normal_recipients_and_pair_at_one_instant(): void
    {
        CarbonImmutable::setTestNow('2026-09-03 08:00:00 UTC');
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $studentA = $this->eligibleStudent($institution, $admin, $group);
        $studentB = $this->eligibleStudent($institution, $admin, $group);
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $this->persistedQuestion($homework);
        $designatedAt = CarbonImmutable::parse('2026-09-03 08:00:00 UTC');
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
            'designated_at' => $designatedAt,
            'created_at' => $designatedAt,
            'updated_at' => $designatedAt,
        ]);

        CarbonImmutable::setTestNow('2026-09-03 09:00:00 UTC');
        $this->homeworkRaw($teacher, 'POST', "/api/v1/teacher/homework/{$homework->id}/activate", '')
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.activated_at', '2026-09-03T09:00:00Z');

        $pair->refresh();
        $this->assertSame('2026-09-03T08:00:00+00:00', $pair->designated_at->toIso8601String());
        $this->assertSame('2026-09-03T09:00:00+00:00', $pair->cohort_snapshotted_at?->toIso8601String());
        $this->assertSame('2026-09-03T09:00:00+00:00', $pair->updated_at->toIso8601String());
        $this->assertNull($pair->locked_at);
        $this->assertNull($pair->blitz_assessment_id);
        $this->assertSame($homework->id, $pair->homework_assessment_id);
        $this->assertSame($teacher->id, $pair->designated_by_user_id);
        $recipients = AssessmentStudent::query()
            ->where('assessment_id', $homework->id)
            ->orderBy('student_id')
            ->get();
        $this->assertSame(
            collect([$studentA->id, $studentB->id])->sort()->values()->all(),
            $recipients->pluck('student_id')->all(),
        );
        $this->assertTrue($recipients->every(
            fn (AssessmentStudent $recipient): bool => $recipient->assigned_at?->toIso8601String() === '2026-09-03T09:00:00+00:00',
        ));
    }

    public function test_designated_draft_activation_rejects_preexisting_pair_lock_or_cohort_without_partial_writes(): void
    {
        foreach (['locked', 'cohort'] as $scenario) {
            [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
            $this->eligibleStudent($institution, $admin, $group);
            $homework = $this->persistedHomework($institution, $teacher, $topic);
            $this->persistedQuestion($homework);
            $pairAttributes = [
                'designated_at' => now()->subMinutes(2),
                'cohort_snapshotted_at' => now()->subMinute(),
            ];

            if ($scenario === 'locked') {
                $pairAttributes['locked_at'] = now();
            }

            $pair = $this->resultPair($institution, $teacher, $topic, $homework, $pairAttributes);
            $before = [
                $pair->cohort_snapshotted_at?->toJSON(),
                $pair->locked_at?->toJSON(),
                $pair->updated_at->toJSON(),
            ];

            $response = $this->homeworkRaw(
                $teacher,
                'POST',
                "/api/v1/teacher/homework/{$homework->id}/activate",
                '',
            );
            $response->assertConflict()->assertJsonPath(
                'code',
                $scenario === 'locked' ? 'result_pair_locked' : 'business_conflict',
            );
            $this->assertSame(HomeworkStatus::Draft, $homework->homeworkAssignment()->firstOrFail()->status);
            $this->assertDatabaseCount('assessment_students', 0);
            $pair->refresh();
            $this->assertSame($before, [
                $pair->cohort_snapshotted_at?->toJSON(),
                $pair->locked_at?->toJSON(),
                $pair->updated_at->toJSON(),
            ]);
        }
    }

    public function test_official_homework_cannot_semantically_change_from_group_to_selected(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $student = $this->eligibleStudent($institution, $admin, $group);
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $pair = $this->resultPair($institution, $teacher, $topic, $homework);
        $assessmentUpdatedAt = $homework->updated_at->toJSON();
        $pairUpdatedAt = $pair->updated_at->toJSON();

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", [
            'assignment_mode' => 'selected_students',
        ])->assertConflict()
            ->assertJsonPath('code', 'official_task_requires_group_assignment');

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", [
            'assignment_mode' => 'selected_students',
            'student_ids' => [$student->id],
        ])->assertConflict()
            ->assertJsonPath('code', 'official_task_requires_group_assignment')
            ->assertJsonPath('message', 'The official task requires whole-group assignment.');
        $this->assertSame(AssessmentAssignmentMode::Group, $homework->fresh()?->assignment_mode);
        $this->assertSame($assessmentUpdatedAt, $homework->fresh()?->updated_at->toJSON());
        $this->assertSame($pairUpdatedAt, $pair->fresh()?->updated_at->toJSON());
        $this->assertDatabaseCount('assessment_students', 0);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", [
            'assignment_mode' => 'group',
        ])->assertOk();
        $this->assertSame($assessmentUpdatedAt, $homework->fresh()?->updated_at->toJSON());

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", [
            'student_ids' => [$student->id],
        ])->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_attempt_activity_keeps_the_stricter_existing_homework_patch_conflict(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $student = $this->eligibleStudent($institution, $admin, $group);
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $this->resultPair($institution, $teacher, $topic, $homework);
        $this->attemptFor($this->groupRecipient($institution, $teacher, $homework, $student));

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", [
            'assignment_mode' => 'selected_students',
            'student_ids' => [$student->id],
        ])->assertConflict()
            ->assertJsonPath('code', 'business_conflict')
            ->assertJsonPath('message', 'The requested change conflicts with current task activity.');
        $this->assertSame(AssessmentAssignmentMode::Group, $homework->fresh()?->assignment_mode);
    }

    public function test_active_official_metadata_patch_preserves_the_exact_snapshotted_cohort(): void
    {
        CarbonImmutable::setTestNow('2026-09-03 10:00:00 UTC');
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $retainedStudent = $this->eligibleStudent($institution, $admin, $group);
        $formerStudent = $this->eligibleStudent($institution, $admin, $group);
        $homework = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Active,
            assessmentAttributes: ['title' => 'Official cohort'],
        );
        $assignedAt = CarbonImmutable::parse('2026-09-03 09:00:00 UTC');
        $this->groupRecipient($institution, $teacher, $homework, $retainedStudent, $assignedAt);
        $this->groupRecipient($institution, $teacher, $homework, $formerStudent, $assignedAt);
        $designatedAt = CarbonImmutable::parse('2026-09-03 08:00:00 UTC');
        $cohortAt = CarbonImmutable::parse('2026-09-03 09:00:00 UTC');
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
            'designated_at' => $designatedAt,
            'cohort_snapshotted_at' => $cohortAt,
            'created_at' => $designatedAt,
            'updated_at' => $cohortAt,
        ]);
        $recipientState = AssessmentStudent::query()
            ->where('assessment_id', $homework->id)
            ->orderBy('id')
            ->get()
            ->map(fn (AssessmentStudent $recipient): array => [
                'id' => $recipient->id,
                'student_id' => $recipient->student_id,
                'assigned_at' => $recipient->assigned_at?->toJSON(),
                'updated_at' => $recipient->updated_at->toJSON(),
            ])->all();
        $pair->refresh();
        $pairState = $pair->getAttributes();

        GroupStudentMembership::query()
            ->where('group_id', $group->id)
            ->where('student_id', $formerStudent->id)
            ->update(['ended_at' => now()]);
        $newStudent = $this->eligibleStudent($institution, $admin, $group);

        CarbonImmutable::setTestNow('2026-09-03 11:00:00 UTC');
        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$homework->id}", [
            'title' => 'Updated official title',
        ])->assertOk()->assertJsonPath('data.title', 'Updated official title');

        $recipients = AssessmentStudent::query()
            ->where('assessment_id', $homework->id)
            ->orderBy('id')
            ->get();
        $this->assertSame($recipientState, $recipients->map(fn (AssessmentStudent $recipient): array => [
            'id' => $recipient->id,
            'student_id' => $recipient->student_id,
            'assigned_at' => $recipient->assigned_at?->toJSON(),
            'updated_at' => $recipient->updated_at->toJSON(),
        ])->all());
        $this->assertTrue($recipients->contains('student_id', $formerStudent->id));
        $this->assertFalse($recipients->contains('student_id', $newStudent->id));

        $pair->refresh();
        $this->assertSame($pairState, $pair->getAttributes());
    }

    public function test_designated_selected_draft_activation_rejects_corrupt_pair_without_partial_writes(): void
    {
        CarbonImmutable::setTestNow('2026-09-03 12:00:00 UTC');
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $homework = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            mode: AssessmentAssignmentMode::SelectedStudents,
        );
        $this->persistedQuestion($homework);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $homework->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct,
            'assigned_at' => now()->subMinute(),
            'assigned_by_user_id' => $teacher->id,
        ]);
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
            'designated_at' => now()->subMinutes(2),
            'created_at' => now()->subMinutes(2),
            'updated_at' => now()->subMinutes(2),
        ]);
        $homework->refresh();
        $assessmentState = $homework->getAttributes();
        $homeworkAssignment = $homework->homeworkAssignment()->firstOrFail();
        $homeworkAssignment->refresh();
        $homeworkState = $homeworkAssignment->getAttributes();
        $pair->refresh();
        $pairState = $pair->getAttributes();
        $recipient->refresh();
        $recipientState = [
            $recipient->id,
            $recipient->student_id,
            $recipient->assignment_source,
            $recipient->assigned_at?->toJSON(),
            $recipient->updated_at->toJSON(),
        ];

        CarbonImmutable::setTestNow('2026-09-03 13:00:00 UTC');
        $this->homeworkRaw($teacher, 'POST', "/api/v1/teacher/homework/{$homework->id}/activate", '')
            ->assertConflict()->assertJsonPath('code', 'business_conflict');

        $homework->refresh();
        $this->assertSame($assessmentState, $homework->getAttributes());
        $homeworkAssignment->refresh();
        $this->assertSame(HomeworkStatus::Draft, $homeworkAssignment->status);
        $this->assertSame($homeworkState, $homeworkAssignment->getAttributes());
        $pair->refresh();
        $this->assertSame($pairState, $pair->getAttributes());
        $recipient->refresh();
        $this->assertSame($recipientState, [
            $recipient->id,
            $recipient->student_id,
            $recipient->assignment_source,
            $recipient->assigned_at?->toJSON(),
            $recipient->updated_at->toJSON(),
        ]);
        $this->assertDatabaseCount('assessment_students', 1);
    }

    public function test_archive_blocks_designated_draft_but_preserves_designated_closed_history(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
        $draft = $this->persistedHomework($institution, $teacher, $topic);
        $draftPair = $this->resultPair($institution, $teacher, $topic, $draft);

        $this->homeworkRaw($teacher, 'POST', "/api/v1/teacher/homework/{$draft->id}/archive", '')
            ->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->assertSame(HomeworkStatus::Draft, $draft->homeworkAssignment()->firstOrFail()->status);
        $this->assertDatabaseHas('topic_result_pairs', ['id' => $draftPair->id]);

        $replacement = $this->persistedHomework($institution, $teacher, $topic);
        $this->homeworkJson($teacher, 'PUT', "/api/v1/teacher/topics/{$topic->id}/result-pair", [
            'homework_assessment_id' => $replacement->id,
        ])->assertOk();
        $this->homeworkRaw($teacher, 'POST', "/api/v1/teacher/homework/{$draft->id}/archive", '')
            ->assertOk()->assertJsonPath('data.status', 'archived');

        [$closedInstitution, $closedTeacher, , , $closedTopic] = $this->homeworkContext(TopicStatus::Closed);
        $closed = $this->persistedHomework(
            $closedInstitution,
            $closedTeacher,
            $closedTopic,
            status: HomeworkStatus::Closed,
        );
        $closedPair = $this->resultPair($closedInstitution, $closedTeacher, $closedTopic, $closed, [
            'designated_at' => now()->subMinutes(2),
            'cohort_snapshotted_at' => now()->subMinute(),
        ]);

        $this->homeworkRaw($closedTeacher, 'POST', "/api/v1/teacher/homework/{$closed->id}/archive", '')
            ->assertOk()->assertJsonPath('data.status', 'archived');
        $this->assertDatabaseHas('topic_result_pairs', [
            'id' => $closedPair->id,
            'homework_assessment_id' => $closed->id,
        ]);
    }

    public function test_designation_alone_does_not_freeze_questions_but_pair_lock_still_does(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework);
        $pair = $this->resultPair($institution, $teacher, $topic, $homework);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'prompt' => 'Official but still editable',
        ])->assertOk()->assertJsonPath('message', 'Question updated successfully.');
        $this->assertSame('Official but still editable', $question->fresh()?->prompt);

        $pair->cohort_snapshotted_at = now();
        $pair->locked_at = now();
        $pair->save();
        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'prompt' => 'Blocked',
        ])->assertConflict()->assertJsonPath('code', 'result_pair_locked');
        $this->assertSame('Official but still editable', $question->fresh()?->prompt);
        $this->assertInstanceOf(TopicResultPair::class, $pair->fresh());
    }
}
