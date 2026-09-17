<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\BlitzStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\Feature\Teacher\Concerns\BuildsTeacherTopicResultPairContext;
use Tests\TestCase;

class TeacherOfficialBlitzDesignationTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use BuildsTeacherTopicResultPairContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        CarbonImmutable::setTestNow('2026-09-17 10:00:00 UTC');
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    public function test_initial_pair_accepts_incomplete_draft_or_scheduled_blitz_without_creating_recipients_or_attempts(): void
    {
        foreach ([BlitzStatus::Draft, BlitzStatus::Scheduled] as $status) {
            [$institution, $teacher, , , $topic] = $this->blitzContext();
            $homework = $this->persistedHomework($institution, $teacher, $topic);
            $blitz = $this->persistedBlitz($institution, $teacher, $topic, status: $status);

            $this->putPair($teacher, $topic, $homework, $blitz)->assertOk()
                ->assertJsonPath('data.homework_assessment_id', $homework->id)
                ->assertJsonPath('data.blitz_assessment_id', $blitz->id)
                ->assertJsonPath('data.cohort_snapshotted_at', null)
                ->assertJsonPath('data.locked_at', null)
                ->assertJsonPath('data.designated_at', '2026-09-17T10:00:00Z');
            $this->assertSame($status, $blitz->blitzTask()->firstOrFail()->status);
        }

        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('questions', 0);
        $this->assertDatabaseCount('topic_result_pairs', 2);
    }

    public function test_initial_complete_pair_adopts_active_homework_snapshot_without_current_membership_resnapshot(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext(TopicStatus::Active);
        $homework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $blitz = $this->persistedBlitz($institution, $teacher, $topic);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $recipient = $this->groupRecipient($institution, $teacher, $homework, $student, now()->subHour());
        $this->eligibleStudent($institution, $admin, $group);
        $before = $recipient->fresh()->getAttributes();

        $this->putPair($teacher, $topic, $homework, $blitz)->assertOk()
            ->assertJsonPath('data.cohort_snapshotted_at', '2026-09-17T10:00:00Z');

        $this->assertSame($before, $recipient->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_students', 1);
        $this->assertSame(0, AssessmentStudent::query()->where('assessment_id', $blitz->id)->count());
    }

    public function test_homework_only_and_same_pair_put_preserve_complete_pair_after_task_lifecycle_and_lock(): void
    {
        foreach ([BlitzStatus::Active, BlitzStatus::Closed, BlitzStatus::Archived] as $status) {
            [$institution, $teacher, , , $topic] = $this->blitzContext(TopicStatus::Active);
            $homework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Archived);
            $blitz = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
            $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
                'blitz_assessment_id' => $blitz->id,
                'designated_at' => now()->subHours(3),
                'cohort_snapshotted_at' => now()->subHours(2),
                'locked_at' => now()->subHour(),
                'created_at' => now()->subHours(3),
                'updated_at' => now()->subHour(),
            ]);
            $before = $pair->fresh()->getAttributes();

            $this->putPair($teacher, $topic, $homework)->assertOk()->assertJsonPath('data.blitz_assessment_id', $blitz->id);
            $this->putPair($teacher, $topic, $homework, $blitz)->assertOk()->assertJsonPath('data.blitz_assessment_id', $blitz->id);

            $this->assertSame($before, $pair->fresh()->getAttributes());
        }
    }

    public function test_locked_partial_pair_can_complete_without_rewriting_homework_activity_or_pair_history(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext(TopicStatus::Active);
        $homework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Closed);
        $blitz = $this->persistedBlitz($institution, $teacher, $topic);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $recipient = $this->groupRecipient($institution, $teacher, $homework, $student, now()->subHours(2));
        $attempt = $this->attemptFor($recipient);
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
            'designated_at' => now()->subHours(3),
            'cohort_snapshotted_at' => now()->subHours(2),
            'locked_at' => now()->subHour(),
            'created_at' => now()->subHours(3),
            'updated_at' => now()->subHour(),
        ]);
        $before = $pair->fresh()->getAttributes();
        $recipientBefore = $recipient->fresh()->getAttributes();
        $attemptBefore = $attempt->fresh()->getAttributes();

        $this->putPair($teacher, $topic, $homework, $blitz)->assertOk()
            ->assertJsonPath('data.updated_at', '2026-09-17T10:00:00Z');

        $this->assertOnlyBlitzChanged($pair, $before, $blitz);
        $this->assertSame($recipientBefore, $recipient->fresh()->getAttributes());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_students', 1);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public function test_unlocked_blitz_attach_and_replacement_preserve_pair_designation_and_existing_cohort(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext(TopicStatus::Active);
        $homework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $this->groupRecipient($institution, $teacher, $homework, $student, now()->subHours(2));
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
            'designated_at' => now()->subHours(3),
            'cohort_snapshotted_at' => now()->subHours(2),
            'created_at' => now()->subHours(3),
            'updated_at' => now()->subHours(2),
        ]);

        foreach ([BlitzStatus::Draft, BlitzStatus::Scheduled, BlitzStatus::Draft] as $status) {
            $blitz = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
            $this->persistedQuestion($blitz);
            $before = $pair->fresh()->getAttributes();
            $this->putPair($teacher, $topic, $homework, $blitz)->assertOk();
            $this->assertOnlyBlitzChanged($pair, $before, $blitz);
        }

        $this->assertDatabaseCount('blitz_tasks', 3);
        $this->assertDatabaseCount('questions', 3);
        $this->assertDatabaseCount('assessment_students', 1);
    }

    public function test_homework_replacement_can_attach_blitz_atomically_when_partial_pair_is_unlocked(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $current = $this->persistedHomework($institution, $teacher, $topic);
        $candidate = $this->persistedHomework($institution, $teacher, $topic);
        $blitz = $this->persistedBlitz($institution, $teacher, $topic);
        $pair = $this->resultPair($institution, $teacher, $topic, $current, [
            'designated_at' => now()->subHour(),
            'created_at' => now()->subHour(),
            'updated_at' => now()->subHour(),
        ]);
        $createdAt = $pair->created_at->toJSON();

        $this->putPair($teacher, $topic, $candidate, $blitz)->assertOk()
            ->assertJsonPath('data.homework_assessment_id', $candidate->id)
            ->assertJsonPath('data.blitz_assessment_id', $blitz->id)
            ->assertJsonPath('data.designated_at', '2026-09-17T10:00:00Z');
        $this->assertSame($createdAt, $pair->fresh()->created_at->toJSON());
    }

    public function test_ineligible_blitz_rejects_the_whole_homework_replacement(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $current = $this->persistedHomework($institution, $teacher, $topic);
        $candidate = $this->persistedHomework($institution, $teacher, $topic);
        $blitz = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Active);
        $pair = $this->resultPair($institution, $teacher, $topic, $current);
        $before = $pair->fresh()->getAttributes();

        $this->putPair($teacher, $topic, $candidate, $blitz)->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->assertSame($before, $pair->fresh()->getAttributes());
    }

    public function test_new_blitz_rejects_selected_assignment_ineligible_lifecycle_attempts_and_hidden_recipients(): void
    {
        foreach (['selected', 'active', 'closed', 'archived', 'attempt', 'recipients'] as $scenario) {
            [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
            $homework = $this->persistedHomework($institution, $teacher, $topic);
            $status = BlitzStatus::tryFrom($scenario) ?? BlitzStatus::Draft;
            $mode = $scenario === 'selected' ? AssessmentAssignmentMode::SelectedStudents : AssessmentAssignmentMode::Group;
            $blitz = $this->persistedBlitz($institution, $teacher, $topic, mode: $mode, status: $status);

            if (in_array($scenario, ['attempt', 'recipients'], true)) {
                $recipient = $this->groupRecipient($institution, $teacher, $blitz, $this->eligibleStudent($institution, $admin, $group));

                if ($scenario === 'attempt') {
                    $this->attemptFor($recipient);
                }
            }

            $expected = match ($scenario) {
                'selected' => 'official_task_requires_group_assignment',
                'attempt' => 'result_pair_locked',
                default => 'business_conflict',
            };
            $this->putPair($teacher, $topic, $homework, $blitz)->assertConflict()->assertJsonPath('code', $expected);
            $this->assertDatabaseMissing('topic_result_pairs', ['topic_id' => $topic->id]);
        }
    }

    public function test_candidate_blitz_resolution_does_not_disclose_foreign_topic_tenant_teacher_or_non_blitz(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->blitzContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $otherTopic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $otherTeacher = User::factory()->teacher($institution)->create();
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->blitzContext();
        $missingDetail = Assessment::factory()->blitz()->groupAssignment()->create([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'teacher_id' => $teacher->id,
        ]);
        $candidates = [
            $this->persistedBlitz($institution, $teacher, $otherTopic),
            $this->persistedBlitz($institution, $otherTeacher, $topic),
            $this->persistedBlitz($foreignInstitution, $foreignTeacher, $foreignTopic),
            $homework,
            $missingDetail,
        ];

        foreach ($candidates as $candidate) {
            $this->putPair($teacher, $topic, $homework, $candidate)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    public function test_locked_partial_or_completed_pair_blocks_homework_replacement_and_locked_blitz_replacement(): void
    {
        foreach (['locked_partial', 'locked_complete', 'unlocked_complete'] as $scenario) {
            [$institution, $teacher, , , $topic] = $this->blitzContext();
            $homework = $this->persistedHomework($institution, $teacher, $topic);
            $replacementHomework = $this->persistedHomework($institution, $teacher, $topic);
            $blitz = $this->persistedBlitz($institution, $teacher, $topic);
            $candidate = $this->persistedBlitz($institution, $teacher, $topic);
            $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
                'blitz_assessment_id' => $scenario === 'locked_partial' ? null : $blitz->id,
                'designated_at' => now()->subHours(3),
                'cohort_snapshotted_at' => now()->subHours(2),
                'locked_at' => $scenario === 'unlocked_complete' ? null : now()->subHour(),
            ]);
            $before = $pair->fresh()->getAttributes();

            $this->putPair($teacher, $topic, $replacementHomework, $candidate)
                ->assertConflict()->assertJsonPath('code', 'result_pair_locked');

            if ($scenario === 'locked_complete') {
                $this->putPair($teacher, $topic, $homework, $candidate)
                    ->assertConflict()->assertJsonPath('code', 'result_pair_locked');
            }

            $this->assertSame($before, $pair->fresh()->getAttributes());
        }
    }

    public function test_current_activated_blitz_or_current_or_candidate_attempt_blocks_unlocked_replacement(): void
    {
        foreach (['active', 'closed', 'archived', 'current_attempt', 'candidate_attempt'] as $scenario) {
            [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
            $homework = $this->persistedHomework($institution, $teacher, $topic);
            $blitz = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::tryFrom($scenario) ?? BlitzStatus::Draft);
            $candidate = $this->persistedBlitz($institution, $teacher, $topic);
            $pair = $this->resultPair($institution, $teacher, $topic, $homework, ['blitz_assessment_id' => $blitz->id]);
            $before = $pair->fresh()->getAttributes();

            if (in_array($scenario, ['current_attempt', 'candidate_attempt'], true)) {
                $assessment = $scenario === 'current_attempt' ? $blitz : $candidate;
                $student = $this->eligibleStudent($institution, $admin, $group);
                $this->attemptFor($this->groupRecipient($institution, $teacher, $assessment, $student));
            }

            $this->putPair($teacher, $topic, $homework, $candidate)
                ->assertConflict()->assertJsonPath('code', 'result_pair_locked');
            $this->assertSame($before, $pair->fresh()->getAttributes());
        }
    }

    private function putPair(User $teacher, Topic $topic, Assessment $homework, ?Assessment $blitz = null): TestResponse
    {
        $payload = ['homework_assessment_id' => $homework->id];

        if ($blitz !== null) {
            $payload['blitz_assessment_id'] = $blitz->id;
        }

        return $this->homeworkJson($teacher, 'PUT', "/api/v1/teacher/topics/{$topic->id}/result-pair", $payload);
    }

    /** @param array<string, mixed> $before */
    private function assertOnlyBlitzChanged(TopicResultPair $pair, array $before, Assessment $blitz): void
    {
        $after = $pair->fresh()->getAttributes();
        $this->assertSame($blitz->id, $after['blitz_assessment_id']);
        $this->assertSame('2026-09-17T10:00:00+00:00', $pair->fresh()->updated_at->toIso8601String());
        unset($before['blitz_assessment_id'], $before['updated_at'], $after['blitz_assessment_id'], $after['updated_at']);
        $this->assertSame($before, $after);
    }
}
