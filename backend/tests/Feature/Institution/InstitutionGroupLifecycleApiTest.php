<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ArchiveInstitutionGroup;
use App\Actions\Institution\UpdateInstitutionGroup;
use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Exceptions\Institution\GroupArchivedException;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class InstitutionGroupLifecycleApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/institution/groups';

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_first_and_repeated_archive_are_locked_idempotent_and_preserve_memberships_and_timestamps(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Lifecycle Group',
            'updated_at' => CarbonImmutable::parse('2026-08-19 09:00:00', 'UTC'),
        ]);
        $activeTeacher = User::factory()->teacher($institution)->create();
        $inactiveTeacher = User::factory()->teacher($institution)->inactive()->create();
        $student = User::factory()->student($institution)->create();
        $endedStudent = User::factory()->student($institution)->create();
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $activeTeacher->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $inactiveTeacher->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        GroupStudentMembership::factory()->ended()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $endedStudent->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        $membershipsBefore = $this->membershipSnapshot($group->id);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 12:00:00', 'UTC'));
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $first = $this->rawRequestAs($actor, 'POST', self::BASE_URI.'/'.$group->id.'/archive', '');
            $firstQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $first->assertOk();
        $this->assertSame(['data', 'message'], array_keys($first->json()));
        $this->assertSame('Group archived successfully.', $first->json('message'));
        $this->assertSame('archived', $first->json('data.status'));
        $this->assertSame('2026-08-19T12:00:00Z', $first->json('data.archived_at'));
        $this->assertSame('2026-08-19T12:00:00Z', $first->json('data.updated_at'));
        $this->assertSame(2, $first->json('data.teachers_count'));
        $this->assertSame(1, $first->json('data.students_count'));
        $this->assertSame(1, $this->groupUpdateCount($firstQueries));
        $this->assertTrue($this->queriesContainScopedForUpdate($firstQueries, $institution->id, $group->id));
        $this->assertSame($membershipsBefore, $this->membershipSnapshot($group->id));

        $group->refresh();
        $archivedAt = $group->getRawOriginal('archived_at');
        $updatedAt = $group->getRawOriginal('updated_at');
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 13:00:00', 'UTC'));

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $second = $this->rawRequestAs($actor, 'POST', self::BASE_URI.'/'.$group->id.'/archive', '{}');
            $secondQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $second->assertOk();
        $this->assertSame('2026-08-19T12:00:00Z', $second->json('data.archived_at'));
        $this->assertSame('2026-08-19T12:00:00Z', $second->json('data.updated_at'));
        $this->assertSame(0, $this->groupUpdateCount($secondQueries));
        $this->assertTrue($this->queriesContainScopedForUpdate($secondQueries, $institution->id, $group->id));
        $group->refresh();
        $this->assertSame($archivedAt, $group->getRawOriginal('archived_at'));
        $this->assertSame($updatedAt, $group->getRawOriginal('updated_at'));
        $this->assertSame($membershipsBefore, $this->membershipSnapshot($group->id));
    }

    public function test_archive_rejects_body_keys_malformed_non_object_wrong_content_type_and_queries_without_mutation(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $otherActor = $this->institutionAdmin($otherInstitution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $foreign = Group::factory()->create([
            'institution_id' => $otherInstitution->id,
            'created_by_user_id' => $otherActor->id,
        ]);
        $before = $group->refresh()->getRawOriginal();

        $cases = [
            [' ', 'application/json'],
            ['{', 'application/json'],
            ['[]', 'application/json'],
            ['null', 'application/json'],
            ['"value"', 'application/json'],
            ['{"reason":"forged"}', 'application/json'],
            ['{}', 'text/plain'],
        ];

        foreach ($cases as [$content, $contentType]) {
            $this->rawRequestAs(
                $actor,
                'POST',
                self::BASE_URI.'/'.$group->id.'/archive',
                $content,
                contentType: $contentType,
            )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            $this->assertSame($before, $group->refresh()->getRawOriginal(), $content);
        }

        $this->rawRequestAs(
            $actor,
            'POST',
            self::BASE_URI.'/'.$group->id.'/archive',
            '',
            query: ['force' => '1'],
        )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $group->refresh()->getRawOriginal());

        foreach (['not-a-uuid', '11111111-1111-4111-8111-111111111111', $foreign->id] as $identifier) {
            $this->rawRequestAs($actor, 'POST', self::BASE_URI.'/'.$identifier.'/archive', '')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->assertSame(GroupStatus::Active, $foreign->refresh()->status);
    }

    public function test_update_and_archive_actions_lock_fresh_tenant_rows_and_enforce_archived_precedence(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Fresh State',
        ]);

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $updated = app(UpdateInstitutionGroup::class)($actor, $group->id, ['name' => 'Updated State']);
            $updateQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }
        $this->assertSame('Updated State', $updated->name);
        $this->assertSame(1, $this->groupUpdateCount($updateQueries));
        $this->assertTrue($this->queriesContainScopedForUpdate($updateQueries, $institution->id, $group->id));

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $archived = app(ArchiveInstitutionGroup::class)($actor, $group->id);
            $archiveQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }
        $this->assertSame(GroupStatus::Archived, $archived->status);
        $this->assertSame('Updated State', $archived->name);
        $this->assertSame(1, $this->groupUpdateCount($archiveQueries));
        $this->assertTrue($this->queriesContainScopedForUpdate($archiveQueries, $institution->id, $group->id));

        $staleActiveInstance = $group;
        $this->assertSame(GroupStatus::Active, $staleActiveInstance->status);
        $this->expectException(GroupArchivedException::class);
        app(UpdateInstitutionGroup::class)($actor, $staleActiveInstance->id, ['name' => 'Must Not Win']);
    }

    public function test_controlled_postgresql_races_serialize_both_update_archive_orders_and_two_archives(): void
    {
        $workerPath = tempnam(sys_get_temp_dir(), 's04_be_002_group_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());

        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            $archiveFirst = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['archive_first'],
                'archive',
                'update',
            );
            $this->assertSame('ok', $archiveFirst['first']['outcome']);
            $this->assertSame(1, $archiveFirst['first']['updates']);
            $this->assertSame('conflict', $archiveFirst['second']['outcome']);
            $this->assertSame(0, $archiveFirst['second']['updates']);
            $archiveFirstGroup = Group::query()->findOrFail($ids['groups']['archive_first']);
            $this->assertSame(GroupStatus::Archived, $archiveFirstGroup->status);
            $this->assertSame('Archive First Original', $archiveFirstGroup->name);

            $updateFirst = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['update_first'],
                'update',
                'archive',
            );
            $this->assertSame('ok', $updateFirst['first']['outcome']);
            $this->assertSame(1, $updateFirst['first']['updates']);
            $this->assertSame('ok', $updateFirst['second']['outcome']);
            $this->assertSame(1, $updateFirst['second']['updates']);
            $updateFirstGroup = Group::query()->findOrFail($ids['groups']['update_first']);
            $this->assertSame(GroupStatus::Archived, $updateFirstGroup->status);
            $this->assertSame('Concurrent Updated', $updateFirstGroup->name);
            $this->assertNotNull($updateFirstGroup->archived_at);

            $doubleArchive = $this->runRace(
                $workerPath,
                $ids['actor'],
                $ids['groups']['double_archive'],
                'archive',
                'archive',
            );
            $this->assertSame('ok', $doubleArchive['first']['outcome']);
            $this->assertSame(1, $doubleArchive['first']['updates']);
            $this->assertSame('ok', $doubleArchive['second']['outcome']);
            $this->assertSame(0, $doubleArchive['second']['updates']);
            $this->assertSame($doubleArchive['first']['archived_at'], $doubleArchive['second']['archived_at']);
            $this->assertSame($doubleArchive['first']['updated_at'], $doubleArchive['second']['updated_at']);
            $doubleArchiveGroup = Group::query()->findOrFail($ids['groups']['double_archive']);
            $this->assertSame(GroupStatus::Archived, $doubleArchiveGroup->status);
            $this->assertSame($doubleArchive['first']['archived_at'], $doubleArchiveGroup->archived_at?->toJSON());
            $this->assertSame($doubleArchive['first']['updated_at'], $doubleArchiveGroup->updated_at?->toJSON());
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    public function test_archive_enforces_authentication_role_account_institution_and_password_gates(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $uri = self::BASE_URI.'/'.$group->id.'/archive';

        $this->rawRequest('POST', $uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');

        $inactive = $this->institutionAdmin($institution, ['is_active' => false]);
        $this->rawRequestAs($inactive, 'POST', $uri, '')->assertForbidden()->assertJsonPath('code', 'user_inactive');

        $passwordIncomplete = $this->institutionAdmin($institution, ['must_change_password' => true]);
        $this->rawRequestAs($passwordIncomplete, 'POST', $uri, '')
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $inactiveInstitutionActor = $this->institutionAdmin($inactiveInstitution);
        $this->rawRequestAs($inactiveInstitutionActor, 'POST', $uri, '')
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRole = $this->userForRole($role, $institution);
            $this->rawRequestAs($wrongRole, 'POST', $uri, '')
                ->assertForbidden()->assertJsonPath('code', 'forbidden');
        }

        $this->assertSame(GroupStatus::Active, $group->refresh()->status);
    }

    private function institutionAdmin(Institution $institution, array $attributes = []): User
    {
        return User::factory()->institutionAdmin($institution)->create(array_merge([
            'must_change_password' => false,
        ], $attributes));
    }

    private function userForRole(UserRole $role, Institution $institution): User
    {
        $factory = match ($role) {
            UserRole::PlatformOwner => User::factory()->platformOwner(),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
        };

        return $factory->create(['must_change_password' => false]);
    }

    /** @param array<string, mixed> $query */
    private function rawRequestAs(
        User $actor,
        string $method,
        string $uri,
        string $content,
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $token = $actor->createToken('institution-group-lifecycle-api-test')->plainTextToken;
        $response = $this->rawRequest($method, $uri, $token, $content, $query, $contentType);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @param array<string, mixed> $query */
    private function rawRequest(
        string $method,
        string $uri,
        ?string $token = null,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json'];

        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call($method, $requestUri, [], [], [], $server, $content);
    }

    /** @return array{teachers: list<array<string, mixed>>, students: list<array<string, mixed>>} */
    private function membershipSnapshot(string $groupId): array
    {
        return [
            'teachers' => DB::table('group_teacher_memberships')->where('group_id', $groupId)->orderBy('id')->get()
                ->map(fn (object $row): array => (array) $row)->all(),
            'students' => DB::table('group_student_memberships')->where('group_id', $groupId)->orderBy('id')->get()
                ->map(fn (object $row): array => (array) $row)->all(),
        ];
    }

    /** @param list<array<string, mixed>> $queries */
    private function groupUpdateCount(array $queries): int
    {
        return collect($queries)
            ->filter(fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "groups"'))
            ->count();
    }

    /** @param list<array<string, mixed>> $queries */
    private function queriesContainScopedForUpdate(array $queries, string $institutionId, string $groupId): bool
    {
        return collect($queries)->contains(function (array $query) use ($institutionId, $groupId): bool {
            $sql = strtolower((string) $query['query']);
            $bindings = array_map(static fn ($binding): string => (string) $binding, $query['bindings']);

            return str_contains($sql, 'for update')
                && str_contains($sql, '"institution_id"')
                && in_array($institutionId, $bindings, true)
                && in_array($groupId, $bindings, true);
        });
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(
        string $workerPath,
        string $actorId,
        string $groupId,
        string $firstOperation,
        string $secondOperation,
    ): array {
        $lockedPath = tempnam(sys_get_temp_dir(), 's04_be_002_locked_');
        $releasePath = tempnam(sys_get_temp_dir(), 's04_be_002_release_');
        $attemptPath = tempnam(sys_get_temp_dir(), 's04_be_002_attempt_');
        $this->assertIsString($lockedPath);
        $this->assertIsString($releasePath);
        $this->assertIsString($attemptPath);
        unlink($lockedPath);
        unlink($releasePath);
        unlink($attemptPath);

        $first = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $groupId,
            $firstOperation,
            'hold',
            $lockedPath,
            $releasePath,
            $attemptPath.'.first',
        ]);
        $this->waitForFile($lockedPath, 'First worker did not acquire the PostgreSQL group row lock.');

        $second = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $groupId,
            $secondOperation,
            'normal',
            $lockedPath,
            $releasePath,
            $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'Second worker did not start its locking operation.');
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

            foreach ([$lockedPath, $releasePath, $attemptPath, $attemptPath.'.first'] as $path) {
                if (file_exists($path)) {
                    unlink($path);
                }
            }

            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }
        file_put_contents($releasePath, 'release');

        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);

        foreach ([$lockedPath, $releasePath, $attemptPath, $attemptPath.'.first'] as $path) {
            if (file_exists($path)) {
                unlink($path);
            }
        }

        return ['first' => $firstResult, 'second' => $secondResult];
    }

    private function waitForFile(string $path, string $failureMessage): void
    {
        $deadline = microtime(true) + 5;
        $fileIsReady = false;

        while (! $fileIsReady && microtime(true) < $deadline) {
            clearstatcache(true, $path);
            $fileIsReady = file_exists($path) && filesize($path) > 0;

            if ($fileIsReady) {
                break;
            }

            usleep(5_000);
        }

        $this->assertTrue($fileIsReady, $failureMessage);
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
use App\Actions\Institution\UpdateInstitutionGroup;
use App\Exceptions\Institution\GroupArchivedException;
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
    $institution = Institution::factory()->create(['name' => 'S04 BE 002 concurrency institution']);
    $actor = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $groups = [];

    foreach ([
        'archive_first' => 'Archive First Original',
        'update_first' => 'Update First Original',
        'double_archive' => 'Double Archive Original',
    ] as $key => $name) {
        $groups[$key] = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => $name,
        ])->id;
    }

    echo json_encode(['institution' => $institution->id, 'actor' => $actor->id, 'groups' => $groups], JSON_THROW_ON_ERROR);
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
$hold = $argv[6] === 'hold';
$lockedPath = $argv[7];
$releasePath = $argv[8];
$attemptPath = $argv[9];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);
DB::flushQueryLog();
DB::enableQueryLog();

if ($hold) {
    DB::beginTransaction();
}

$outcome = 'ok';
$result = null;

try {
    $result = match ($operation) {
        'update' => (new UpdateInstitutionGroup)($actor, $groupId, ['name' => 'Concurrent Updated']),
        'archive' => (new ArchiveInstitutionGroup)($actor, $groupId),
    };
} catch (GroupArchivedException) {
    $outcome = 'conflict';
}

$queries = DB::getQueryLog();

if ($hold) {
    file_put_contents($lockedPath, 'locked');
    $deadline = microtime(true) + 10;

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

$updates = count(array_filter(
    $queries,
    static fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "groups"'),
));

echo json_encode([
    'outcome' => $outcome,
    'updates' => $updates,
    'name' => $result?->name,
    'status' => $result?->status->value,
    'archived_at' => $result?->archived_at?->toJSON(),
    'updated_at' => $result?->updated_at?->toJSON(),
], JSON_THROW_ON_ERROR);
PHP;
    }
}
