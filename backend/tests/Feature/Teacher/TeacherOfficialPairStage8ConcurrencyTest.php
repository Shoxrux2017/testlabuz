<?php

namespace Tests\Feature\Teacher;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherOfficialPairStage8ConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_competing_blitz_designations_and_replacements_serialize_and_preserve_pair_history(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's08_pair_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach (['initial', 'partial', 'replacement', 'locked_completion'] as $scenario) {
                $result = $this->runRace($workerPath, $ids['scenarios'][$scenario]);
                $this->assertSame('ok', $result['first']['outcome'], $scenario);
                $expectedOutcome = $scenario === 'locked_completion' ? 'result_pair_locked' : 'ok';
                $this->assertSame($expectedOutcome, $result['second']['outcome'], $scenario);
                $final = $result['second'];
                $this->assertSame(1, $final['pair_count']);
                $this->assertSame($ids['scenarios'][$scenario]['homework'], $final['homework_id']);
                $this->assertSame($ids['scenarios'][$scenario][$scenario === 'locked_completion' ? 'a' : 'b'], $final['blitz_id']);
                $this->assertSame($scenario === 'initial' ? '2026-09-17T10:00:00+00:00' : '2026-09-17T08:00:00+00:00', $final['designated_at']);
                $this->assertSame($scenario === 'initial' ? null : '2026-09-17T09:00:00+00:00', $final['cohort_at']);
                $this->assertSame($scenario === 'locked_completion' ? '2026-09-17T09:30:00+00:00' : null, $final['locked_at']);
                $this->assertSame(0, $final['blitz_recipient_count']);
                $this->assertSame(0, $final['attempt_count']);
                $this->assertSame(3, $final['blitz_count']);
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(string $workerPath, array $scenario): array
    {
        $lockedPath = $this->unusedTempPath('s08_pair_locked_');
        $releasePath = $this->unusedTempPath('s08_pair_release_');
        $attemptPath = $this->unusedTempPath('s08_pair_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
        $arguments = [$scenario['teacher'], $scenario['topic'], $scenario['homework']];
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $scenario['a'],
            'hold', $lockedPath, $releasePath, $firstAttemptPath,
        ]);
        $second = null;

        try {
            $this->waitForFile($lockedPath, 'The first designation worker did not retain its mutation locks.');
            $second = $this->startWorker([
                $workerPath, base_path(), 'run', ...$arguments, $scenario['b'],
                'normal', $lockedPath, $releasePath, $attemptPath,
            ]);
            $this->waitForFile($attemptPath, 'The competing designation worker did not start.');
            $this->waitForPostgresLock((int) file_get_contents($attemptPath));
        } finally {
            file_put_contents($releasePath, 'release');
            try {
                $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
                $secondResult = $second === null ? null : json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
            } finally {
                foreach ([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath] as $path) {
                    if (file_exists($path)) {
                        unlink($path);
                    }
                }
            }
        }

        return ['first' => $firstResult, 'second' => $secondResult];
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

    private function waitForPostgresLock(int $backendPid): void
    {
        $deadline = microtime(true) + 10;
        $activity = null;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne('select wait_event_type, wait_event from pg_stat_activity where pid = ?', [$backendPid]);
            if ($activity !== null && $activity->wait_event_type === 'Lock') {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('Competing designation did not enter a PostgreSQL lock wait: '.json_encode($activity));
    }

    /** @return array{process: resource, pipes: array<int, resource>} */
    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open(array_merge([PHP_BINARY], $arguments), [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);
        $this->assertIsResource($process);
        fclose($pipes[0]);

        return ['process' => $process, 'pipes' => $pipes];
    }

    /** @param array{process: resource, pipes: array<int, resource>} $worker */
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

use App\Actions\Teacher\SetTeacherTopicResultPair;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
CarbonImmutable::setTestNow('2026-09-17 10:00:00 UTC');

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S08 official pair concurrency']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create();
    $scenarios = [];

    foreach (['initial', 'partial', 'replacement', 'locked_completion'] as $scenario) {
        $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $topic = Topic::factory()->active()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $homework = Assessment::factory()->homework()->groupAssignment()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);
        HomeworkAssignment::factory()->draft()->create(['institution_id' => $institution->id, 'assessment_id' => $homework->id]);
        $blitzIds = [];
        foreach (['a', 'b', 'c'] as $label) {
            $blitz = Assessment::factory()->blitz()->groupAssignment()->create([
                'institution_id' => $institution->id,
                'teacher_id' => $teacher->id,
                'topic_id' => $topic->id,
            ]);
            BlitzTask::factory()->draft()->create(['institution_id' => $institution->id, 'assessment_id' => $blitz->id]);
            $blitzIds[$label] = $blitz->id;
        }
        if ($scenario !== 'initial') {
            TopicResultPair::factory()->create([
                'institution_id' => $institution->id,
                'topic_id' => $topic->id,
                'homework_assessment_id' => $homework->id,
                'blitz_assessment_id' => $scenario === 'replacement' ? $blitzIds['c'] : null,
                'designated_by_user_id' => $teacher->id,
                'designated_at' => now()->subHours(2),
                'cohort_snapshotted_at' => now()->subHour(),
                'locked_at' => $scenario === 'locked_completion' ? now()->subMinutes(30) : null,
            ]);
        }
        $scenarios[$scenario] = array_merge($blitzIds, [
            'teacher' => $teacher->id,
            'topic' => $topic->id,
            'homework' => $homework->id,
        ]);
    }
    echo json_encode(['institution' => $institution->id, 'scenarios' => $scenarios], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    TopicResultPair::query()->where('institution_id', $institutionId)->delete();
    BlitzTask::query()->where('institution_id', $institutionId)->delete();
    HomeworkAssignment::query()->where('institution_id', $institutionId)->delete();
    Assessment::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$topicId = $argv[4];
$homeworkId = $argv[5];
$blitzId = $argv[6];
$hold = $argv[7] === 'hold';
$lockedPath = $argv[8];
$releasePath = $argv[9];
$attemptPath = $argv[10];
file_put_contents($attemptPath, (string) DB::selectOne('select pg_backend_pid() as pid')->pid);

try {
    DB::transaction(function () use ($teacher, $topicId, $homeworkId, $blitzId, $hold, $lockedPath, $releasePath): void {
        app(SetTeacherTopicResultPair::class)($teacher, $topicId, $homeworkId, $blitzId);
        if ($hold) {
            file_put_contents($lockedPath, 'locked');
            $deadline = microtime(true) + 15;
            do {
                clearstatcache(true, $releasePath);
                if (file_exists($releasePath)) {
                    return;
                }
                usleep(5_000);
            } while (microtime(true) < $deadline);
            throw new RuntimeException('Timed out waiting for designation release signal.');
        }
    });
    $outcome = 'ok';
} catch (ResultPairLockedException) {
    $outcome = 'result_pair_locked';
}

$pair = TopicResultPair::query()->where('topic_id', $topicId)->firstOrFail();
$blitzIds = Assessment::query()->where('topic_id', $topicId)->where('type', 'blitz')->pluck('id');
echo json_encode([
    'outcome' => $outcome,
    'pair_count' => TopicResultPair::query()->where('topic_id', $topicId)->count(),
    'homework_id' => $pair->homework_assessment_id,
    'blitz_id' => $pair->blitz_assessment_id,
    'designated_at' => $pair->designated_at->toIso8601String(),
    'cohort_at' => $pair->cohort_snapshotted_at?->toIso8601String(),
    'locked_at' => $pair->locked_at?->toIso8601String(),
    'blitz_recipient_count' => AssessmentStudent::query()->whereIn('assessment_id', $blitzIds)->count(),
    'attempt_count' => AssessmentAttempt::query()->whereIn('assessment_id', $blitzIds)->count(),
    'blitz_count' => $blitzIds->count(),
], JSON_THROW_ON_ERROR);
PHP;
    }
}
