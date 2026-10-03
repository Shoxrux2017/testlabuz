<?php

namespace Tests\Feature\Results\Concerns;

use Illuminate\Support\Facades\DB;

/**
 * Real-concurrency races between two worker processes (tests/Support/LockRaceWorker.php): the first
 * pauses while it holds a chosen lock, the test proves that the second really waits on that lock in
 * PostgreSQL, then releases the first. Fixtures must be committed (DatabaseTruncation).
 */
trait RunsLockRaceWorkers
{
    /**
     * @param  array<string, mixed>  $holder  Input of the worker that holds `hold` = {table, lock}
     * @param  array<string, mixed>  $waiter  Input of the worker that must wait
     * @return array{0: array<string, mixed>, 1: array<string, mixed>|null}
     */
    protected function lockRace(array $holder, array $waiter, string $waitingOn): array
    {
        $first = $this->startRaceWorker($holder);
        $second = null;
        try {
            $this->assertSame('held', $this->raceWorkerMessage($first)['event']);
            $second = $this->startRaceWorker($waiter);
            $this->assertWaitsOn($second['pid'], $first['pid'], $waitingOn);
        } finally {
            fwrite($first['pipes'][0], "release\n");
            fflush($first['pipes'][0]);
            $firstResult = $this->finishRaceWorker($first);
            $secondResult = $second === null ? null : $this->finishRaceWorker($second);
        }

        return [$firstResult, $secondResult];
    }

    /** @return array<string, mixed> */
    protected function raceInput(string $operation, array $input): array
    {
        return ['operation' => $operation, 'now' => now()->format('Y-m-d H:i:s.uP'), ...$input];
    }

    private function assertWaitsOn(int $waitingPid, int $holdingPid, string $table): void
    {
        $deadline = microtime(true) + 10;
        do {
            DB::select('SELECT pg_stat_clear_snapshot()');
            $activity = DB::selectOne('SELECT wait_event_type, query, ? = ANY(pg_blocking_pids(pid)) AS blocked FROM pg_stat_activity WHERE pid = ?',
                [$holdingPid, $waitingPid]);
            if ($activity !== null && $activity->wait_event_type === 'Lock' && $activity->blocked) {
                $this->assertStringContainsString('from "'.$table.'"', $activity->query);

                return;
            }
            usleep(5_000); // Polls the observed PostgreSQL lock state, never an elapsed-time ordering.
        } while (microtime(true) < $deadline);
        $this->fail('The second operation did not wait on the first one\'s lock: '.json_encode($activity));
    }

    /** @param array<string, mixed> $input */
    private function startRaceWorker(array $input): array
    {
        $environment = getenv();
        foreach (['APP_ENV' => 'testing', 'DB_CONNECTION' => 'pgsql', 'DB_DATABASE' => 'testlabuz_testing',
            'DB_HOST' => 'postgres', 'DB_PORT' => '5432', 'DB_USERNAME' => 'testlabuz', 'CACHE_STORE' => 'array',
            'SESSION_DRIVER' => 'array'] as $key => $value) {
            $environment[$key] = $value;
        }
        $process = proc_open([PHP_BINARY, base_path('tests/Support/LockRaceWorker.php'), json_encode($input, JSON_THROW_ON_ERROR)],
            [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $environment);
        $this->assertIsResource($process);
        $worker = ['process' => $process, 'pipes' => $pipes];
        $started = $this->raceWorkerMessage($worker);
        $this->assertSame('started', $started['event']);
        $worker['pid'] = $started['pid'];

        return $worker;
    }

    /** @return array<string, mixed> */
    private function raceWorkerMessage(array $worker): array
    {
        $read = [$worker['pipes'][1]];
        $write = $except = [];
        $this->assertSame(1, stream_select($read, $write, $except, 15), 'The race worker did not reach its barrier.');
        $line = fgets($worker['pipes'][1]);
        $message = $line === false ? null : json_decode($line, true);
        if (! is_array($message)) {
            $this->fail('The race worker sent no message: '.($line === false ? '' : $line).stream_get_contents($worker['pipes'][2]));
        }

        return $message;
    }

    /** @return array<string, mixed> */
    private function finishRaceWorker(array $worker): array
    {
        try {
            $result = $this->raceWorkerMessage($worker);
            $errors = stream_get_contents($worker['pipes'][2]);
        } finally {
            foreach ($worker['pipes'] as $pipe) {
                fclose($pipe);
            }
            $exit = proc_close($worker['process']);
        }
        $this->assertSame(0, $exit, $errors ?? 'The race worker failed.');
        $this->assertSame('result', $result['event']);

        return $result;
    }
}
