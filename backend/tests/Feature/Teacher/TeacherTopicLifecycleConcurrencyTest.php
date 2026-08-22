<?php

namespace Tests\Feature\Teacher;

use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\LearningMaterial;
use App\Models\Topic;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherTopicLifecycleConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_postgresql_locks_serialize_all_required_lifecycle_races(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $workerPath = tempnam(sys_get_temp_dir(), 's05_be_004_topic_lifecycle_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        $races = [
            ['activate_group', 'activate', 'group_archive', 'ok', 'ok'],
            ['group_activate', 'group_archive', 'activate', 'ok', 'topic_not_editable'],
            ['activate_membership', 'activate', 'membership_remove', 'ok', 'ok'],
            ['membership_activate', 'membership_remove', 'activate', 'ok', 'not_found'],
            ['activate_material', 'activate', 'material_remove', 'ok', 'ok'],
            ['material_activate', 'material_remove', 'activate', 'ok', 'topic_not_editable'],
            ['upload_activate', 'upload', 'activate', 'ok', 'ok'],
            ['activate_upload', 'activate', 'upload', 'topic_not_editable', 'ok'],
            ['activate_archive', 'activate', 'topic_archive', 'ok', 'topic_not_editable'],
            ['archive_activate', 'topic_archive', 'activate', 'ok', 'topic_not_editable'],
            ['activate_close', 'activate', 'close', 'ok', 'ok'],
            ['close_activate', 'close', 'activate', 'topic_not_editable', 'ok'],
            ['close_archive', 'close', 'topic_archive', 'ok', 'ok'],
            ['archive_close', 'topic_archive', 'close', 'topic_not_editable', 'ok'],
            ['close_group', 'close', 'group_archive', 'ok', 'ok'],
            ['group_close', 'group_archive', 'close', 'ok', 'ok'],
            ['same_activate', 'activate', 'activate', 'ok', 'ok'],
            ['same_close', 'close', 'close', 'ok', 'ok'],
            ['same_archive', 'topic_archive', 'topic_archive', 'ok', 'ok'],
        ];
        $results = [];

        try {
            foreach ($races as [$scenario, $firstOperation, $secondOperation, $firstOutcome, $secondOutcome]) {
                $result = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $this->assertSame($firstOutcome, $result['first']['outcome'], $scenario.' first');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second');
                $results[$scenario] = $result;
            }

            foreach ([
                'activate_group' => TopicStatus::Active,
                'group_activate' => TopicStatus::Draft,
                'activate_membership' => TopicStatus::Active,
                'membership_activate' => TopicStatus::Draft,
                'activate_material' => TopicStatus::Active,
                'material_activate' => TopicStatus::Draft,
                'upload_activate' => TopicStatus::Active,
                'activate_upload' => TopicStatus::Draft,
                'activate_archive' => TopicStatus::Active,
                'archive_activate' => TopicStatus::Archived,
                'activate_close' => TopicStatus::Closed,
                'close_activate' => TopicStatus::Active,
                'close_archive' => TopicStatus::Archived,
                'archive_close' => TopicStatus::Closed,
                'close_group' => TopicStatus::Closed,
                'group_close' => TopicStatus::Closed,
                'same_activate' => TopicStatus::Active,
                'same_close' => TopicStatus::Closed,
                'same_archive' => TopicStatus::Archived,
            ] as $scenario => $status) {
                $this->assertSame($status, Topic::query()->findOrFail($ids['topics'][$scenario])->status, $scenario.' status');
            }

            foreach (['activate_group', 'group_activate', 'close_group', 'group_close'] as $scenario) {
                $this->assertSame(GroupStatus::Archived, Group::query()->findOrFail($ids['groups'][$scenario])->status);
            }
            foreach (['activate_membership', 'membership_activate'] as $scenario) {
                $this->assertNotNull(GroupTeacherMembership::query()
                    ->where('group_id', $ids['groups'][$scenario])
                    ->where('teacher_id', $ids['teacher'])
                    ->value('ended_at'));
            }
            foreach (['activate_material', 'material_activate'] as $scenario) {
                $this->assertNotNull(LearningMaterial::query()->findOrFail($ids['materials'][$scenario])->removed_at);
            }
            foreach (['upload_activate', 'activate_upload'] as $scenario) {
                $this->assertSame(1, LearningMaterial::query()
                    ->where('topic_id', $ids['topics'][$scenario])
                    ->whereNull('removed_at')
                    ->count());
            }

            foreach ([
                'same_activate' => 'activated_at',
                'same_close' => 'closed_at',
                'same_archive' => 'archived_at',
            ] as $scenario => $transitionTimestamp) {
                $this->assertNotNull($results[$scenario]['first'][$transitionTimestamp]);
                $this->assertSame(
                    $results[$scenario]['first'][$transitionTimestamp],
                    $results[$scenario]['second'][$transitionTimestamp],
                    $scenario.' transition timestamp',
                );
                $this->assertSame(
                    $results[$scenario]['first']['updated_at'],
                    $results[$scenario]['second']['updated_at'],
                    $scenario.' updated timestamp',
                );
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(
        string $workerPath,
        array $ids,
        string $scenario,
        string $firstOperation,
        string $secondOperation,
    ): array {
        $lockedPath = $this->unusedTempPath('s05_be_004_locked_');
        $releasePath = $this->unusedTempPath('s05_be_004_release_');
        $attemptPath = $this->unusedTempPath('s05_be_004_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
        $arguments = [
            $ids['teacher'],
            $ids['admin'],
            $ids['groups'][$scenario],
            $ids['topics'][$scenario],
            $ids['materials'][$scenario] ?? '-',
        ];

        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation, 'hold', $lockedPath, $releasePath, $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'First lifecycle worker did not finish while retaining its Group lock.');

        $second = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation, 'normal', $lockedPath, $releasePath, $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'Second lifecycle worker did not begin its locking operation.');
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
use App\Actions\Teacher\ActivateTeacherTopic;
use App\Actions\Teacher\ArchiveTeacherTopic;
use App\Actions\Teacher\CloseTeacherTopic;
use App\Actions\Teacher\RemoveTeacherLearningMaterial;
use App\Actions\Teacher\UploadTeacherLearningMaterial;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S05 BE 004 lifecycle concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $groups = [];
    $topics = [];
    $materials = [];
    $scenarios = [
        'activate_group', 'group_activate', 'activate_membership', 'membership_activate',
        'activate_material', 'material_activate', 'upload_activate', 'activate_upload',
        'activate_archive', 'archive_activate', 'activate_close', 'close_activate',
        'close_archive', 'archive_close', 'close_group', 'group_close',
        'same_activate', 'same_close', 'same_archive',
    ];
    $activeTopics = ['close_archive', 'archive_close', 'close_group', 'group_close', 'same_close'];
    $materialTopics = [
        'activate_group', 'group_activate', 'activate_membership', 'membership_activate',
        'activate_material', 'material_activate', 'activate_archive', 'archive_activate',
        'activate_close', 'close_activate', 'same_activate',
    ];

    foreach ($scenarios as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
            'name' => 'Lifecycle race '.$scenario,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $topicFactory = in_array($scenario, $activeTopics, true) ? Topic::factory()->active() : Topic::factory();
        $topic = $topicFactory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $groups[$scenario] = $group->id;
        $topics[$scenario] = $topic->id;

        if (in_array($scenario, $materialTopics, true)) {
            $file = File::factory()->create([
                'institution_id' => $institution->id,
                'uploaded_by_user_id' => $teacher->id,
                'storage_key' => 'learning-materials/'.$institution->id.'/'.$topic->id.'/'.$scenario.'.pdf',
            ]);
            $materials[$scenario] = LearningMaterial::factory()->create([
                'institution_id' => $institution->id,
                'topic_id' => $topic->id,
                'teacher_id' => $teacher->id,
                'file_id' => $file->id,
            ])->id;
        }
    }

    echo json_encode([
        'institution' => $institution->id,
        'teacher' => $teacher->id,
        'admin' => $admin->id,
        'groups' => $groups,
        'topics' => $topics,
        'materials' => $materials,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    LearningMaterial::query()->where('institution_id', $institutionId)->delete();
    File::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    Storage::disk(config('filesystems.private_files_disk'))->deleteDirectory('learning-materials/'.$institutionId);
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$admin = User::query()->findOrFail($argv[4]);
$groupId = $argv[5];
$topicId = $argv[6];
$materialId = $argv[7];
$operation = $argv[8];
$hold = $argv[9] === 'hold';
$lockedPath = $argv[10];
$releasePath = $argv[11];
$attemptPath = $argv[12];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);

if ($hold) {
    DB::beginTransaction();
    Group::query()->where('institution_id', $teacher->institution_id)->whereKey($groupId)->lockForUpdate()->firstOrFail();
}

$outcome = 'ok';
$uploadPath = tempnam(sys_get_temp_dir(), 's05_be_004_race_upload_');
file_put_contents($uploadPath, "%PDF-1.7\nRace");
$upload = new UploadedFile($uploadPath, 'race.pdf', 'application/octet-stream', UPLOAD_ERR_OK, true);

try {
    match ($operation) {
        'activate' => app(ActivateTeacherTopic::class)($teacher, $topicId),
        'close' => app(CloseTeacherTopic::class)($teacher, $topicId),
        'topic_archive' => app(ArchiveTeacherTopic::class)($teacher, $topicId),
        'group_archive' => app(ArchiveInstitutionGroup::class)($admin, $groupId),
        'membership_remove' => app(RemoveTeacherFromInstitutionGroup::class)($admin, $groupId, $teacher->id),
        'material_remove' => app(RemoveTeacherLearningMaterial::class)($teacher, $materialId),
        'upload' => app(UploadTeacherLearningMaterial::class)($teacher, $topicId, $upload, null),
    };
} catch (NotFoundHttpException) {
    $outcome = 'not_found';
} catch (TopicNotEditableException) {
    $outcome = 'topic_not_editable';
} finally {
    unlink($uploadPath);
}

if ($hold) {
    file_put_contents($lockedPath, 'locked');
    $deadline = microtime(true) + 15;
    while (! file_exists($releasePath) && microtime(true) < $deadline) {
        usleep(5_000);
    }
    if (! file_exists($releasePath)) {
        DB::rollBack();
        fwrite(STDERR, 'Timed out waiting for deterministic lifecycle race release.');
        exit(1);
    }
    DB::commit();
}

$topic = Topic::query()->findOrFail($topicId);
echo json_encode([
    'outcome' => $outcome,
    'status' => $topic->status->value,
    'activated_at' => $topic->activated_at?->toIso8601String(),
    'closed_at' => $topic->closed_at?->toIso8601String(),
    'archived_at' => $topic->archived_at?->toIso8601String(),
    'updated_at' => $topic->updated_at?->toIso8601String(),
], JSON_THROW_ON_ERROR);
PHP;
    }
}
