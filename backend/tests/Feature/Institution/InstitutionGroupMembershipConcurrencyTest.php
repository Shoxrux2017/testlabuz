<?php

namespace Tests\Feature\Institution;

use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class InstitutionGroupMembershipConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_postgresql_row_locks_produce_all_membership_archive_and_user_lifecycle_race_outcomes(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $workerPath = tempnam(sys_get_temp_dir(), 's04_be_003_membership_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            $identical = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['identical'],
                'assign_teacher',
                $ids['users']['identical'],
                'assign_teacher',
                $ids['users']['identical'],
            );
            $this->assertSame(2, $identical['first']['created_count']);
            $this->assertSame(0, $identical['second']['created_count']);
            $this->assertSame(2, $this->currentTeacherCount($ids['groups']['identical']));
            $this->assertSame(2, GroupTeacherMembership::query()->where('group_id', $ids['groups']['identical'])->count());

            $overlap = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['overlap'],
                'assign_teacher',
                array_slice($ids['users']['overlap'], 0, 2),
                'assign_teacher',
                array_slice($ids['users']['overlap'], 1, 2),
            );
            $this->assertSame(2, $overlap['first']['created_count']);
            $this->assertSame(1, $overlap['second']['created_count']);
            $this->assertSame(3, $this->currentTeacherCount($ids['groups']['overlap']));

            $remove = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['remove'],
                'remove_teacher',
                $ids['users']['remove'],
                'remove_teacher',
                $ids['users']['remove'],
            );
            $this->assertSame(1, $remove['first']['membership_updates']);
            $this->assertSame(0, $remove['second']['membership_updates']);
            $this->assertSame(0, $this->currentTeacherCount($ids['groups']['remove']));
            $this->assertSame(1, GroupTeacherMembership::query()->where('group_id', $ids['groups']['remove'])->whereNotNull('ended_at')->count());

            $assignThenRemove = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['assign_remove'],
                'assign_teacher',
                $ids['users']['assign_remove'],
                'remove_teacher',
                [$ids['users']['assign_remove'][0]],
            );
            $this->assertSame(2, $assignThenRemove['first']['created_count']);
            $this->assertSame(1, $assignThenRemove['second']['membership_updates']);
            $this->assertSame(1, $this->currentTeacherCount($ids['groups']['assign_remove']));
            $this->assertSame(1, GroupTeacherMembership::query()
                ->where('group_id', $ids['groups']['assign_remove'])
                ->where('teacher_id', $ids['users']['assign_remove'][0])
                ->whereNotNull('ended_at')
                ->count());

            $removeThenAssign = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['remove_assign'],
                'remove_teacher',
                $ids['users']['remove_assign'],
                'assign_teacher',
                $ids['users']['remove_assign'],
            );
            $this->assertSame(1, $removeThenAssign['first']['membership_updates']);
            $this->assertSame(1, $removeThenAssign['second']['created_count']);
            $this->assertSame(2, GroupTeacherMembership::query()->where('group_id', $ids['groups']['remove_assign'])->count());
            $this->assertSame(1, $this->currentTeacherCount($ids['groups']['remove_assign']));

            $membershipThenArchive = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['membership_archive'],
                'assign_teacher',
                $ids['users']['membership_archive'],
                'archive',
                [],
            );
            $this->assertSame('ok', $membershipThenArchive['first']['outcome']);
            $this->assertSame('ok', $membershipThenArchive['second']['outcome']);
            $this->assertSame(GroupStatus::Archived, Group::query()->findOrFail($ids['groups']['membership_archive'])->status);
            $this->assertSame(1, $this->currentTeacherCount($ids['groups']['membership_archive']));

            $archiveThenAssign = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['archive_assign'],
                'archive',
                [],
                'assign_teacher',
                $ids['users']['archive_assign'],
            );
            $this->assertSame('ok', $archiveThenAssign['first']['outcome']);
            $this->assertSame('group_archived', $archiveThenAssign['second']['outcome']);
            $this->assertSame(0, GroupTeacherMembership::query()->where('group_id', $ids['groups']['archive_assign'])->count());

            $archiveThenRemove = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['archive_remove'],
                'archive',
                [],
                'remove_teacher',
                $ids['users']['archive_remove'],
            );
            $this->assertSame('group_archived', $archiveThenRemove['second']['outcome']);
            $this->assertSame(1, $this->currentTeacherCount($ids['groups']['archive_remove']));

            $deactivateThenAssign = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['deactivate_assign'],
                'deactivate',
                $ids['users']['deactivate_assign'],
                'assign_teacher',
                $ids['users']['deactivate_assign'],
            );
            $this->assertSame('ok', $deactivateThenAssign['first']['outcome']);
            $this->assertSame('inactive_member', $deactivateThenAssign['second']['outcome']);
            $this->assertFalse(User::query()->findOrFail($ids['users']['deactivate_assign'][0])->is_active);
            $this->assertSame(0, GroupTeacherMembership::query()->where('group_id', $ids['groups']['deactivate_assign'])->count());

            $assignThenDeactivate = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['assign_deactivate'],
                'assign_teacher',
                $ids['users']['assign_deactivate'],
                'deactivate',
                $ids['users']['assign_deactivate'],
            );
            $this->assertSame(1, $assignThenDeactivate['first']['created_count']);
            $this->assertSame('ok', $assignThenDeactivate['second']['outcome']);
            $this->assertFalse(User::query()->findOrFail($ids['users']['assign_deactivate'][0])->is_active);
            $this->assertSame(1, $this->currentTeacherCount($ids['groups']['assign_deactivate']));

            $crossGroup = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['cross_a'],
                'assign_teacher',
                array_reverse($ids['users']['cross']),
                'assign_teacher_other_group',
                array_merge([$ids['groups']['cross_b']], $ids['users']['cross']),
            );
            $this->assertSame(2, $crossGroup['first']['created_count']);
            $this->assertSame(2, $crossGroup['second']['created_count']);
            $this->assertSame(2, $this->currentTeacherCount($ids['groups']['cross_a']));
            $this->assertSame(2, $this->currentTeacherCount($ids['groups']['cross_b']));

            $studentIdentical = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['student_identical'],
                'assign_student',
                $ids['users']['student_identical'],
                'assign_student',
                $ids['users']['student_identical'],
            );
            $this->assertSame(2, $studentIdentical['first']['created_count']);
            $this->assertSame(0, $studentIdentical['second']['created_count']);
            $this->assertSame(2, GroupStudentMembership::query()
                ->where('group_id', $ids['groups']['student_identical'])
                ->whereNull('ended_at')
                ->count());
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    private function currentTeacherCount(string $groupId): int
    {
        return GroupTeacherMembership::query()
            ->where('group_id', $groupId)
            ->whereNull('ended_at')
            ->count();
    }

    /**
     * @param  list<string>  $firstIds
     * @param  list<string>  $secondIds
     * @return array{first: array<string, mixed>, second: array<string, mixed>}
     */
    private function runRace(
        string $workerPath,
        string $actorId,
        string $groupId,
        string $firstOperation,
        array $firstIds,
        string $secondOperation,
        array $secondIds,
    ): array {
        $lockedPath = $this->unusedTempPath('s04_be_003_locked_');
        $releasePath = $this->unusedTempPath('s04_be_003_release_');
        $attemptPath = $this->unusedTempPath('s04_be_003_attempt_');
        $firstAttemptPath = $attemptPath.'.first';

        $first = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $groupId,
            $firstOperation,
            json_encode($firstIds, JSON_THROW_ON_ERROR),
            'hold',
            $lockedPath,
            $releasePath,
            $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'First worker did not finish its operation while holding row locks.');

        $second = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $groupId,
            $secondOperation,
            json_encode($secondIds, JSON_THROW_ON_ERROR),
            'normal',
            $lockedPath,
            $releasePath,
            $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'Second worker did not begin its row-locking operation.');
        $secondBackendPid = (int) file_get_contents($attemptPath);
        try {
            $this->waitForPostgresLock(
                $secondBackendPid,
                $firstOperation.' -> '.$secondOperation.' for group '.$groupId,
            );
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);

            foreach ([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath] as $path) {
                if (file_exists($path)) {
                    unlink($path);
                }
            }

            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }
        file_put_contents($releasePath, 'release');

        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);

        foreach ([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath] as $path) {
            if (file_exists($path)) {
                unlink($path);
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
            'Second worker never entered a PostgreSQL row-lock wait during %s. Last activity: %s',
            $scenario,
            json_encode($lastActivity, JSON_THROW_ON_ERROR),
        ));
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

    private function postgresConcurrencyWorkerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Institution\ArchiveInstitutionGroup;
use App\Actions\Institution\AssignStudentToInstitutionGroup;
use App\Actions\Institution\AssignTeacherToInstitutionGroup;
use App\Actions\Institution\ChangeInstitutionUserLifecycle;
use App\Actions\Institution\RemoveTeacherFromInstitutionGroup;
use App\Exceptions\Institution\GroupArchivedException;
use App\Exceptions\Institution\InactiveGroupMemberException;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S04 BE 003 concurrency institution']);
    $actor = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $groups = [];
    $users = [];

    $teacherScenarios = [
        'identical' => 2,
        'overlap' => 3,
        'remove' => 1,
        'assign_remove' => 2,
        'remove_assign' => 1,
        'membership_archive' => 1,
        'archive_assign' => 1,
        'archive_remove' => 1,
        'deactivate_assign' => 1,
        'assign_deactivate' => 1,
    ];

    foreach ($teacherScenarios as $scenario => $count) {
        $groups[$scenario] = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Concurrency '.str_replace('_', ' ', $scenario),
        ])->id;
        $users[$scenario] = User::factory()->count($count)->teacher($institution)->create()->pluck('id')->all();
    }

    foreach (['remove', 'remove_assign', 'archive_remove'] as $scenario) {
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $groups[$scenario],
            'teacher_id' => $users[$scenario][0],
            'assigned_by_user_id' => $actor->id,
        ]);
    }

    $groups['cross_a'] = Group::factory()->create([
        'institution_id' => $institution->id,
        'created_by_user_id' => $actor->id,
        'name' => 'Concurrency cross A',
    ])->id;
    $groups['cross_b'] = Group::factory()->create([
        'institution_id' => $institution->id,
        'created_by_user_id' => $actor->id,
        'name' => 'Concurrency cross B',
    ])->id;
    $users['cross'] = User::factory()->count(2)->teacher($institution)->create()->pluck('id')->all();

    $groups['student_identical'] = Group::factory()->create([
        'institution_id' => $institution->id,
        'created_by_user_id' => $actor->id,
        'name' => 'Concurrency student identical',
    ])->id;
    $users['student_identical'] = User::factory()->count(2)->student($institution)->create()->pluck('id')->all();

    echo json_encode([
        'institution' => $institution->id,
        'actor' => $actor->id,
        'groups' => $groups,
        'users' => $users,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $groupIds = Group::query()->where('institution_id', $institutionId)->pluck('id');
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    GroupTeacherMembership::query()->whereIn('group_id', $groupIds)->delete();
    GroupStudentMembership::query()->whereIn('group_id', $groupIds)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$actor = User::query()->findOrFail($argv[3]);
$groupId = $argv[4];
$operation = $argv[5];
$ids = json_decode($argv[6], true, flags: JSON_THROW_ON_ERROR);
$hold = $argv[7] === 'hold';
$lockedPath = $argv[8];
$releasePath = $argv[9];
$attemptPath = $argv[10];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);

if ($hold) {
    DB::beginTransaction();
}

DB::flushQueryLog();
DB::enableQueryLog();
$outcome = 'ok';
$createdCount = null;

try {
    if ($operation === 'assign_teacher_other_group') {
        $otherGroupId = array_shift($ids);
        $result = (new AssignTeacherToInstitutionGroup)($actor, $otherGroupId, $ids);
        $createdCount = $result->createdCount;
    } else {
        $result = match ($operation) {
            'assign_teacher' => (new AssignTeacherToInstitutionGroup)($actor, $groupId, $ids),
            'assign_student' => (new AssignStudentToInstitutionGroup)($actor, $groupId, $ids),
            'remove_teacher' => (new RemoveTeacherFromInstitutionGroup)($actor, $groupId, $ids[0]),
            'archive' => (new ArchiveInstitutionGroup)($actor, $groupId),
            'deactivate' => (new ChangeInstitutionUserLifecycle)->deactivate($actor, $ids[0]),
        };

        if (isset($result->createdCount)) {
            $createdCount = $result->createdCount;
        }
    }
} catch (GroupArchivedException) {
    $outcome = 'group_archived';
} catch (InactiveGroupMemberException) {
    $outcome = 'inactive_member';
}

$queries = DB::getQueryLog();

if ($hold) {
    file_put_contents($lockedPath, 'locked');
    $deadline = microtime(true) + 15;

    while (! file_exists($releasePath) && microtime(true) < $deadline) {
        usleep(5_000);
    }

    if (! file_exists($releasePath)) {
        DB::rollBack();
        fwrite(STDERR, 'Timed out waiting for deterministic race release.');
        exit(1);
    }

    DB::commit();
}

$membershipUpdates = count(array_filter(
    $queries,
    static function (array $query): bool {
        $sql = strtolower((string) $query['query']);

        return str_starts_with($sql, 'update "group_teacher_memberships"')
            || str_starts_with($sql, 'update "group_student_memberships"');
    },
));

echo json_encode([
    'outcome' => $outcome,
    'created_count' => $createdCount,
    'membership_updates' => $membershipUpdates,
], JSON_THROW_ON_ERROR);
PHP;
    }
}
