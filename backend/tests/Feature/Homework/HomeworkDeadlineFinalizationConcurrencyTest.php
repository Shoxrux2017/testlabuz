<?php

namespace Tests\Feature\Homework;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class HomeworkDeadlineFinalizationConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_postgresql_serializes_deadline_and_close_and_retains_attempt_locks_until_commit(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's07_be_002_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach ([
                'deadline_close' => ['deadline', 'close'],
                'close_deadline' => ['close', 'deadline'],
                'deadline_probe' => ['deadline', 'probe'],
                'close_probe' => ['close', 'probe'],
                'early_close_deadline' => ['close', 'deadline'],
            ] as $scenario => [$firstOperation, $secondOperation]) {
                $results = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $first = $results['first'];
                $second = $results['second'];
                $earlyClose = $scenario === 'early_close_deadline';

                $this->assertSame('submitted', $second['attempt']['status'], $scenario);
                $this->assertNull($second['attempt']['submitted_at'], $scenario);
                $this->assertSame($earlyClose ? 'task_closed_auto_finalize' : 'homework_deadline_auto_submit', $second['attempt']['finalization_reason'], $scenario);
                $this->assertSame($earlyClose ? '2026-09-09 09:59:59+00' : '2026-09-09 10:00:00+00', $second['attempt']['finalized_at'], $scenario);
                $this->assertSame($second['attempt']['finalized_at'], $second['attempt']['locked_at'], $scenario);
                $this->assertSame($first['attempt'], $second['attempt'], $scenario.' terminal transition must not be rewritten');
                $this->assertSame($scenario === 'deadline_probe' ? 'active' : 'closed', $second['homework_status'], $scenario);
                $this->assertSame(1, $second['attempt_count'], $scenario);

                if ($firstOperation === 'deadline') {
                    $this->assertSame(1, $first['finalized_count'], $scenario);
                }
                if ($secondOperation === 'deadline') {
                    $this->assertSame(0, $second['finalized_count'], $scenario);
                }
                if ($secondOperation === 'probe') {
                    $this->assertSame($first['attempt'], $second['probe_snapshot'], $scenario.' probe sees committed terminal state');
                }
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(string $workerPath, array $ids, string $scenario, string $firstOperation, string $secondOperation): array
    {
        $lockedPath = $this->unusedTempPath('s07_be_002_locked_');
        $releasePath = $this->unusedTempPath('s07_be_002_release_');
        $startedPath = $this->unusedTempPath('s07_be_002_started_');
        $arguments = [$ids['institution'], $ids['teacher'], $ids['assessments'][$scenario]];
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation, 'hold',
            $lockedPath, $releasePath, $startedPath.'.first',
            $scenario === 'early_close_deadline' ? '2026-09-09 09:59:59 UTC' : '2026-09-09 10:03:00 UTC',
        ]);
        $second = null;

        try {
            $this->waitForFile($lockedPath, 'The finalization worker did not reach the terminal write inside its transaction.');
            $firstBackendPid = (int) file_get_contents($lockedPath);
            $second = $this->startWorker([
                $workerPath, base_path(), 'run', ...$arguments, $secondOperation, 'normal',
                $lockedPath, $releasePath, $startedPath, '2026-09-09 10:04:00 UTC',
            ]);
            $this->waitForFile($startedPath, 'The second worker did not begin.');
            $this->waitForPostgresLock((int) file_get_contents($startedPath), $firstBackendPid, $secondOperation === 'probe');
        } finally {
            file_put_contents($releasePath, 'release');
            try {
                $firstOutput = $this->finishWorker($first);
                $secondOutput = $second === null ? null : $this->finishWorker($second);
            } finally {
                foreach ([$lockedPath, $releasePath, $startedPath, $startedPath.'.first'] as $path) {
                    if (file_exists($path)) {
                        unlink($path);
                    }
                }
            }
        }

        return [
            'first' => json_decode($firstOutput, true, flags: JSON_THROW_ON_ERROR),
            'second' => json_decode($secondOutput, true, flags: JSON_THROW_ON_ERROR),
        ];
    }

    private function unusedTempPath(string $prefix): string
    {
        $path = tempnam(sys_get_temp_dir(), $prefix);
        $this->assertIsString($path);
        unlink($path);

        return $path;
    }

    private function waitForFile(string $path, string $message): void
    {
        $deadline = microtime(true) + 10;

        do {
            clearstatcache(true, $path);
            if (file_exists($path) && filesize($path) > 0) {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail($message);
    }

    private function waitForPostgresLock(int $waitingPid, int $holdingPid, bool $attemptProbe): void
    {
        $deadline = microtime(true) + 10;
        $activity = null;

        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne(
                'select wait_event_type, query, ? = any(pg_blocking_pids(pid)) as blocked_by_finalizer from pg_stat_activity where pid = ?',
                [$holdingPid, $waitingPid],
            );
            if ($activity !== null && $activity->wait_event_type === 'Lock' && $activity->blocked_by_finalizer) {
                if ($attemptProbe) {
                    $this->assertStringContainsString('"assessment_attempts"', $activity->query);
                    $this->assertStringContainsString('for update', $activity->query);
                }

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('The second worker never waited on the finalization transaction: '.json_encode($activity));
    }

    /** @return array{process: resource, pipes: array<int, resource>} */
    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open([PHP_BINARY, ...$arguments], [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);
        $this->assertIsResource($process);
        fclose($pipes[0]);

        return ['process' => $process, 'pipes' => $pipes];
    }

    private function finishWorker(array $worker): string
    {
        $stdout = stream_get_contents($worker['pipes'][1]);
        $stderr = stream_get_contents($worker['pipes'][2]);
        fclose($worker['pipes'][1]);
        fclose($worker['pipes'][2]);
        $exitCode = proc_close($worker['process']);
        $this->assertSame(0, $exitCode, $stderr."\nSTDOUT: {$stdout}");

        return trim($stdout);
    }

    private function runWorker(array $arguments): string
    {
        return $this->finishWorker($this->startWorker($arguments));
    }

    private function workerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Actions\Teacher\CloseTeacherHomework;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
Carbon::setTestNow(Carbon::parse('2026-09-09 09:00:00 UTC'));
$mode = $argv[2];

if ($mode === 'setup') {
    $institution = Institution::factory()->create();
    $teacher = User::factory()->teacher($institution)->create();
    $admin = User::factory()->institutionAdmin($institution)->create();
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
    $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
    GroupTeacherMembership::factory()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id,
        'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id,
    ]);
    $topic = Topic::factory()->active()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $teacher->id,
    ]);
    $assessments = [];

    foreach (['deadline_close', 'close_deadline', 'deadline_probe', 'close_probe', 'early_close_deadline'] as $scenario) {
        $assessment = Assessment::factory()->homework()->create([
            'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
        ]);
        HomeworkAssignment::factory()->active()->create([
            'assessment_id' => $assessment, 'deadline_at' => Carbon::parse('2026-09-09 10:00:00 UTC'),
        ]);
        $recipient = AssessmentStudent::factory()->create([
            'assessment_id' => $assessment, 'assigned_by_user_id' => $teacher->id,
        ]);
        AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient]);
        $assessments[$scenario] = $assessment->id;
    }

    echo json_encode(['institution' => $institution->id, 'teacher' => $teacher->id, 'assessments' => $assessments], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    DB::transaction(function () use ($institutionId): void {
        foreach ([AssessmentAttempt::class, AssessmentStudent::class, HomeworkAssignment::class, Assessment::class,
            Topic::class, GroupTeacherMembership::class, Group::class, InstitutionSetting::class, User::class] as $model) {
            $model::query()->where('institution_id', $institutionId)->delete();
        }
        Institution::query()->whereKey($institutionId)->delete();
    });
    echo '{}';
    exit(0);
}

[$institutionId, $teacherId, $assessmentId, $operation, $hold, $lockedPath, $releasePath, $startedPath, $observedAt] = array_slice($argv, 3);
Carbon::setTestNow(Carbon::parse($observedAt));
DB::statement("set lock_timeout = '10s'");
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($startedPath, (string) $pid);

if ($hold === 'hold') {
    DB::listen(function ($query) use ($lockedPath, $releasePath, $pid): void {
        if (! str_starts_with($query->sql, 'update "assessment_attempts"')) {
            return;
        }
        if (DB::transactionLevel() < 1) {
            throw new LogicException('The terminal Attempt write must remain inside its finalization transaction.');
        }
        file_put_contents($lockedPath, (string) $pid);
        $deadline = microtime(true) + 15;
        do {
            clearstatcache(true, $releasePath);
            if (file_exists($releasePath)) {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        throw new RuntimeException('Timed out waiting for the deterministic finalization race release.');
    });
}

$finalizedCount = null;
$probeSnapshot = null;
if ($operation === 'deadline') {
    $finalizedCount = app(FinalizeHomeworkAttemptsAtDeadline::class)($institutionId, $assessmentId);
} elseif ($operation === 'close') {
    $teacher = User::query()->where('institution_id', $institutionId)->whereKey($teacherId)->firstOrFail();
    app(CloseTeacherHomework::class)($teacher, $assessmentId);
} else {
    $probeSnapshot = DB::transaction(fn () => AssessmentAttempt::query()
        ->where('institution_id', $institutionId)->where('assessment_id', $assessmentId)
        ->lockForUpdate()->firstOrFail()->getAttributes());
}

$attempt = AssessmentAttempt::query()->where('institution_id', $institutionId)->where('assessment_id', $assessmentId)->firstOrFail();
$homework = HomeworkAssignment::query()->where('institution_id', $institutionId)->whereKey($assessmentId)->firstOrFail();
echo json_encode([
    'attempt' => $attempt->getAttributes(),
    'homework_status' => $homework->status->value,
    'finalized_count' => $finalizedCount,
    'probe_snapshot' => $probeSnapshot,
    'attempt_count' => AssessmentAttempt::query()->where('institution_id', $institutionId)->where('assessment_id', $assessmentId)->count(),
], JSON_THROW_ON_ERROR);
PHP;
    }
}
