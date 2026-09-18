<?php

namespace Tests\Feature\Teacher;

use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzMonitoringContext;
use Tests\TestCase;

class TeacherBlitzMonitoringTimeoutReconciliationTest extends TestCase
{
    use BuildsTeacherBlitzMonitoringContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('dueAttempts')]
    public function test_due_normal_and_replacement_attempts_finalize_at_exact_deadline_without_repeated_churn(string $mode, bool $replacement): void
    {
        if ($replacement) {
            [$student, $assessment, , $teacher, $attempt] = $this->replacementContext($mode);
        } else {
            [$student, $assessment, $teacher] = $this->monitoringContext($mode);
            $attempt = $this->studentBlitzAttempt($assessment, $student);
        }
        $neverStarted = $this->studentBlitzActor($student->institution);
        $this->blitzRecipient($assessment, $neverStarted, $teacher);
        $this->travelTo($attempt->deadline_at);
        $beforeTask = $assessment->blitzTask->getAttributes();
        $response = $this->monitor($teacher, $assessment)->assertOk();
        $row = collect($response->json('data.students'))->firstWhere('student.id', $student->id);
        $this->assertSame('finalized', $row['status']);
        $this->assertSame('timeout_auto_submit', $row['finalization_reason']);
        $this->assertSame(0, $row['remaining_seconds']);
        $this->assertMonitoringPartition($response);
        $terminal = $attempt->fresh();
        $this->assertTrue($terminal->finalized_at->equalTo($attempt->deadline_at));
        $this->assertTrue($terminal->locked_at->equalTo($attempt->deadline_at));
        $this->assertNull($terminal->submitted_at);
        $this->travelTo(now()->addMinute());
        $this->monitor($teacher, $assessment)->assertOk();
        $this->assertSame($terminal->getAttributes(), $attempt->fresh()->getAttributes());
        $this->assertSame($beforeTask, $assessment->blitzTask->fresh()->getAttributes());
        $this->assertDatabaseMissing('assessment_attempts', ['student_id' => $neverStarted->id]);
    }

    public static function dueAttempts(): array
    {
        return [['synchronized', false], ['individual', false], ['synchronized', true], ['individual', true]];
    }

    public function test_mixed_due_future_terminal_and_never_started_students_share_one_response_clock(): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        $due = $this->studentBlitzAttempt($assessment, $student, ['started_at' => now()->subMinutes(10), 'deadline_at' => now()]);
        $futureStudent = $this->studentBlitzActor($student->institution);
        $future = $this->studentBlitzAttempt($assessment, $futureStudent);
        $terminalStudent = $this->studentBlitzActor($student->institution);
        $terminal = $this->studentBlitzAttempt($assessment, $terminalStudent);
        $this->terminateStudentBlitzAttempt($terminal);
        $never = $this->studentBlitzActor($student->institution);
        $this->blitzRecipient($assessment, $never, $teacher);
        $response = $this->monitor($teacher, $assessment)->assertOk()->assertJsonPath('data.summary', [
            'assigned' => 4, 'not_started' => 1, 'in_progress' => 1, 'finalized' => 2,
            'waiting_for_teacher_review' => 0, 'attempt_exceptions_granted' => 0,
        ]);
        $this->assertMonitoringPartition($response);
        $this->assertSame('timed_out_finalized', $due->fresh()->status->value);
        $this->assertSame('in_progress', $future->fresh()->status->value);
        $row = collect($response->json('data.students'))->firstWhere('student.id', $futureStudent->id);
        $this->assertSame(540, $row['remaining_seconds']);
    }

    #[DataProvider('deadlineBoundaries')]
    public function test_crossing_deadline_after_reconciliation_rebuilds_a_read_only_snapshot(string $clock, bool $due): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        $attempt = $this->studentBlitzAttempt($assessment, $student, [
            'started_at' => '2026-09-17 11:51:00', 'deadline_at' => '2026-09-17 12:01:00',
        ]);
        $this->travelTo(Carbon::parse('2026-09-17 12:00:59 UTC'));
        $snapshots = 0;
        $writes = 0;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$snapshots, &$writes, $clock): void {
            if (str_starts_with($query->sql, 'SET TRANSACTION')) {
                $snapshots++;
                $this->travelTo(Carbon::parse($clock));
            }
            if (str_starts_with($query->sql, 'update "assessment_attempts"')) {
                $writes++;
                $this->assertSame('off', DB::selectOne("SELECT current_setting('transaction_read_only') AS readonly")->readonly);
            }
        });
        try {
            $response = $this->monitor($teacher, $assessment)->assertOk();
            $response->assertJsonPath('data.blitz.timing.server_now', $due ? '2026-09-17T12:01:00Z' : '2026-09-17T12:00:59Z')
                ->assertJsonPath('data.students.0.status', $due ? 'finalized' : 'in_progress')
                ->assertJsonPath('data.students.0.remaining_seconds', $due ? 0 : 1);
            $this->assertSame($due ? 2 : 1, $snapshots);
            $this->assertSame($due ? 1 : 0, $writes);
            if ($due) {
                $this->assertTrue($attempt->fresh()->finalized_at->equalTo($attempt->deadline_at));
            }
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
    }

    public static function deadlineBoundaries(): array
    {
        return [['2026-09-17 12:01:00 UTC', true], ['2026-09-17 12:00:59.999999 UTC', false],
            ['2026-09-17 12:01:00.000001 UTC', true]];
    }

    public function test_later_clock_changes_do_not_change_rows_from_the_established_snapshot(): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext('synchronized');
        $this->studentBlitzAttempt($assessment, $student);
        $captured = false;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$captured): void {
            if (! $captured && str_contains($query->sql, 'AS snapshot_at')) {
                $captured = true;
                $this->travelTo(now()->addHour());
            }
        });
        try {
            $this->monitor($teacher, $assessment)->assertOk()->assertJsonPath('data.blitz.timing.server_now', '2026-09-17T12:00:00Z')
                ->assertJsonPath('data.students.0.status', 'in_progress')->assertJsonPath('data.students.0.remaining_seconds', 300);
            $this->assertTrue($captured);
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
    }

    public function test_reconciliation_without_progress_fails_instead_of_looping(): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        $attempt = $this->studentBlitzAttempt($assessment, $student);
        $this->travelTo($attempt->deadline_at->copy()->subSecond());
        $snapshots = 0;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$snapshots, $attempt): void {
            if (str_starts_with($query->sql, 'SET TRANSACTION')) {
                $snapshots++;
                $this->travelTo($attempt->deadline_at);
            }
            if (str_contains($query->sql, 'AS snapshot_at')) {
                $this->travelTo($attempt->deadline_at->copy()->subSecond());
            }
        });
        $this->withoutExceptionHandling();
        try {
            $this->monitor($teacher, $assessment);
            $this->fail('Repeated due Attempt must fail internally.');
        } catch (LogicException $exception) {
            $this->assertSame('Blitz timeout reconciliation made no progress between final snapshots.', $exception->getMessage());
            $this->assertSame(2, $snapshots);
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
        $this->assertSame(0, DB::transactionLevel());
    }
}
