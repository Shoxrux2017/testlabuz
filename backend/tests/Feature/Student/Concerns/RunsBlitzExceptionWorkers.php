<?php

namespace Tests\Feature\Student\Concerns;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

trait RunsBlitzExceptionWorkers
{
    protected function workerInput(array $context, string $operation, array $overrides = []): array
    {
        [$student, $assessment, $normal, $teacher] = $context;

        return array_replace(['student' => $student->id, 'teacher' => $teacher->id, 'assessment' => $assessment->id,
            'attempt' => $normal->id, 'operation' => $operation, 'key' => (string) Str::uuid(),
            'now' => now()->format('Y-m-d H:i:s.uP')], $overrides);
    }

    protected function startExceptionWorker(array $input): array
    {
        $environment = getenv();
        foreach (['APP_ENV' => 'testing', 'DB_CONNECTION' => 'pgsql', 'DB_DATABASE' => 'testlabuz_testing',
            'DB_HOST' => 'postgres', 'DB_PORT' => '5432', 'DB_USERNAME' => 'testlabuz', 'CACHE_STORE' => 'array',
            'SESSION_DRIVER' => 'array'] as $key => $value) {
            $environment[$key] = $value;
        }
        $process = proc_open([PHP_BINARY, base_path('tests/Support/BlitzExceptionWorker.php'), json_encode($input, JSON_THROW_ON_ERROR)],
            [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $environment);
        $this->assertIsResource($process);
        $worker = ['process' => $process, 'pipes' => $pipes];
        $started = $this->workerMessage($worker);
        $this->assertSame('started', $started['event']);
        $worker['pid'] = $started['pid'];

        return $worker;
    }

    protected function workerMessage(array $worker): array
    {
        $read = [$worker['pipes'][1]];
        $write = $except = [];
        $this->assertSame(1, stream_select($read, $write, $except, 15), 'Worker did not reach its deterministic barrier.');
        $line = fgets($worker['pipes'][1]);
        if ($line === false) {
            $this->fail('Worker ended without a result: '.stream_get_contents($worker['pipes'][2]));
        }

        return json_decode($line, true, flags: JSON_THROW_ON_ERROR);
    }

    protected function releaseExceptionWorker(array $worker, string $message): void
    {
        fwrite($worker['pipes'][0], $message."\n");
        fflush($worker['pipes'][0]);
    }

    protected function finishExceptionWorker(array $worker): array
    {
        try {
            $result = $this->workerMessage($worker);
            $this->assertSame('result', $result['event']);
            $errors = stream_get_contents($worker['pipes'][2]);
        } finally {
            foreach ($worker['pipes'] as $pipe) {
                fclose($pipe);
            }
            $exit = proc_close($worker['process']);
        }
        $this->assertSame(0, $exit, $errors ?? 'Worker failed.');

        return $result;
    }

    protected function exceptionRace(array $firstInput, array $secondInput): array
    {
        $first = $this->startExceptionWorker($firstInput + ['hold' => true]);
        $second = null;
        try {
            $this->assertSame('held', $this->workerMessage($first)['event']);
            $second = $this->startExceptionWorker($secondInput);
            $deadline = microtime(true) + 10;
            do {
                DB::select('SELECT pg_stat_clear_snapshot()');
                $blocked = DB::selectOne('SELECT ? = ANY(pg_blocking_pids(?)) AS blocked', [$first['pid'], $second['pid']])->blocked;
                if ($blocked) {
                    break;
                }
                usleep(5000); // Poll the observed PostgreSQL lock condition, never elapsed-time race ordering.
            } while (microtime(true) < $deadline);
            $this->assertTrue($blocked, 'Competing operation must actually wait on the first transaction.');
        } finally {
            $this->releaseExceptionWorker($first, 'commit');
            $firstResult = $this->finishExceptionWorker($first);
            $secondResult = $second === null ? null : $this->finishExceptionWorker($second);
        }

        return [$firstResult, $secondResult];
    }
}
