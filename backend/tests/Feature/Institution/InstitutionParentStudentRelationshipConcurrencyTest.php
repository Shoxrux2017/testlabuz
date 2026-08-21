<?php

namespace Tests\Feature\Institution;

use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class InstitutionParentStudentRelationshipConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_postgresql_locks_produce_all_parent_student_relationship_and_user_lifecycle_race_outcomes(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $workerPath = tempnam(sys_get_temp_dir(), 's04_be_004_relationship_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            $duplicateConnect = $this->runBlockingRace(
                $workerPath,
                $ids['actor'],
                'connect',
                $ids['scenarios']['duplicate_connect'],
                'connect',
                $ids['scenarios']['duplicate_connect'],
            );
            $this->assertTrue($duplicateConnect['first']['created']);
            $this->assertFalse($duplicateConnect['second']['created']);
            $this->assertSame($duplicateConnect['first']['relationship_id'], $duplicateConnect['second']['relationship_id']);
            $this->assertSame(1, $duplicateConnect['first']['relationship_inserts']);
            $this->assertSame(0, $duplicateConnect['second']['relationship_inserts']);
            $this->assertSame(1, $this->currentCount($ids['scenarios']['duplicate_connect']));

            $duplicateDisconnect = $this->runBlockingRace(
                $workerPath,
                $ids['actor'],
                'disconnect',
                [$ids['relationships']['duplicate_disconnect']],
                'disconnect',
                [$ids['relationships']['duplicate_disconnect']],
            );
            $this->assertSame(1, $duplicateDisconnect['first']['relationship_updates']);
            $this->assertSame(0, $duplicateDisconnect['second']['relationship_updates']);
            $this->assertNotNull(ParentStudentRelationship::query()
                ->findOrFail($ids['relationships']['duplicate_disconnect'])
                ->ended_at);

            $connectThenDisconnect = json_decode($this->runWorker([
                $workerPath,
                base_path(),
                'run',
                $ids['actor'],
                'connect',
                json_encode($ids['scenarios']['connect_disconnect'], JSON_THROW_ON_ERROR),
                'normal',
                '',
                '',
                $this->unusedTempPath('s04_be_004_attempt_'),
            ]), true, flags: JSON_THROW_ON_ERROR);
            $this->assertTrue($connectThenDisconnect['created']);
            $disconnectAfterConnect = json_decode($this->runWorker([
                $workerPath,
                base_path(),
                'run',
                $ids['actor'],
                'disconnect',
                json_encode([$connectThenDisconnect['relationship_id']], JSON_THROW_ON_ERROR),
                'normal',
                '',
                '',
                $this->unusedTempPath('s04_be_004_attempt_'),
            ]), true, flags: JSON_THROW_ON_ERROR);
            $this->assertSame(1, $disconnectAfterConnect['relationship_updates']);
            $this->assertSame(0, $this->currentCount($ids['scenarios']['connect_disconnect']));

            $disconnectThenConnect = $this->runBlockingRace(
                $workerPath,
                $ids['actor'],
                'disconnect',
                [$ids['relationships']['disconnect_connect']],
                'connect',
                $ids['scenarios']['disconnect_connect'],
            );
            $this->assertSame(1, $disconnectThenConnect['first']['relationship_updates']);
            $this->assertTrue($disconnectThenConnect['second']['created']);
            $this->assertNotSame(
                $ids['relationships']['disconnect_connect'],
                $disconnectThenConnect['second']['relationship_id'],
            );
            $this->assertSame(2, $this->pairCount($ids['scenarios']['disconnect_connect']));
            $this->assertSame(1, $this->currentCount($ids['scenarios']['disconnect_connect']));

            $overlap = $this->runBlockingRace(
                $workerPath,
                $ids['actor'],
                'connect',
                $ids['scenarios']['overlap_first'],
                'connect',
                $ids['scenarios']['overlap_second'],
            );
            $this->assertTrue($overlap['first']['created']);
            $this->assertTrue($overlap['second']['created']);
            $this->assertSame(1, $this->currentCount($ids['scenarios']['overlap_first']));
            $this->assertSame(1, $this->currentCount($ids['scenarios']['overlap_second']));

            $disjoint = $this->runIndependentRace(
                $workerPath,
                $ids['actor'],
                $ids['scenarios']['disjoint_first'],
                $ids['scenarios']['disjoint_second'],
            );
            $this->assertTrue($disjoint['first']['created']);
            $this->assertTrue($disjoint['second']['created']);
            $this->assertSame(1, $this->currentCount($ids['scenarios']['disjoint_first']));
            $this->assertSame(1, $this->currentCount($ids['scenarios']['disjoint_second']));

            $deactivateThenConnect = $this->runBlockingRace(
                $workerPath,
                $ids['actor'],
                'deactivate',
                [$ids['scenarios']['deactivate_connect'][1]],
                'connect',
                $ids['scenarios']['deactivate_connect'],
            );
            $this->assertSame('ok', $deactivateThenConnect['first']['outcome']);
            $this->assertSame('inactive_user', $deactivateThenConnect['second']['outcome']);
            $this->assertFalse(User::query()->findOrFail($ids['scenarios']['deactivate_connect'][1])->is_active);
            $this->assertSame(0, $this->pairCount($ids['scenarios']['deactivate_connect']));

            $connectThenDeactivate = $this->runBlockingRace(
                $workerPath,
                $ids['actor'],
                'connect',
                $ids['scenarios']['connect_deactivate'],
                'deactivate',
                [$ids['scenarios']['connect_deactivate'][0]],
            );
            $this->assertTrue($connectThenDeactivate['first']['created']);
            $this->assertSame('ok', $connectThenDeactivate['second']['outcome']);
            $this->assertFalse(User::query()->findOrFail($ids['scenarios']['connect_deactivate'][0])->is_active);
            $this->assertSame(1, $this->currentCount($ids['scenarios']['connect_deactivate']));
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /**
     * @param  list<string>  $firstTarget
     * @param  list<string>  $secondTarget
     * @return array{first: array<string, mixed>, second: array<string, mixed>}
     */
    private function runBlockingRace(
        string $workerPath,
        string $actorId,
        string $firstOperation,
        array $firstTarget,
        string $secondOperation,
        array $secondTarget,
    ): array {
        $lockedPath = $this->unusedTempPath('s04_be_004_locked_');
        $releasePath = $this->unusedTempPath('s04_be_004_release_');
        $firstAttemptPath = $this->unusedTempPath('s04_be_004_attempt_first_');
        $secondAttemptPath = $this->unusedTempPath('s04_be_004_attempt_second_');
        $first = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $firstOperation,
            json_encode($firstTarget, JSON_THROW_ON_ERROR),
            'hold',
            $lockedPath,
            $releasePath,
            $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'First relationship worker did not acquire and hold its locks.');
        $second = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $secondOperation,
            json_encode($secondTarget, JSON_THROW_ON_ERROR),
            'normal',
            $lockedPath,
            $releasePath,
            $secondAttemptPath,
        ]);
        $this->waitForFile($secondAttemptPath, 'Second relationship worker did not begin its operation.');

        try {
            $this->waitForPostgresLock(
                (int) file_get_contents($secondAttemptPath),
                $firstOperation.' -> '.$secondOperation,
            );
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $firstAttemptPath, $secondAttemptPath]);
            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }

        file_put_contents($releasePath, 'release');
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $firstAttemptPath, $secondAttemptPath]);

        return ['first' => $firstResult, 'second' => $secondResult];
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runIndependentRace(
        string $workerPath,
        string $actorId,
        array $firstTarget,
        array $secondTarget,
    ): array {
        $lockedPath = $this->unusedTempPath('s04_be_004_locked_');
        $releasePath = $this->unusedTempPath('s04_be_004_release_');
        $firstAttemptPath = $this->unusedTempPath('s04_be_004_attempt_first_');
        $secondAttemptPath = $this->unusedTempPath('s04_be_004_attempt_second_');
        $first = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            'connect',
            json_encode($firstTarget, JSON_THROW_ON_ERROR),
            'hold',
            $lockedPath,
            $releasePath,
            $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'First disjoint worker did not acquire and hold its locks.');
        $second = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            'connect',
            json_encode($secondTarget, JSON_THROW_ON_ERROR),
            'normal',
            $lockedPath,
            $releasePath,
            $secondAttemptPath,
        ]);

        try {
            $this->waitForWorkerExit($second, 'Disjoint relationship mutation was unexpectedly blocked.');
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $firstAttemptPath, $secondAttemptPath]);
            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }

        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        file_put_contents($releasePath, 'release');
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $firstAttemptPath, $secondAttemptPath]);

        return ['first' => $firstResult, 'second' => $secondResult];
    }

    /** @param list<string> $pair */
    private function currentCount(array $pair): int
    {
        return ParentStudentRelationship::query()
            ->where('parent_id', $pair[0])
            ->where('student_id', $pair[1])
            ->whereNull('ended_at')
            ->count();
    }

    /** @param list<string> $pair */
    private function pairCount(array $pair): int
    {
        return ParentStudentRelationship::query()
            ->where('parent_id', $pair[0])
            ->where('student_id', $pair[1])
            ->count();
    }

    private function unusedTempPath(string $prefix): string
    {
        $path = tempnam(sys_get_temp_dir(), $prefix);
        $this->assertIsString($path);
        unlink($path);

        return $path;
    }

    private function waitForFile(string $path, string $failureMessage): void
    {
        $deadline = microtime(true) + 10;

        do {
            clearstatcache(true, $path);

            if (file_exists($path) && filesize($path) > 0) {
                return;
            }

            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail($failureMessage);
    }

    private function waitForPostgresLock(int $backendPid, string $scenario): void
    {
        $deadline = microtime(true) + 10;
        $lastActivity = null;

        do {
            DB::select('select pg_stat_clear_snapshot()');
            $lastActivity = DB::selectOne(
                'select wait_event_type, wait_event from pg_stat_activity where pid = ?',
                [$backendPid],
            );

            if ($lastActivity !== null && $lastActivity->wait_event_type === 'Lock') {
                $this->assertNotNull($lastActivity->wait_event);

                return;
            }

            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail(sprintf(
            'Second worker never entered a PostgreSQL lock wait during %s. Last activity: %s',
            $scenario,
            json_encode($lastActivity, JSON_THROW_ON_ERROR),
        ));
    }

    /** @param array{process: resource, pipes: array<int, resource>} $worker */
    private function waitForWorkerExit(array $worker, string $failureMessage): void
    {
        $deadline = microtime(true) + 5;

        do {
            if (! proc_get_status($worker['process'])['running']) {
                return;
            }

            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail($failureMessage);
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
        $this->assertSame(0, $exitCode, $stderr."\nSTDOUT: ".$stdout);

        return trim($stdout);
    }

    private function runWorker(array $arguments): string
    {
        return $this->finishWorker($this->startWorker($arguments));
    }

    /** @param list<string> $paths */
    private function removeTempPaths(array $paths): void
    {
        foreach ($paths as $path) {
            if (file_exists($path)) {
                unlink($path);
            }
        }
    }

    private function postgresConcurrencyWorkerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Institution\ChangeInstitutionUserLifecycle;
use App\Actions\Institution\ConnectInstitutionParentStudentRelationship;
use App\Actions\Institution\DisconnectInstitutionParentStudentRelationship;
use App\Exceptions\Institution\InactiveParentStudentRelationshipUserException;
use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S04 BE 004 concurrency institution']);
    $actor = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $scenarios = [];
    $relationships = [];

    $createPair = static function () use ($institution): array {
        return [
            User::factory()->parent($institution)->create()->id,
            User::factory()->student($institution)->create()->id,
        ];
    };
    $createRelationship = static function (array $pair) use ($institution, $actor): string {
        return ParentStudentRelationship::factory()->create([
            'institution_id' => $institution->id,
            'parent_id' => $pair[0],
            'student_id' => $pair[1],
            'connected_by_user_id' => $actor->id,
        ])->id;
    };

    foreach (['duplicate_connect', 'connect_disconnect', 'disjoint_first', 'disjoint_second', 'deactivate_connect', 'connect_deactivate'] as $scenario) {
        $scenarios[$scenario] = $createPair();
    }
    foreach (['duplicate_disconnect', 'disconnect_connect'] as $scenario) {
        $scenarios[$scenario] = $createPair();
        $relationships[$scenario] = $createRelationship($scenarios[$scenario]);
    }

    $sharedStudent = User::factory()->student($institution)->create([
        'id' => '50000000-0000-4000-8000-000000000002',
    ]);
    $overlapFirstParent = User::factory()->parent($institution)->create([
        'id' => '10000000-0000-4000-8000-000000000001',
    ]);
    $overlapSecondParent = User::factory()->parent($institution)->create([
        'id' => '90000000-0000-4000-8000-000000000003',
    ]);
    $scenarios['overlap_first'] = [$overlapFirstParent->id, $sharedStudent->id];
    $scenarios['overlap_second'] = [$overlapSecondParent->id, $sharedStudent->id];

    echo json_encode([
        'institution' => $institution->id,
        'actor' => $actor->id,
        'scenarios' => $scenarios,
        'relationships' => $relationships,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    ParentStudentRelationship::query()->where('institution_id', $institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$actor = User::query()->findOrFail($argv[3]);
$operation = $argv[4];
$target = json_decode($argv[5], true, flags: JSON_THROW_ON_ERROR);
$hold = $argv[6] === 'hold';
$lockedPath = $argv[7];
$releasePath = $argv[8];
$attemptPath = $argv[9];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);

if ($hold) {
    DB::beginTransaction();
}

DB::flushQueryLog();
DB::enableQueryLog();
$outcome = 'ok';
$created = null;
$relationshipId = null;

try {
    if ($operation === 'connect') {
        $result = (new ConnectInstitutionParentStudentRelationship)($actor, $target[0], $target[1]);
        $created = $result->created;
        $relationshipId = $result->relationship->id;
    } elseif ($operation === 'disconnect') {
        (new DisconnectInstitutionParentStudentRelationship)($actor, $target[0]);
    } elseif ($operation === 'deactivate') {
        (new ChangeInstitutionUserLifecycle)->deactivate($actor, $target[0]);
    }
} catch (InactiveParentStudentRelationshipUserException) {
    $outcome = 'inactive_user';
} catch (NotFoundHttpException) {
    $outcome = 'not_found';
}

$queries = DB::getQueryLog();
$response = [
    'outcome' => $outcome,
    'created' => $created,
    'relationship_id' => $relationshipId,
    'relationship_inserts' => count(array_filter(
        $queries,
        static fn (array $query): bool => str_starts_with(
            strtolower((string) $query['query']),
            'insert into "parent_student_relationships"',
        ),
    )),
    'relationship_updates' => count(array_filter(
        $queries,
        static fn (array $query): bool => str_starts_with(
            strtolower((string) $query['query']),
            'update "parent_student_relationships"',
        ),
    )),
];

if ($hold) {
    file_put_contents($lockedPath, json_encode($response, JSON_THROW_ON_ERROR));
    $deadline = microtime(true) + 15;

    while (! file_exists($releasePath) && microtime(true) < $deadline) {
        usleep(5_000);
    }

    if (! file_exists($releasePath)) {
        DB::rollBack();
        fwrite(STDERR, 'Timed out waiting for deterministic relationship race release.');
        exit(1);
    }

    DB::commit();
}

echo json_encode($response, JSON_THROW_ON_ERROR);
PHP;
    }
}
