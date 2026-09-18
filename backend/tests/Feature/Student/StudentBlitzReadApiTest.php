<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzContext;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

class StudentBlitzReadApiTest extends TestCase
{
    use BuildsStudentBlitzContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_active_list_returns_only_assigned_executable_normal_attempts_in_deterministic_order(): void
    {
        $student = $this->studentBlitzActor();
        $expected = [];
        foreach (['synchronized', 'individual'] as $index => $mode) {
            foreach ([false, true] as $inProgress) {
                $number = 1 + $index * 2 + (int) $inProgress;
                $assessment = $this->studentBlitz($student, $mode, assessmentAttributes: [
                    'id' => sprintf('00000000-0000-4000-8000-%012d', $number),
                ]);
                if ($inProgress) {
                    $this->studentBlitzAttempt($assessment, $student);
                }
                $expected[] = $assessment->id;
            }
        }
        $older = $this->studentBlitz($student, blitzAttributes: ['activated_at' => now()->subHour()]);
        foreach (BlitzStatus::cases() as $status) {
            if ($status !== BlitzStatus::Active) {
                $this->studentBlitz($student, status: $status);
            }
        }
        $this->studentBlitz($student, assigned: false);
        $this->studentBlitz($this->studentBlitzActor($student->institution));
        $this->studentBlitz($this->studentBlitzActor());
        $this->studentBlitz($student, 'synchronized', blitzAttributes: [
            'activated_at' => now()->subMinutes(10), 'synchronized_ends_at' => now(),
        ]);
        $expired = $this->studentBlitz($student);
        $expiredAttempt = $this->studentBlitzAttempt($expired, $student, [
            'started_at' => now()->subMinutes(10), 'deadline_at' => now(),
        ]);
        $terminal = $this->studentBlitz($student);
        $this->terminateStudentBlitzAttempt($this->studentBlitzAttempt($terminal, $student));
        $before = $expiredAttempt->getAttributes();

        $response = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk();

        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertSame([...array_reverse($expected), $older->id], array_column($response->json('data'), 'id'));
        $this->assertStudentBlitzMetadataIsSecret($response);
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $expiredAttempt->fresh()->status);
        $this->assertTrue($expiredAttempt->deadline_at->equalTo($expiredAttempt->fresh()->finalized_at));
        $transitionFields = array_flip(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at']);
        $this->assertSame(array_diff_key($before, $transitionFields), array_diff_key($expiredAttempt->fresh()->getAttributes(), $transitionFields));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('timerModes')]
    public function test_detail_and_list_share_canonical_clock_and_never_expose_questions_before_start(string $mode): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $this->studentBlitzQuestions($assessment);
        $this->travelTo(Carbon::parse('2026-09-17T17:00:00.500000+05:00'));
        $expectedTiming = [
            'mode' => $mode, 'server_now' => '2026-09-17T12:00:00Z',
            'synchronized_ends_at' => $mode === 'synchronized' ? '2026-09-17T12:05:00Z' : null,
            'deadline_at' => $mode === 'synchronized' ? '2026-09-17T12:05:00Z' : null,
            'remaining_seconds' => $mode === 'synchronized' ? 300 : null,
        ];
        $expectedAttempts = ['normal_attempts' => 1, 'normal_used' => 0, 'in_progress_attempt_id' => null,
            'additional_exception_granted' => false, 'replacement_attempt_available' => false];
        $detail = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk();
        $this->assertSame([
            'id' => $assessment->id, 'topic' => ['id' => $assessment->topic_id, 'title' => $assessment->topic->title],
            'title' => 'Classroom Blitz', 'description' => 'Timed practice.', 'student_instructions' => 'Answer independently.',
            'status' => 'active', 'duration_seconds' => 600, 'total_possible_points' => 5,
            'timing' => $expectedTiming, 'attempts' => $expectedAttempts,
        ], $detail->json('data'));
        $this->assertSame(['data'], array_keys($detail->json()));
        $this->assertStudentBlitzMetadataIsSecret($detail);
        $list = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk();
        $this->assertSame($expectedTiming, $list->json('data.0.timing'));
        $this->assertSame($expectedAttempts, $list->json('data.0.attempts'));
        $this->assertSame(['id', 'topic', 'title', 'status', 'duration_seconds', 'timing', 'attempts'], array_keys($list->json('data.0')));
        $this->assertStudentBlitzMetadataIsSecret($list);
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    #[DataProvider('timerModes')]
    public function test_detail_uses_own_persisted_attempt_and_reconciles_before_rejecting_expiry(string $mode): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $attempt = $this->studentBlitzAttempt($assessment, $student);
        $otherAttempt = $this->studentBlitzAttempt($assessment, $this->studentBlitzActor($student->institution));
        $before = $attempt->getAttributes();
        $this->travelTo(Carbon::parse('2026-09-17T12:00:00.999999Z'));
        $response = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk()
            ->assertJsonPath('data.attempts.normal_used', 1)->assertJsonPath('data.attempts.in_progress_attempt_id', $attempt->id)
            ->assertJsonPath('data.timing.deadline_at', $attempt->deadline_at->format('Y-m-d\TH:i:s\Z'))
            ->assertJsonPath('data.timing.remaining_seconds', $mode === 'synchronized' ? 300 : 540);
        $this->assertStringNotContainsString($otherAttempt->id, $response->getContent());
        $this->travelTo($attempt->deadline_at);
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertConflict()
            ->assertJsonPath('code', 'blitz_time_expired')->assertJsonPath('message', 'The Blitz time has expired.');
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $attempt->fresh()->status);
        $this->assertTrue($attempt->deadline_at->equalTo($attempt->fresh()->finalized_at));
        $this->assertTrue($attempt->deadline_at->equalTo($attempt->fresh()->locked_at));
        $transitionFields = array_flip(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at']);
        $this->assertSame(array_diff_key($before, $transitionFields), array_diff_key($attempt->fresh()->getAttributes(), $transitionFields));
    }

    public function test_terminal_normal_attempt_remains_visible_in_active_detail_with_no_resume_capacity(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $this->terminateStudentBlitzAttempt($this->studentBlitzAttempt($assessment, $student));
        $response = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk()
            ->assertJsonPath('data.attempts.normal_used', 1)->assertJsonPath('data.attempts.in_progress_attempt_id', null)
            ->assertJsonPath('data.attempts.replacement_attempt_available', false);
        $this->assertStudentBlitzMetadataIsSecret($response);
    }

    public function test_detail_applies_recipient_privacy_before_lifecycle_and_never_uses_current_membership(): void
    {
        $student = $this->studentBlitzActor();
        foreach ([...array_map(fn (BlitzStatus $status) => $this->studentBlitz($student, status: $status, assigned: false)->id, BlitzStatus::cases()),
            $this->studentBlitz($this->studentBlitzActor($student->institution))->id,
            $this->studentBlitz($this->studentBlitzActor())->id, (string) Str::uuid(), 'malformed'] as $id) {
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$id)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        foreach (BlitzStatus::cases() as $status) {
            if ($status !== BlitzStatus::Active) {
                $assessment = $this->studentBlitz($student, status: $status);
                $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertConflict()
                    ->assertJsonPath('code', 'blitz_not_active')->assertJsonPath('message', 'This Blitz is not active.');
            }
        }
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    public function test_active_reads_reject_request_body_and_query_keys(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        foreach (['/api/v1/student/blitz/active', '/api/v1/student/blitz/'.$assessment->id] as $uri) {
            foreach (['{}', '[]', 'null', ' ', '{"server_now":"2000-01-01"}'] as $body) {
                $this->studentBlitzRequest($student, 'GET', $uri, $body)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            }
            $this->studentBlitzRequest($student, 'GET', $uri.'?page=1')->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
    }

    public function test_list_query_count_does_not_grow_per_blitz_and_never_loads_question_tables(): void
    {
        $student = $this->studentBlitzActor();
        $this->studentBlitz($student);
        DB::enableQueryLog();
        try {
            DB::flushQueryLog();
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk();
            $singleQueries = DB::getQueryLog();
            for ($index = 0; $index < 5; $index++) {
                $this->studentBlitz($student);
            }
            DB::flushQueryLog();
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk()->assertJsonCount(6, 'data');
            $manyQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }
        $this->assertSame(count($singleQueries), count($manyQueries));
        foreach ($manyQueries as $query) {
            $this->assertStringNotContainsString('"questions"', $query['query']);
            $this->assertStringNotContainsString('"question_choice_options"', $query['query']);
        }
    }

    #[DataProvider('corruptReadHistories')]
    public function test_corrupt_attempt_history_is_an_internal_conflict_without_repair(string $corruption): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $attempt = $this->studentBlitzAttempt($assessment, $student);
        $attempt->update(match ($corruption) {
            'unsupported attempt' => ['attempt_number' => 2],
            'deadline mismatch' => ['deadline_at' => now()->addHour()],
            'missing deadline' => ['deadline_at' => null],
            'in progress finalized' => ['finalized_at' => now()],
        });
        $before = $attempt->fresh()->getAttributes();
        $this->withoutExceptionHandling();
        try {
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id);
            $this->fail('Corrupt Blitz history cannot be projected as valid timing.');
        } catch (LogicException) {
            $this->assertSame($before, $attempt->fresh()->getAttributes());
            $this->assertDatabaseCount('assessment_attempts', 1);
        }
    }

    public static function timerModes(): array
    {
        return [['synchronized'], ['individual']];
    }

    #[DataProvider('fractionalHistoryFields')]
    public function test_fractional_timer_history_is_rejected_at_hydration_without_rounding_or_repair(string $field): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $field === 'synchronized_ends_at' ? 'synchronized' : 'individual');
        $attempt = $field === 'synchronized_ends_at' ? null : $this->studentBlitzAttempt($assessment, $student);
        $model = $field === 'synchronized_ends_at' ? BlitzTask::class : AssessmentAttempt::class;
        $targetId = $attempt?->id ?? $assessment->id;
        $injected = false;
        $dispatcher = $model::getEventDispatcher();
        $model::setEventDispatcher(clone $dispatcher);
        // PostgreSQL timestamp(0) prevents physical fractional storage; inject corrupt history at hydration.
        $model::retrieved(function ($row) use ($targetId, $field, &$injected): void {
            if ($row->getKey() === $targetId) {
                $attributes = $row->getAttributes();
                $attributes[$field] = Carbon::parse($attributes[$field])->addMicroseconds(500000)->format('Y-m-d H:i:s.uP');
                $row->setRawAttributes($attributes, true);
                $injected = true;
            }
        });
        $this->withoutExceptionHandling();
        try {
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id);
            $this->fail('Fractional persisted timer history cannot be silently rounded.');
        } catch (LogicException) {
            $this->assertTrue($injected);
            $this->assertDatabaseCount('idempotency_records', 0);
        } finally {
            $model::setEventDispatcher($dispatcher);
        }
        $stored = $model::query()->findOrFail($targetId);
        $this->assertSame('000000', $stored->{$field}->format('u'));
    }

    public static function fractionalHistoryFields(): array
    {
        return [['synchronized_ends_at'], ['started_at'], ['deadline_at']];
    }

    public static function corruptReadHistories(): array
    {
        return [['unsupported attempt'], ['deadline mismatch'], ['missing deadline'], ['in progress finalized']];
    }
}
