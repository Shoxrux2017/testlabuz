<?php

namespace Tests\Feature\Teacher;

use App\Support\Student\StudentBlitzReadSnapshot;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\RunsBlitzExceptionWorkers;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzMonitoringContext;
use Tests\TestCase;

class TeacherBlitzMonitoringConcurrencyTest extends TestCase
{
    use BuildsTeacherBlitzMonitoringContext, RunsBlitzExceptionWorkers, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('interQueryMutations')]
    public function test_concurrent_commit_between_selects_cannot_create_a_hybrid_graph(string $operation, bool $beforeSnapshot): void
    {
        $context = $this->exceptionContext(terminal: in_array($operation, ['grant', 'start_replacement'], true));
        [$student, $assessment, $normal, $teacher] = $context;
        if ($operation === 'start_normal') {
            $normal->delete();
        } elseif ($operation === 'start_replacement') {
            $this->grantException($teacher, $assessment, $student)->assertCreated();
        }
        $worker = $this->startExceptionWorker($this->workerInput($context, $operation, ['wait' => true]));
        $committed = false;
        $snapshots = 0;
        $snapshotQueries = [];
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$committed, &$snapshots, &$snapshotQueries, $operation, $beforeSnapshot, $worker): void {
            if (str_contains($query->sql, 'AS snapshot_at')) {
                $snapshots++;
                $state = DB::selectOne("SELECT current_setting('transaction_isolation') AS isolation, current_setting('transaction_read_only') AS readonly");
                $this->assertSame('repeatable read', $state->isolation);
                $this->assertSame('on', $state->readonly);
            }
            if ($snapshots > 0) {
                $snapshotQueries[] = $query->sql;
                $this->assertSame(DB::connection(), $query->connection);
                $this->assertDoesNotMatchRegularExpression('/\bfor\s+(?:no\s+key\s+update|key\s+share|update|share)\b/i', $query->sql);
                $this->assertDoesNotMatchRegularExpression('/^(?:insert|update|delete)\b/i', $query->sql);
            }
            $boundary = $beforeSnapshot ? str_starts_with($query->sql, 'SET TRANSACTION')
                : ($snapshots === 1 && str_starts_with($query->sql, 'select ')
                    && str_contains($query->sql, $operation === 'close' ? 'from "blitz_tasks"' : 'from "assessment_attempts"'));
            if (! $committed && $boundary) {
                $committed = true;
                $this->releaseExceptionWorker($worker, 'run');
                $this->assertSame('ok', $this->finishExceptionWorker($worker)['outcome']);
            }
        });
        try {
            $response = $this->monitor($teacher, $assessment);
            $this->assertTrue($committed);
            $this->assertSame(1, $snapshots);
            if ($beforeSnapshot && $operation === 'close') {
                $response->assertConflict()->assertJsonPath('code', 'task_closed');
            } else {
                $response->assertOk()->assertJsonPath('data.blitz.status', 'active');
                $this->assertMonitoringPartition($response);
                $expectedStatus = $beforeSnapshot
                    ? match ($operation) {
                        'submit' => 'finalized', 'grant' => 'not_started', default => 'in_progress'
                    }
                : match ($operation) {
                    'start_normal', 'start_replacement' => 'not_started', 'grant' => 'finalized', default => 'in_progress'
                };
                $response->assertJsonPath('data.students.0.status', $expectedStatus);
                if ($operation === 'start_replacement' || ($operation === 'grant' && $beforeSnapshot)) {
                    $response->assertJsonPath('data.students.0.attempt_exception.replacement_attempt_available', ! $beforeSnapshot || $operation === 'grant')
                        ->assertJsonPath('data.students.0.attempt_number', $operation === 'start_replacement' && $beforeSnapshot ? 2 : null);
                    if ($operation === 'start_replacement' && $beforeSnapshot) {
                        $this->assertNotNull($response->json('data.students.0.attempt_exception.replacement_attempt_id'));
                    } else {
                        $response->assertJsonPath('data.students.0.attempt_exception.replacement_attempt_id', null);
                    }
                } else {
                    $response->assertJsonPath('data.students.0.attempt_exception', null);
                }
            }
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
            if (! $committed) {
                $this->releaseExceptionWorker($worker, 'run');
                $this->finishExceptionWorker($worker);
            }
        }
        $next = $this->monitor($teacher, $assessment);
        if ($operation === 'close') {
            $next->assertConflict()->assertJsonPath('code', 'task_closed');
        } else {
            $next->assertOk()->assertJsonPath('data.students.0.status', match ($operation) {
                'submit' => 'finalized', 'grant' => 'not_started', default => 'in_progress',
            });
            $this->assertMonitoringPartition($next);
        }
        $this->assertNotEmpty($snapshotQueries);
    }

    public static function interQueryMutations(): array
    {
        $cases = [];
        foreach (['start_normal', 'submit', 'grant', 'start_replacement', 'close'] as $operation) {
            $cases[] = [$operation, false];
            $cases[] = [$operation, true];
        }

        return $cases;
    }

    public function test_production_clock_is_captured_by_first_select_on_the_read_only_snapshot_connection(): void
    {
        [, $assessment, $teacher] = $this->monitoringContext();
        $this->app->instance(StudentBlitzReadSnapshot::class, new StudentBlitzReadSnapshot);
        $before = Carbon::parse(DB::selectOne("SELECT date_trunc('second', clock_timestamp()) AS instant")->instant);
        $inside = false;
        $queries = [];
        $dispatcher = DB::connection()->getEventDispatcher();
        DB::connection()->setEventDispatcher(clone $dispatcher);
        DB::listen(function (QueryExecuted $query) use (&$inside, &$queries): void {
            if (str_starts_with($query->sql, 'SET TRANSACTION')) {
                $inside = true;
            } elseif ($inside) {
                $queries[] = $query->sql;
            }
        });
        try {
            $response = $this->monitor($teacher, $assessment)->assertOk();
        } finally {
            DB::connection()->setEventDispatcher($dispatcher);
        }
        $after = Carbon::parse(DB::selectOne("SELECT date_trunc('second', clock_timestamp()) AS instant")->instant);
        $this->assertSame("SELECT date_trunc('second', clock_timestamp()) AS snapshot_at", $queries[0]);
        $clock = $response->json('data.blitz.timing.server_now');
        $this->assertMatchesRegularExpression('/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/', $clock);
        $this->assertTrue(Carbon::parse($clock)->betweenIncluded($before, $after));
        $this->assertSame(0, DB::transactionLevel());
    }
}
