<?php

namespace Tests\Feature\Teacher;

use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class TeacherTopicMutationApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/teacher/topics';

    public function test_create_persists_server_owned_draft_and_returns_exact_resource_with_utc_lesson_time(): void
    {
        [$institution, $teacher, $admin, $group] = $this->authoringContext();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);

        $response = $this->jsonRequest($teacher, 'POST', self::URI, [
            'group_id' => $group->id,
            'title' => '  Internet Basics  ',
            'description' => null,
            'subject' => '  Informatics  ',
            'student_instructions' => '  Study the materials.  ',
            'lesson_at' => '2026-08-25T09:00:00+05:00',
        ]);

        $response->assertCreated()->assertJsonPath('message', 'Topic created successfully.');
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertTopicResource($response->json('data'));
        $this->assertSame('Internet Basics', $response->json('data.title'));
        $this->assertSame('Informatics', $response->json('data.subject'));
        $this->assertSame('Study the materials.', $response->json('data.student_instructions'));
        $this->assertSame('2026-08-25T04:00:00Z', $response->json('data.lesson_at'));
        $this->assertSame('draft', $response->json('data.status'));
        $this->assertNull($response->json('data.activated_at'));
        $this->assertNull($response->json('data.closed_at'));
        $this->assertNull($response->json('data.archived_at'));

        $topic = Topic::query()->findOrFail($response->json('data.id'));
        $this->assertSame($institution->id, $topic->institution_id);
        $this->assertSame($teacher->id, $topic->teacher_id);
        $this->assertSame($group->id, $topic->group_id);
        $this->assertSame(TopicStatus::Draft, $topic->status);
        $this->assertSame('2026-08-25T04:00:00+00:00', $topic->lesson_at?->toIso8601String());

        $nullLesson = $this->jsonRequest($teacher, 'POST', self::URI, [
            'group_id' => $group->id,
            'title' => 'No scheduled lesson',
            'description' => 'Description',
            'subject' => 'Informatics',
            'student_instructions' => 'Read.',
            'lesson_at' => null,
        ]);
        $nullLesson->assertCreated()->assertJsonPath('data.lesson_at', null);

        foreach (['institution_id', 'teacher_id', 'membership', 'storage', '"materials":', '"results":'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public function test_create_requires_current_assignment_to_active_same_institution_group(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $active = $this->group($institution, $admin);
        $unrelated = $this->group($institution, $admin);
        $ended = $this->group($institution, $admin);
        $archived = $this->group($institution, $admin, archived: true);
        $foreign = $this->group($foreignInstitution, $foreignAdmin);
        $this->membership($institution, $active, $teacher, $admin);
        $this->membership($institution, $ended, $teacher, $admin, ended: true);
        $this->membership($institution, $archived, $teacher, $admin);

        foreach (['00000000-0000-0000-0000-000000000099', $unrelated->id, $ended->id, $archived->id, $foreign->id] as $groupId) {
            $this->jsonRequest($teacher, 'POST', self::URI, $this->validCreatePayload($groupId))
                ->assertNotFound()
                ->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertDatabaseCount('topics', 0);
    }

    public function test_create_strictly_rejects_invalid_shapes_fields_and_protected_input(): void
    {
        [, $teacher, , $group] = $this->authoringContext();

        foreach (['', '{', '42', '[]', 'null'] as $content) {
            $this->rawRequest($teacher, 'POST', self::URI, $content)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach (['institution_id', 'teacher_id', 'status', 'activated_at', 'closed_at', 'archived_at', 'created_at', 'updated_at', 'unexpected'] as $protected) {
            $this->jsonRequest($teacher, 'POST', self::URI, [
                ...$this->validCreatePayload($group->id),
                $protected => 'forbidden',
            ])->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->jsonRequest($teacher, 'POST', self::URI, $this->validCreatePayload($group->id), ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        foreach ([
            ['group_id' => null],
            ['group_id' => 'not-a-uuid'],
            ['title' => null],
            ['title' => '   '],
            ['title' => str_repeat('x', 256)],
            ['description' => 10],
            ['subject' => null],
            ['subject' => '   '],
            ['subject' => str_repeat('x', 161)],
            ['student_instructions' => null],
            ['student_instructions' => '   '],
        ] as $override) {
            $this->jsonRequest($teacher, 'POST', self::URI, [...$this->validCreatePayload($group->id), ...$override])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->assertDatabaseCount('topics', 0);
    }

    public function test_create_validates_numeric_offset_against_institution_timezone_and_dst_gaps(): void
    {
        [$institution, $teacher, , $group] = $this->authoringContext();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'America/New_York']);

        foreach ([
            '2026-08-25T09:00:00',
            '2026-08-25T13:00:00Z',
            '2026-08-25T09:00:00-05:00',
            '2026-03-08T02:30:00-05:00',
            '2026-02-30T09:00:00-05:00',
        ] as $lessonAt) {
            $this->jsonRequest($teacher, 'POST', self::URI, [
                ...$this->validCreatePayload($group->id),
                'lesson_at' => $lessonAt,
            ])->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->jsonRequest($teacher, 'POST', self::URI, [
            ...$this->validCreatePayload($group->id),
            'lesson_at' => '2026-08-25T09:00:00-04:00',
        ])->assertCreated()->assertJsonPath('data.lesson_at', '2026-08-25T13:00:00Z');
    }

    public function test_update_changes_only_supplied_metadata_for_draft_and_active_topics_and_can_clear_nullable_fields(): void
    {
        [$institution, $teacher, $admin, $group] = $this->authoringContext();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
        $draft = $this->topic($institution, $group, $teacher, [
            'description' => 'Old description',
            'lesson_at' => CarbonImmutable::parse('2026-08-25 04:00:00', 'UTC'),
        ]);
        $active = $this->topic($institution, $group, $teacher, [], TopicStatus::Active);

        $before = $draft->only(['institution_id', 'teacher_id', 'group_id', 'status', 'activated_at', 'closed_at', 'archived_at']);
        CarbonImmutable::setTestNow('2026-08-22 12:00:00 UTC');
        try {
            $response = $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$draft->id, [
                'title' => '  Updated title  ',
                'description' => null,
                'lesson_at' => null,
            ]);
        } finally {
            CarbonImmutable::setTestNow();
        }

        $response->assertOk()->assertJsonPath('message', 'Topic updated successfully.');
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertTopicResource($response->json('data'));
        $this->assertSame('Updated title', $response->json('data.title'));
        $this->assertNull($response->json('data.description'));
        $this->assertNull($response->json('data.lesson_at'));

        $draft->refresh();
        $this->assertSame($before, $draft->only(array_keys($before)));
        $this->assertSame('2026-08-22T12:00:00+00:00', $draft->updated_at->toIso8601String());

        $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$active->id, [
            'subject' => '  Advanced Informatics  ',
            'student_instructions' => '  Complete the exercise.  ',
            'lesson_at' => '2026-08-26T10:30:00+05:00',
        ])->assertOk()
            ->assertJsonPath('data.subject', 'Advanced Informatics')
            ->assertJsonPath('data.student_instructions', 'Complete the exercise.')
            ->assertJsonPath('data.lesson_at', '2026-08-26T05:30:00Z')
            ->assertJsonPath('data.status', 'active');
    }

    public function test_exact_update_no_op_preserves_updated_at(): void
    {
        [$institution, $teacher, , $group] = $this->authoringContext();
        $originalUpdatedAt = CarbonImmutable::parse('2026-08-22 08:00:00', 'UTC');
        $topic = $this->topic($institution, $group, $teacher, [
            'title' => 'Same title',
            'updated_at' => $originalUpdatedAt,
        ]);

        CarbonImmutable::setTestNow('2026-08-22 14:00:00 UTC');
        try {
            $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$topic->id, ['title' => '  Same title  '])
                ->assertOk()
                ->assertJsonPath('message', 'Topic updated successfully.')
                ->assertJsonPath('data.updated_at', '2026-08-22T08:00:00Z');
        } finally {
            CarbonImmutable::setTestNow();
        }

        $this->assertSame('2026-08-22T08:00:00+00:00', $topic->fresh()?->updated_at->toIso8601String());
    }

    public function test_update_authorization_precedes_editability_and_returns_exact_lifecycle_conflict(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $otherTeacher = $this->teacher($institution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $group = $this->group($institution, $admin);
        $archivedGroup = $this->group($institution, $admin, archived: true);
        $endedGroup = $this->group($institution, $admin);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin);
        $this->membership($institution, $group, $teacher, $admin);
        $this->membership($institution, $archivedGroup, $teacher, $admin);
        $this->membership($institution, $endedGroup, $teacher, $admin, ended: true);

        $closed = $this->topic($institution, $group, $teacher, [], TopicStatus::Closed);
        $archived = $this->topic($institution, $group, $teacher, [], TopicStatus::Archived);
        $archivedGroupTopic = $this->topic($institution, $archivedGroup, $teacher);

        foreach ([$closed, $archived, $archivedGroupTopic] as $notEditable) {
            $response = $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$notEditable->id, ['title' => 'Changed']);
            $response->assertConflict();
            $this->assertSame([
                'message' => 'The topic is not editable.',
                'code' => 'topic_not_editable',
                'errors' => [],
            ], $response->json());
        }

        $hiddenTopics = [
            $this->topic($institution, $endedGroup, $teacher, [], TopicStatus::Closed),
            $this->topic($institution, $group, $otherTeacher, [], TopicStatus::Closed),
            $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher, [], TopicStatus::Closed),
        ];

        foreach (['not-a-uuid', '00000000-0000-0000-0000-000000000099', ...collect($hiddenTopics)->pluck('id')->all()] as $hidden) {
            $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$hidden, ['title' => 'Changed'])
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_update_strictly_rejects_empty_invalid_unknown_protected_and_query_input(): void
    {
        [$institution, $teacher, , $group] = $this->authoringContext();
        $topic = $this->topic($institution, $group, $teacher);

        foreach (['', '{', '42', '[]', 'null', '{}'] as $content) {
            $this->rawRequest($teacher, 'PATCH', self::URI.'/'.$topic->id, $content)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach (['institution_id', 'teacher_id', 'group_id', 'status', 'activated_at', 'closed_at', 'archived_at', 'created_at', 'updated_at', 'unexpected'] as $protected) {
            $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$topic->id, [$protected => 'forbidden'])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach ([
            ['title' => null],
            ['title' => '   '],
            ['title' => str_repeat('x', 256)],
            ['description' => 1],
            ['subject' => null],
            ['subject' => str_repeat('x', 161)],
            ['student_instructions' => null],
            ['lesson_at' => '2026-08-25T04:00:00Z'],
        ] as $payload) {
            $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$topic->id, $payload)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->jsonRequest($teacher, 'PATCH', self::URI.'/'.$topic->id, ['title' => 'Valid'], ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_postgresql_locks_serialize_create_and_update_against_archive_and_membership_removal(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $workerPath = tempnam(sys_get_temp_dir(), 's05_be_002_topic_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach ([
                ['create_archive', 'create', 'archive', 'ok', 'ok'],
                ['archive_create', 'archive', 'create', 'ok', 'not_found'],
                ['create_remove', 'create', 'remove', 'ok', 'ok'],
                ['remove_create', 'remove', 'create', 'ok', 'not_found'],
                ['update_archive', 'update', 'archive', 'ok', 'ok'],
                ['archive_update', 'archive', 'update', 'ok', 'topic_not_editable'],
                ['update_remove', 'update', 'remove', 'ok', 'ok'],
                ['remove_update', 'remove', 'update', 'ok', 'not_found'],
            ] as [$scenario, $firstOperation, $secondOperation, $firstOutcome, $secondOutcome]) {
                $result = $this->runRace(
                    $workerPath,
                    $ids,
                    $scenario,
                    $firstOperation,
                    $secondOperation,
                );
                $this->assertSame($firstOutcome, $result['first']['outcome'], $scenario.' first');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second');
            }

            $this->assertSame(1, Topic::query()->where('group_id', $ids['groups']['create_archive'])->count());
            $this->assertSame(0, Topic::query()->where('group_id', $ids['groups']['archive_create'])->count());
            $this->assertSame(1, Topic::query()->where('group_id', $ids['groups']['create_remove'])->count());
            $this->assertSame(0, Topic::query()->where('group_id', $ids['groups']['remove_create'])->count());
            $this->assertSame('Race updated', Topic::query()->findOrFail($ids['topics']['update_archive'])->title);
            $this->assertSame('Original', Topic::query()->findOrFail($ids['topics']['archive_update'])->title);
            $this->assertSame('Race updated', Topic::query()->findOrFail($ids['topics']['update_remove'])->title);
            $this->assertSame('Original', Topic::query()->findOrFail($ids['topics']['remove_update'])->title);
            $this->assertSame(GroupStatus::Archived, Group::query()->findOrFail($ids['groups']['create_archive'])->status);
            $this->assertSame(GroupStatus::Archived, Group::query()->findOrFail($ids['groups']['archive_update'])->status);
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /** @return array{Institution, User, User, Group} */
    private function authoringContext(): array
    {
        $institution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $group = $this->group($institution, $admin);
        $this->membership($institution, $group, $teacher, $admin);

        return [$institution, $teacher, $admin, $group];
    }

    private function teacher(Institution $institution): User
    {
        return User::factory()->teacher($institution)->create(['must_change_password' => false]);
    }

    private function admin(Institution $institution): User
    {
        return User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    }

    private function group(Institution $institution, User $admin, array $attributes = [], bool $archived = false): Group
    {
        $factory = $archived ? Group::factory()->archived() : Group::factory();

        return $factory->create(array_merge([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ], $attributes));
    }

    private function membership(Institution $institution, Group $group, User $teacher, User $admin, bool $ended = false): void
    {
        $factory = $ended ? GroupTeacherMembership::factory()->ended() : GroupTeacherMembership::factory();
        $factory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
    }

    private function topic(
        Institution $institution,
        Group $group,
        User $teacher,
        array $attributes = [],
        TopicStatus $status = TopicStatus::Draft,
    ): Topic {
        $factory = match ($status) {
            TopicStatus::Active => Topic::factory()->active(),
            TopicStatus::Closed => Topic::factory()->closed(),
            TopicStatus::Archived => Topic::factory()->archivedFromDraft(),
            TopicStatus::Draft => Topic::factory(),
        };

        return $factory->create(array_merge([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'title' => 'Original',
        ], $attributes));
    }

    /** @return array<string, mixed> */
    private function validCreatePayload(string $groupId): array
    {
        return [
            'group_id' => $groupId,
            'title' => 'Internet Basics',
            'description' => null,
            'subject' => 'Informatics',
            'student_instructions' => 'Study the materials.',
            'lesson_at' => null,
        ];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $query
     */
    private function jsonRequest(User $actor, string $method, string $uri, array $payload, array $query = []): TestResponse
    {
        return $this->rawRequest($actor, $method, $uri, json_encode($payload, JSON_THROW_ON_ERROR), $query);
    }

    /** @param array<string, mixed> $query */
    private function rawRequest(User $actor, string $method, string $uri, string $content, array $query = []): TestResponse
    {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('teacher-topic-mutation-api-test')->plainTextToken,
        ];

        $response = $this->call($method, $requestUri, [], [], [], $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @param array<string, mixed> $resource */
    private function assertTopicResource(array $resource): void
    {
        $this->assertSame([
            'id',
            'group',
            'title',
            'description',
            'subject',
            'student_instructions',
            'lesson_at',
            'status',
            'activated_at',
            'closed_at',
            'archived_at',
            'created_at',
            'updated_at',
        ], array_keys($resource));
        $this->assertSame(['id', 'name', 'level', 'subject_direction', 'status'], array_keys($resource['group']));
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(
        string $workerPath,
        array $ids,
        string $scenario,
        string $firstOperation,
        string $secondOperation,
    ): array {
        $lockedPath = $this->unusedTempPath('s05_be_002_locked_');
        $releasePath = $this->unusedTempPath('s05_be_002_release_');
        $attemptPath = $this->unusedTempPath('s05_be_002_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
        $arguments = [
            $ids['teacher'],
            $ids['admin'],
            $ids['groups'][$scenario],
            $ids['topics'][$scenario] ?? '-',
        ];

        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation, 'hold', $lockedPath, $releasePath, $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'First Topic worker did not finish while retaining its locks.');

        $second = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation, 'normal', $lockedPath, $releasePath, $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'Second Topic worker did not begin its locking operation.');
        $secondBackendPid = (int) file_get_contents($attemptPath);

        try {
            $this->waitForPostgresLock($secondBackendPid, $scenario);
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath]);
            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }

        file_put_contents($releasePath, 'release');
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath]);

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
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('Second worker never entered a PostgreSQL lock wait for '.$scenario.'. Activity: '.json_encode($lastActivity));
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

use App\Actions\Institution\ArchiveInstitutionGroup;
use App\Actions\Institution\RemoveTeacherFromInstitutionGroup;
use App\Actions\Teacher\CreateTeacherTopic;
use App\Actions\Teacher\UpdateTeacherTopic;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
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
    $institution = Institution::factory()->create(['name' => 'S05 BE 002 concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $groups = [];
    $topics = [];
    $scenarios = [
        'create_archive', 'archive_create', 'create_remove', 'remove_create',
        'update_archive', 'archive_update', 'update_remove', 'remove_update',
    ];

    foreach ($scenarios as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
            'name' => 'Race '.$scenario,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $groups[$scenario] = $group->id;

        if (str_starts_with($scenario, 'update_') || str_ends_with($scenario, '_update')) {
            $topics[$scenario] = Topic::factory()->create([
                'institution_id' => $institution->id,
                'group_id' => $group->id,
                'teacher_id' => $teacher->id,
                'title' => 'Original',
            ])->id;
        }
    }

    echo json_encode([
        'institution' => $institution->id,
        'teacher' => $teacher->id,
        'admin' => $admin->id,
        'groups' => $groups,
        'topics' => $topics,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$admin = User::query()->findOrFail($argv[4]);
$groupId = $argv[5];
$topicId = $argv[6];
$operation = $argv[7];
$hold = $argv[8] === 'hold';
$lockedPath = $argv[9];
$releasePath = $argv[10];
$attemptPath = $argv[11];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);

if ($hold) {
    DB::beginTransaction();
}

$outcome = 'ok';

try {
    match ($operation) {
        'create' => app(CreateTeacherTopic::class)($teacher, [
            'group_id' => $groupId,
            'title' => 'Race created',
            'description' => null,
            'subject' => 'Concurrency',
            'student_instructions' => 'Read.',
            'lesson_at' => null,
        ]),
        'update' => app(UpdateTeacherTopic::class)($teacher, $topicId, ['title' => 'Race updated']),
        'archive' => app(ArchiveInstitutionGroup::class)($admin, $groupId),
        'remove' => app(RemoveTeacherFromInstitutionGroup::class)($admin, $groupId, $teacher->id),
    };
} catch (NotFoundHttpException) {
    $outcome = 'not_found';
} catch (TopicNotEditableException) {
    $outcome = 'topic_not_editable';
}

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

echo json_encode(['outcome' => $outcome], JSON_THROW_ON_ERROR);
PHP;
    }
}
