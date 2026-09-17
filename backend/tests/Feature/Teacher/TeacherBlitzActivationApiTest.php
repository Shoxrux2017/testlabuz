<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\BlitzStatus;
use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\GroupStudentMembership;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzActivationContext;
use Tests\TestCase;

class TeacherBlitzActivationApiTest extends TestCase
{
    use BuildsTeacherBlitzActivationContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-17 12:00:00 UTC'));
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        parent::tearDown();
    }

    #[DataProvider('activationSources')]
    public function test_synchronized_activation_uses_current_questions_and_group_recipients_and_preserves_schedule(string $source, ?string $scheduledAt): void
    {
        [$institution, $teacher, $admin, $group, , $student, $assessment] = $this->readyBlitzActivation(status: BlitzStatus::from($source));
        $secondStudent = $this->eligibleBlitzStudent($institution, $admin, $group);
        $this->eligibleBlitzStudent($institution, $admin, $group, ['is_active' => false]);
        $former = $this->eligibleBlitzStudent($institution, $admin, $group);
        GroupStudentMembership::query()->where('student_id', $former->id)->update(['ended_at' => now()]);
        User::factory()->student($institution)->create();
        $this->activationQuestion($assessment, '0.100002', 2);
        $assessment->update(['total_possible_points' => '99.000000']);
        BlitzTask::query()->whereKey($assessment->id)->update(['scheduled_at' => $scheduledAt]);
        $questionsBefore = Question::query()->where('assessment_id', $assessment->id)->orderBy('position')->get()->map->getAttributes()->all();
        $this->travelTo(CarbonImmutable::parse('2026-09-17 13:00:00 UTC'));

        $response = $this->activateBlitz($teacher, $assessment->id)->assertOk()
            ->assertJsonPath('message', 'Blitz task activated successfully.')
            ->assertJsonPath('data.id', $assessment->id)->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.timer_start_mode_snapshot', 'synchronized')
            ->assertJsonPath('data.activated_at', '2026-09-17T13:00:00Z')
            ->assertJsonPath('data.synchronized_ends_at', '2026-09-17T13:10:00Z')
            ->assertJsonPath('data.scheduled_at', $scheduledAt)
            ->assertJsonPath('data.duration_seconds', 600)->assertJsonPath('data.total_possible_points', 2.100003)
            ->assertJsonPath('data.institution_timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.attempt_policy', ['normal_attempts' => 1, 'max_additional_exception_attempts' => 1])
            ->assertJsonPath('data.student_ids', [])->assertJsonCount(2, 'data.questions');
        $this->assertSame([
            'id', 'topic_id', 'group_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'duration_seconds', 'scheduled_at', 'institution_timezone',
            'status', 'timer_start_mode_snapshot', 'attempt_policy', 'activated_at', 'synchronized_ends_at',
            'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $blitz = BlitzTask::query()->findOrFail($assessment->id);
        $this->assertSame($teacher->id, $blitz->activated_by_user_id);
        $this->assertTrue($blitz->activated_at->equalTo(now()));
        $this->assertTrue($blitz->updated_at->equalTo(now()));
        $this->assertTrue($assessment->fresh()->updated_at->equalTo(now()));
        $this->assertSame('2.100003', $assessment->fresh()->total_possible_points);
        $recipients = AssessmentStudent::query()->where('assessment_id', $assessment->id)->get();
        $this->assertEqualsCanonicalizing([$student->id, $secondStudent->id], $recipients->pluck('student_id')->all());
        foreach ($recipients as $recipient) {
            $this->assertSame('group', $recipient->assignment_source->value);
            $this->assertSame($teacher->id, $recipient->assigned_by_user_id);
            $this->assertTrue($recipient->assigned_at->equalTo(now()));
        }
        $this->assertSame($questionsBefore, Question::query()->where('assessment_id', $assessment->id)->orderBy('position')->get()->map->getAttributes()->all());
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    public static function activationSources(): array
    {
        return [
            'draft' => ['draft', null],
            'scheduled before planned instant' => ['scheduled', '2026-09-18T15:00:00Z'],
            'scheduled after planned instant' => ['scheduled', '2026-09-17T12:30:00Z'],
        ];
    }

    public function test_individual_activation_snapshots_mode_without_common_end_or_attempts(): void
    {
        [$institution, $teacher, , , , , $assessment] = $this->readyBlitzActivation('individual');
        $this->activateBlitz($teacher, $assessment->id, body: '')->assertOk()
            ->assertJsonPath('data.timer_start_mode_snapshot', 'individual')->assertJsonPath('data.synchronized_ends_at', null);
        $this->assertDatabaseCount('assessment_attempts', 0);
        $before = $this->activationSnapshot($assessment);
        InstitutionSetting::query()->whereKey($institution->id)->update(['blitz_timer_start_mode' => 'synchronized']);
        $this->assertSame($before, $this->activationSnapshot($assessment));
    }

    #[DataProvider('fractionalInstants')]
    public function test_timer_decision_instant_truncates_to_whole_utc_seconds(string $instant): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $this->travelTo(CarbonImmutable::parse($instant));
        $this->activateBlitz($teacher, $assessment->id)->assertOk()
            ->assertJsonPath('data.activated_at', '2026-09-17T12:00:00Z')
            ->assertJsonPath('data.synchronized_ends_at', '2026-09-17T12:10:00Z');
        $blitz = BlitzTask::query()->findOrFail($assessment->id);
        $this->assertSame('000000', $blitz->activated_at->format('u'));
        $this->assertSame('000000', $blitz->synchronized_ends_at->format('u'));
        $this->assertSame('2026-09-17 12:00:00', $blitz->activated_at->utc()->format('Y-m-d H:i:s'));
        $this->assertSame(600.0, $blitz->activated_at->diffInSeconds($blitz->synchronized_ends_at));
    }

    public static function fractionalInstants(): array
    {
        return [['2026-09-17T12:00:00.500000Z'], ['2026-09-17T12:00:00.999999Z']];
    }

    public function test_missing_timer_setting_rolls_back_official_cohort_recipients_activation_and_claim(): void
    {
        [$institution, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $pair = $this->activationPair($assessment, $teacher);
        InstitutionSetting::query()->whereKey($institution->id)->update(['blitz_timer_start_mode' => null]);
        $before = $this->activationSnapshot($assessment, $pair);
        $response = $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertExactJson([
            'message' => 'Required institution settings are incomplete.', 'code' => 'institution_settings_incomplete',
            'errors' => [], 'meta' => ['missing_fields' => ['blitz_timer_start_mode']],
        ]);
        $this->assertIsObject(json_decode($response->getContent(), false, flags: JSON_THROW_ON_ERROR)->errors);
        $this->assertSame($before, $this->activationSnapshot($assessment, $pair));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('questionFailures')]
    public function test_invalid_questions_fail_without_partial_activation(string $corruption, string $code): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $question = Question::query()->where('assessment_id', $assessment->id)->sole();
        if ($corruption === 'no questions') {
            $question->trueFalseAnswer()->delete();
            $question->delete();
        } elseif ($corruption === 'zero points') {
            $question->update(['points' => '0.000000']);
        } else {
            QuestionTrueFalseAnswer::query()->where('question_id', $question->id)->delete();
        }
        $before = $this->activationSnapshot($assessment);
        $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertJsonPath('code', $code);
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function questionFailures(): array
    {
        return [
            ['no questions', 'assessment_has_no_scoreable_points'],
            ['zero points', 'assessment_has_no_scoreable_points'],
            ['missing typed configuration', 'business_conflict'],
        ];
    }

    public function test_group_without_eligible_students_cannot_activate(): void
    {
        [, $teacher, , , , $student, $assessment] = $this->readyBlitzActivation();
        $student->update(['is_active' => false]);
        $before = $this->activationSnapshot($assessment);
        $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertJsonPath('code', 'assessment_not_assigned');
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_selected_student_activation_preserves_direct_recipient_rows(): void
    {
        [, $teacher, , , , $student, $assessment] = $this->readyBlitzActivation(assignmentMode: AssessmentAssignmentMode::SelectedStudents);
        $before = AssessmentStudent::query()->where('assessment_id', $assessment->id)->sole()->getAttributes();
        $this->travel(1)->minutes();
        $this->activateBlitz($teacher, $assessment->id)->assertOk()->assertJsonPath('data.student_ids', [$student->id]);
        $this->assertSame($before, AssessmentStudent::query()->where('assessment_id', $assessment->id)->sole()->getAttributes());
    }

    #[DataProvider('selectedRecipientFailures')]
    public function test_selected_student_ineligibility_rejects_the_entire_set_without_rewriting_it(string $failure): void
    {
        [, $teacher, , , , $student, $assessment] = $this->readyBlitzActivation(assignmentMode: AssessmentAssignmentMode::SelectedStudents);
        match ($failure) {
            'inactive' => $student->update(['is_active' => false]),
            'former member' => GroupStudentMembership::query()->where('student_id', $student->id)->update(['ended_at' => now()]),
            'missing' => AssessmentStudent::query()->where('assessment_id', $assessment->id)->delete(),
        };
        $before = $this->activationSnapshot($assessment);
        $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertJsonPath('code', 'assessment_not_assigned');
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function selectedRecipientFailures(): array
    {
        return [['inactive'], ['former member'], ['missing']];
    }

    #[DataProvider('nonActivatableStates')]
    public function test_closed_or_archived_blitz_rejects_a_new_key(string $status, string $code): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation(status: BlitzStatus::from($status));
        $before = $this->activationSnapshot($assessment);
        $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertJsonPath('code', $code);
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function nonActivatableStates(): array
    {
        return [['closed', 'task_closed'], ['archived', 'task_archived']];
    }

    public function test_activation_requires_active_topic_and_group(): void
    {
        foreach ([TopicStatus::Draft, TopicStatus::Closed, TopicStatus::Archived, 'archived group'] as $state) {
            [, $teacher, , $group, $topic, , $assessment] = $this->readyBlitzActivation();
            if ($state === 'archived group') {
                $group->update(['status' => GroupStatus::Archived, 'archived_at' => now()]);
            } else {
                $topic->update(['status' => $state, 'activated_at' => $state === TopicStatus::Closed ? $topic->activated_at : null,
                    'closed_at' => $state === TopicStatus::Closed ? now() : null,
                    'archived_at' => $state === TopicStatus::Archived ? now() : null]);
            }
            $before = $this->activationSnapshot($assessment);
            $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertJsonPath('code', 'topic_not_editable');
            $this->assertSame($before, $this->activationSnapshot($assessment));
        }
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_preactivation_attempt_and_hidden_group_snapshot_are_not_activated_around(): void
    {
        foreach ([false, true] as $hasAttempt) {
            [, $teacher, , , , $student, $assessment] = $this->readyBlitzActivation();
            $this->blitzRecipient($assessment, $student, $teacher)->update(['assignment_source' => 'group']);
            if ($hasAttempt) {
                $this->blitzAttempt($assessment, $student, $teacher);
            }
            $before = $this->activationSnapshot($assessment);
            $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertJsonPath('code', 'business_conflict');
            $this->assertSame($before, $this->activationSnapshot($assessment));
        }
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('invalidActivationRequests')]
    public function test_activation_rejects_invalid_request_shape_without_writes(?string $key, string $body, array $query, string $contentType): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $before = $this->activationSnapshot($assessment);
        $this->activateBlitz($teacher, $assessment->id, $key, $body, $query, $contentType)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function invalidActivationRequests(): array
    {
        return [
            'missing key' => ['', '{}', [], 'application/json'],
            'malformed key' => ['invalid', '{}', [], 'application/json'],
            'field' => [null, '{"duration_seconds":10}', [], 'application/json'],
            'array' => [null, '[]', [], 'application/json'],
            'null' => [null, 'null', [], 'application/json'],
            'scalar' => [null, '"value"', [], 'application/json'],
            'malformed JSON' => [null, '{', [], 'application/json'],
            'query' => [null, '{}', ['unexpected' => 'value'], 'application/json'],
            'non JSON object' => [null, '{}', [], 'text/plain'],
        ];
    }
}
