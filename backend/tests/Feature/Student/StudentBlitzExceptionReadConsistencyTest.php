<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\BlitzAttemptException;
use App\Support\Student\StudentBlitzReadSnapshot;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\Feature\Student\Concerns\RevertsBlitzAttemptConcurrently;
use Tests\Feature\Student\Concerns\RunsBlitzExceptionWorkers;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

class StudentBlitzExceptionReadConsistencyTest extends TestCase
{
    use BuildsBlitzExceptionContext, RevertsBlitzAttemptConcurrently, RunsBlitzExceptionWorkers, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('interQueryCommits')]
    public function test_commits_between_final_selects_produce_one_complete_old_snapshot(string $operation, bool $list): void
    {
        $context = $this->exceptionContext('synchronized');
        [$student, $assessment, $normal, $teacher] = $context;
        if ($operation !== 'grant') {
            $this->grantException($teacher, $assessment, $student)->assertCreated();
        }
        if ($list && $operation === 'grant') {
            // The terminal target is absent before Grant; another eligible parent drives the batched SELECTs.
            $this->studentBlitz($student);
        }
        $worker = $this->startExceptionWorker($this->workerInput($context, $operation, ['wait' => true]));
        $committed = false;
        $snapshots = 0;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$committed, &$snapshots, $operation, $worker): void {
            if (str_contains($query->sql, 'AS snapshot_at')) {
                $snapshots++;
                $state = DB::selectOne("SELECT current_setting('transaction_isolation') AS isolation, current_setting('transaction_read_only') AS readonly");
                $this->assertSame('repeatable read', $state->isolation);
                $this->assertSame('on', $state->readonly);
            }
            $boundary = $operation === 'close' ? 'from "assessments" inner join' : 'from "assessment_attempts"';
            if (! $committed && $snapshots === 1 && str_starts_with($query->sql, 'select ') && str_contains($query->sql, $boundary)) {
                $committed = true;
                $this->releaseExceptionWorker($worker, 'run');
                $this->assertSame('ok', $this->finishExceptionWorker($worker)['outcome']);
            }
        });
        try {
            $uri = '/api/v1/student/blitz/'.($list ? 'active' : $assessment->id);
            $response = $this->studentBlitzRequest($student, 'GET', $uri)->assertOk();
            $this->assertTrue($committed);
            $this->assertSame(1, $snapshots);
            $projection = $list ? collect($response->json('data'))->firstWhere('id', $assessment->id) : $response->json('data');
            if ($list && $operation === 'grant') {
                $this->assertNull($projection);
            } else {
                $this->assertSame($operation !== 'grant', $projection['attempts']['additional_exception_granted']);
                $this->assertSame($operation !== 'grant', $projection['attempts']['replacement_attempt_available']);
                $this->assertNull($projection['attempts']['in_progress_attempt_id']);
            }
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
            if (! $committed) {
                $this->releaseExceptionWorker($worker, 'run');
                $this->finishExceptionWorker($worker);
            }
        }
        if ($operation === 'close') {
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertConflict()->assertJsonPath('code', 'blitz_not_active');
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk()->assertJsonCount(0, 'data');
        } else {
            $replacement = AssessmentAttempt::query()->where('assessment_id', $assessment->id)->where('attempt_number', 2)->first();
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk()
                ->assertJsonPath('data.attempts.additional_exception_granted', true)
                ->assertJsonPath('data.attempts.replacement_attempt_available', $operation === 'grant')
                ->assertJsonPath('data.attempts.in_progress_attempt_id', $replacement?->id);
            $this->assertFalse($normal->fresh()->official_score_eligible);
            $this->assertSame($replacement?->id, BlitzAttemptException::query()->sole()->replacement_attempt_id);
        }
    }

    public static function interQueryCommits(): array
    {
        return [['grant', false], ['grant', true], ['start_replacement', false], ['start_replacement', true], ['close', false], ['close', true]];
    }

    #[DataProvider('readPaths')]
    public function test_close_before_final_snapshot_is_observed_in_the_current_response(bool $list): void
    {
        $context = $this->exceptionContext();
        [$student, $assessment] = $context;
        $worker = $this->startExceptionWorker($this->workerInput($context, 'close', ['wait' => true]));
        $closed = false;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$closed, $worker): void {
            if (! $closed && str_starts_with($query->sql, 'SET TRANSACTION')) {
                $closed = true;
                $this->releaseExceptionWorker($worker, 'run');
                $this->assertSame('ok', $this->finishExceptionWorker($worker)['outcome']);
            }
        });
        try {
            $response = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.($list ? 'active' : $assessment->id));
            $list ? $response->assertOk()->assertJsonCount(0, 'data') : $response->assertConflict()->assertJsonPath('code', 'blitz_not_active');
            $this->assertTrue($closed);
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
            if (! $closed) {
                $this->releaseExceptionWorker($worker, 'run');
                $this->finishExceptionWorker($worker);
            }
        }
    }

    #[DataProvider('readPaths')]
    public function test_crossing_deadline_after_preliminary_reconciliation_discards_and_rebuilds_snapshot(bool $list): void
    {
        [$student, $assessment, , , $replacement] = $this->replacementContext();
        $this->travelTo($replacement->deadline_at->copy()->subSecond());
        $snapshots = 0;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$snapshots, $replacement): void {
            if (str_starts_with($query->sql, 'SET TRANSACTION')) {
                $snapshots++;
                $this->travelTo($replacement->deadline_at);
            }
            if (str_starts_with($query->sql, 'update "assessment_attempts"')) {
                $this->assertSame('off', DB::selectOne("SELECT current_setting('transaction_read_only') AS readonly")->readonly);
            }
        });
        try {
            $response = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.($list ? 'active' : $assessment->id));
            $list ? $response->assertOk()->assertJsonCount(0, 'data') : $response->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
            $this->assertSame(2, $snapshots);
            $this->assertSame('timeout_auto_submit', $replacement->fresh()->finalization_reason->value);
            $this->assertTrue($replacement->deadline_at->equalTo($replacement->fresh()->finalized_at));
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
    }

    #[DataProvider('readPaths')]
    public function test_one_snapshot_clock_drives_timing_even_when_wall_time_moves_during_later_selects(bool $list): void
    {
        [$student, $assessment, , , $replacement] = $this->replacementContext();
        $this->travelTo($replacement->deadline_at->copy()->subSecond()->addMicroseconds(999999));
        $expected = now()->startOfSecond()->format('Y-m-d\TH:i:s\Z');
        $captured = false;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$captured, $replacement): void {
            if (! $captured && str_contains($query->sql, 'AS snapshot_at')) {
                $captured = true;
                $this->travelTo($replacement->deadline_at->copy()->addHour());
            }
        });
        try {
            $prefix = $list ? 'data.0' : 'data';
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.($list ? 'active' : $assessment->id))->assertOk()
                ->assertJsonPath($prefix.'.timing.server_now', $expected)
                ->assertJsonPath($prefix.'.timing.remaining_seconds', 1)
                ->assertJsonPath($prefix.'.attempts.in_progress_attempt_id', $replacement->id);
            $this->assertTrue($captured);
            $this->assertSame('in_progress', $replacement->fresh()->status->value);
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
    }

    public static function readPaths(): array
    {
        return [[false], [true]];
    }

    public function test_production_snapshot_uses_postgresql_whole_second_clock_and_read_only_isolation(): void
    {
        $snapshot = new StudentBlitzReadSnapshot;
        $before = DB::selectOne("SELECT date_trunc('second', clock_timestamp()) AS instant")->instant;
        $result = $snapshot->read(function ($at): array {
            $state = DB::selectOne("SELECT current_setting('transaction_isolation') AS isolation, current_setting('transaction_read_only') AS readonly");

            return [$at, $state];
        });
        $after = DB::selectOne("SELECT date_trunc('second', clock_timestamp()) AS instant")->instant;
        $this->assertTrue($result[0]->betweenIncluded(Carbon::parse($before), Carbon::parse($after)));
        $this->assertSame('000000', $result[0]->format('u'));
        $this->assertSame('repeatable read', $result[1]->isolation);
        $this->assertSame('on', $result[1]->readonly);
        $this->assertSame(0, DB::transactionLevel());
    }

    #[DataProvider('readPaths')]
    public function test_database_clock_ahead_of_app_clock_at_deadline_reconciles_at_the_snapshot_instant(bool $list): void
    {
        [$student, $assessment, , , $replacement] = $this->replacementContext();
        $this->travelTo($replacement->deadline_at->copy()->subSecond());
        $snapshots = 0;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$snapshots, $replacement): void {
            if (str_starts_with($query->sql, 'SET TRANSACTION')) {
                $snapshots++;
                $this->travelTo($replacement->deadline_at);
            }
            if (str_contains($query->sql, 'AS snapshot_at')) {
                // The database clock observed the deadline; the app clock is still one second behind.
                $this->travelTo($replacement->deadline_at->copy()->subSecond());
            }
        });
        try {
            $response = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.($list ? 'active' : $assessment->id));
            $list ? $response->assertOk()->assertJsonCount(0, 'data') : $response->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
            $this->assertSame(2, $snapshots);
            $finalized = $replacement->fresh();
            $this->assertSame('timeout_auto_submit', $finalized->finalization_reason->value);
            $this->assertTrue($replacement->deadline_at->equalTo($finalized->finalized_at));
            $this->assertTrue($replacement->deadline_at->equalTo($finalized->locked_at));
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
    }

    public function test_repeated_due_attempt_after_reconciliation_fails_instead_of_looping(): void
    {
        [$student, $assessment, , , $replacement] = $this->replacementContext();
        $this->travelTo($replacement->deadline_at->copy()->subSecond());
        $snapshots = 0;
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$snapshots, $replacement): void {
            if (str_starts_with($query->sql, 'SET TRANSACTION')) {
                $snapshots++;
                $this->travelTo($replacement->deadline_at);
                if ($snapshots === 2) {
                    $this->revertAttemptToInProgressConcurrently($replacement);
                }
            }
        });
        $this->withoutExceptionHandling();
        try {
            $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id);
            $this->fail('No-progress loop must fail.');
        } catch (LogicException $exception) {
            $this->assertSame('Blitz timeout reconciliation made no progress between final snapshots.', $exception->getMessage());
            $this->assertSame(2, $snapshots);
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
    }
}
