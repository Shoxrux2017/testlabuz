<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\CloseTeacherBlitz;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Models\AnswerBooleanValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzActivationContext;
use Tests\TestCase;

class TeacherBlitzCloseApiTest extends TestCase
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

    #[DataProvider('synchronizedCloseTimes')]
    public function test_synchronized_close_uses_deadline_precedence_and_returns_complete_resource(string $closedAt, string $status, string $reason, string $finalizedAt): void
    {
        [, $teacher, , , , $student, $assessment] = $this->closeContext('synchronized');
        $attempt = $this->closeAttempt($assessment, $student, '2026-09-17 12:05:00 UTC');
        $before = $attempt->getAttributes();
        $history = $assessment->blitzTask->getAttributes();
        $this->travelTo(CarbonImmutable::parse($closedAt));

        $response = $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close", '{}')
            ->assertOk()->assertJsonPath('message', 'Blitz task closed successfully.')
            ->assertJsonPath('data.id', $assessment->id)->assertJsonPath('data.status', 'closed')
            ->assertJsonPath('data.closed_at', now()->format('Y-m-d\TH:i:s\Z'))
            ->assertJsonPath('data.timer_start_mode_snapshot', 'synchronized')->assertJsonCount(1, 'data.questions');
        $this->assertSame([
            'id', 'topic_id', 'group_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'duration_seconds', 'scheduled_at', 'institution_timezone',
            'status', 'timer_start_mode_snapshot', 'attempt_policy', 'activated_at', 'synchronized_ends_at',
            'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $this->assertFinalization($attempt, $status, $reason, $finalizedAt);
        foreach (['started_at', 'deadline_at', 'attempt_number', 'assessment_student_id', 'student_id',
            'official_score_eligible', 'possible_points', 'earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertSame($before[$field], $attempt->fresh()->getAttributes()[$field], $field);
        }
        $blitz = BlitzTask::query()->findOrFail($assessment->id);
        foreach (['scheduled_at', 'timer_start_mode_snapshot', 'activated_at', 'activated_by_user_id', 'synchronized_ends_at', 'archived_at'] as $field) {
            $this->assertSame($history[$field], $blitz->getAttributes()[$field], $field);
        }
        $this->assertTrue($blitz->updated_at->equalTo(now()));
        $this->assertTrue($assessment->fresh()->updated_at->equalTo(now()));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function synchronizedCloseTimes(): array
    {
        return [
            'before deadline' => ['2026-09-17 12:00:00 UTC', 'submitted', 'task_closed_auto_finalize', '2026-09-17 12:00:00'],
            'exact deadline' => ['2026-09-17 12:05:00 UTC', 'timed_out_finalized', 'timeout_auto_submit', '2026-09-17 12:05:00'],
            'after deadline' => ['2026-09-17 12:08:00 UTC', 'timed_out_finalized', 'timeout_auto_submit', '2026-09-17 12:05:00'],
        ];
    }

    public function test_individual_close_mixes_timeout_and_close_reasons_preserving_answers_terminal_history_and_cohort(): void
    {
        [$institution, $teacher, $admin, $group, , $student, $assessment] = $this->closeContext();
        $pair = $this->officialBlitzPair($assessment, $teacher, true);
        $attempts = [];
        foreach (['2026-09-17 11:59:00 UTC', '2026-09-17 12:00:00 UTC', '2026-09-17 12:05:00 UTC'] as $deadline) {
            $actor = $attempts === [] ? $student : $this->eligibleBlitzStudent($institution, $admin, $group);
            $attempts[] = $this->closeAttempt($assessment, $actor, $deadline);
        }
        $terminal = [];
        foreach ([['submitted', 'student_submit'], ['timed_out_finalized', 'timeout_auto_submit']] as [$status, $reason]) {
            $actor = $this->eligibleBlitzStudent($institution, $admin, $group);
            $attempt = $this->closeAttempt($assessment, $actor, '2026-09-17 11:59:00 UTC');
            $attempt->update(['status' => $status, 'finalization_reason' => $reason,
                'submitted_at' => $reason === 'student_submit' ? '2026-09-17 11:58:00' : null,
                'finalized_at' => '2026-09-17 11:59:00', 'locked_at' => '2026-09-17 11:59:00']);
            $terminal[$attempt->id] = $attempt->fresh()->getAttributes();
        }
        $neverStarted = $this->eligibleBlitzStudent($institution, $admin, $group);
        $this->blitzRecipient($assessment, $neverStarted, $teacher);
        $question = $assessment->questions()->sole();
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempts[0]->id, 'question_id' => $question->id]);
        $value = AnswerBooleanValue::factory()->create(['answer_id' => $answer->id, 'boolean_value' => false]);
        $answerBefore = [$answer->fresh()->getAttributes(), $value->fresh()->getAttributes()];
        $snapshot = $this->activationSnapshot($assessment, $pair);

        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")->assertOk();

        foreach ($attempts as $index => $attempt) {
            $this->assertFinalization($attempt, $index < 2 ? 'timed_out_finalized' : 'submitted',
                $index < 2 ? 'timeout_auto_submit' : 'task_closed_auto_finalize',
                $index < 2 ? $attempt->deadline_at->format('Y-m-d H:i:s') : '2026-09-17 12:00:00');
        }
        foreach ($terminal as $id => $attributes) {
            $this->assertSame($attributes, AssessmentAttempt::query()->findOrFail($id)->getAttributes());
        }
        $this->assertSame($answerBefore, [$answer->fresh()->getAttributes(), $value->fresh()->getAttributes()]);
        $this->assertDatabaseCount('attempt_answers', 1);
        $this->assertDatabaseCount('assessment_attempts', 5);
        $this->assertDatabaseMissing('assessment_attempts', ['student_id' => $neverStarted->id]);
        $this->assertSame($snapshot['pair'], $pair->fresh()->getAttributes());
        $this->assertSame($snapshot['recipients'], $this->activationSnapshot($assessment)['recipients']);
    }

    public function test_close_without_attempts_does_not_fabricate_work_and_repeat_is_write_free_even_under_archived_topic(): void
    {
        [, $teacher, , , $topic, $student, $assessment] = $this->closeContext();
        $this->blitzRecipient($assessment, $student, $teacher);
        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")->assertOk();
        $before = $this->activationSnapshot($assessment);
        $this->travelTo(now()->addHour());
        $topic->update(['status' => TopicStatus::Archived, 'closed_at' => now(), 'archived_at' => now()]);

        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close", '{}')->assertOk();

        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('rejectedTaskStates')]
    public function test_close_rejects_non_active_lifecycle_states_without_writes(string $status, string $code): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation(status: BlitzStatus::from($status));
        $before = $this->activationSnapshot($assessment);
        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")
            ->assertConflict()->assertJsonPath('code', $code);
        $this->assertSame($before, $this->activationSnapshot($assessment));
    }

    public static function rejectedTaskStates(): array
    {
        return [['draft', 'task_not_active'], ['scheduled', 'task_not_active'], ['archived', 'task_archived']];
    }

    public function test_archived_topic_blocks_close_but_closed_topic_allows_recovery(): void
    {
        [, $teacher, , , $topic, , $assessment] = $this->closeContext();
        $topic->update(['status' => TopicStatus::Archived, 'closed_at' => now(), 'archived_at' => now()]);
        $before = $this->activationSnapshot($assessment);
        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")
            ->assertConflict()->assertJsonPath('code', 'topic_not_editable');
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $topic->update(['status' => TopicStatus::Closed, 'archived_at' => null]);
        $topicBefore = $topic->fresh()->getAttributes();
        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")->assertOk();
        $this->assertSame($topicBefore, $topic->fresh()->getAttributes());
    }

    public function test_corrupt_in_progress_history_rolls_back_entire_close(): void
    {
        [, $teacher, , , , $student, $assessment] = $this->closeContext();
        $attempt = $this->closeAttempt($assessment, $student, '2026-09-17 12:05:00 UTC');
        $attempt->update(['submitted_at' => now()]);
        $before = [$this->activationSnapshot($assessment), $attempt->fresh()->getAttributes()];
        try {
            app(CloseTeacherBlitz::class)($teacher, $assessment->id);
            $this->fail('Corrupt finalization history must reject close.');
        } catch (LogicException) {
            $this->assertSame($before, [$this->activationSnapshot($assessment), $attempt->fresh()->getAttributes()]);
        }
    }

    #[DataProvider('invalidLifecycleInputs')]
    public function test_close_requires_empty_body_and_no_query(string $body, array $query): void
    {
        [, $teacher, , , , , $assessment] = $this->closeContext();
        $before = $this->activationSnapshot($assessment);
        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close", $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $this->activationSnapshot($assessment));
    }

    public static function invalidLifecycleInputs(): array
    {
        return [['{"closed_at":"2026-09-17"}', []], ['[]', []], ['null', []], ['{}', ['force' => 1]]];
    }

    public function test_route_is_registered_once_with_teacher_middleware_and_requires_teacher_authentication(): void
    {
        $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/teacher/blitz/{blitz}/close')
            ->map(fn ($route): array => [$route->methods(), $route->middleware()])->values()->all();
        $this->assertSame([[['POST'], ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher']]], $routes);
        [, , $admin, , , $student, $assessment] = $this->closeContext();
        $student->update(['must_change_password' => false]);
        $before = $this->activationSnapshot($assessment);
        $this->postJson("/api/v1/teacher/blitz/{$assessment->id}/close")->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        foreach ([$admin, $student] as $actor) {
            $this->blitzRaw($actor, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")
                ->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
        $this->assertSame($before, $this->activationSnapshot($assessment));
    }

    #[DataProvider('restrictedAccountStates')]
    public function test_close_obeys_account_institution_and_password_gates(string $gate, string $code): void
    {
        [$institution, $teacher, , , , , $assessment] = $this->closeContext();
        match ($gate) {
            'account' => $teacher->update(['is_active' => false]),
            'password' => $teacher->update(['must_change_password' => true]),
            'institution' => $institution->update(['status' => 'inactive', 'deactivated_at' => now()]),
        };
        $before = $this->activationSnapshot($assessment);
        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")
            ->assertForbidden()->assertJsonPath('code', $code);
        $this->assertSame($before, $this->activationSnapshot($assessment));
    }

    public static function restrictedAccountStates(): array
    {
        return [['account', 'user_inactive'], ['password', 'password_change_required'], ['institution', 'institution_inactive']];
    }

    public function test_private_foreign_invalid_and_non_blitz_identifiers_are_indistinguishable(): void
    {
        [$institution, $teacher, , $group, $topic, , $assessment] = $this->closeContext();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $other = $this->persistedBlitz($institution, $otherTeacher, $topic);
        $homework = Assessment::factory()->homework()->create(['institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id]);
        $missingDetail = Assessment::factory()->blitz()->create(['institution_id' => $institution->id, 'teacher_id' => $teacher->id, 'topic_id' => $topic->id]);
        $hiddenTopic = Topic::factory()->active()->create(['institution_id' => $institution->id, 'teacher_id' => $otherTeacher->id, 'group_id' => $group->id]);
        $hidden = $this->persistedBlitz($institution, $teacher, $hiddenTopic);
        [, , , , , , $foreign] = $this->closeContext();
        $before = $this->activationSnapshot($assessment);
        $expected = null;
        foreach (['bad-id', (string) Str::uuid(), $other->id, $homework->id, $missingDetail->id, $hidden->id, $foreign->id] as $id) {
            $response = $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$id}/close")
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $expected ??= $response->json();
            $this->assertSame($expected, $response->json());
        }
        GroupTeacherMembership::query()->where('group_id', $group->id)->where('teacher_id', $teacher->id)->update(['ended_at' => now()]);
        $this->blitzRaw($teacher, 'POST', "/api/v1/teacher/blitz/{$assessment->id}/close")
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    private function closeContext(string $timerMode = 'individual'): array
    {
        $context = $this->readyBlitzActivation($timerMode, status: BlitzStatus::Active);
        BlitzTask::query()->whereKey($context[6]->id)->update([
            'created_at' => '2026-09-17 11:49:00',
            'activated_at' => '2026-09-17 11:50:00', 'timer_start_mode_snapshot' => $timerMode,
            'synchronized_ends_at' => $timerMode === 'synchronized' ? '2026-09-17 12:05:00' : null,
            'duration_seconds' => 900,
        ]);

        return $context;
    }

    private function closeAttempt(Assessment $assessment, User $student, string $deadline): AssessmentAttempt
    {
        return $this->blitzAttempt($assessment, $student, $assessment->teacher, [
            'started_at' => '2026-09-17 11:50:00', 'deadline_at' => CarbonImmutable::parse($deadline),
            'possible_points' => '2.000001',
        ])->fresh();
    }

    private function assertFinalization(AssessmentAttempt $attempt, string $status, string $reason, string $instant): void
    {
        $attempt->refresh();
        $this->assertSame($status, $attempt->status->value);
        $this->assertSame($reason, $attempt->finalization_reason->value);
        $this->assertNull($attempt->submitted_at);
        $this->assertSame($instant, $attempt->finalized_at->format('Y-m-d H:i:s'));
        $this->assertSame($instant, $attempt->locked_at->format('Y-m-d H:i:s'));
        foreach (['earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertNull($attempt->{$field});
        }
    }
}
