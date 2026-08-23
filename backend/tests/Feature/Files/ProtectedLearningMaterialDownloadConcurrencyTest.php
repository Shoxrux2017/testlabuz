<?php

namespace Tests\Feature\Files;

use App\Enums\TopicStatus;
use App\Models\File;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\LearningMaterial;
use App\Models\Topic;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ProtectedLearningMaterialDownloadConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_postgresql_locks_produce_all_download_membership_material_replace_and_activation_outcomes(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's05_be_005_download_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        $races = [
            ['student_download_first', 'student_download', 'student_membership_remove', 'ok', 'ok', 'old-student_download_first'],
            ['student_removal_first', 'student_membership_remove', 'student_download', 'ok', 'not_found', null],
            ['teacher_download_first', 'teacher_download', 'teacher_membership_remove', 'ok', 'ok', 'old-teacher_download_first'],
            ['teacher_removal_first', 'teacher_membership_remove', 'teacher_download', 'ok', 'not_found', null],
            ['material_download_first', 'teacher_download', 'material_remove', 'ok', 'ok', 'old-material_download_first'],
            ['material_removal_first', 'material_remove', 'teacher_download', 'ok', 'not_found', null],
            ['replace_download_first', 'teacher_download', 'material_replace', 'ok', 'ok', 'old-replace_download_first'],
            ['replace_first', 'material_replace', 'teacher_download', 'ok', 'ok', "%PDF-1.7\nnew-replace_first"],
        ];

        try {
            foreach ($races as [$scenario, $firstOperation, $secondOperation, $firstOutcome, $secondOutcome, $expectedBytes]) {
                $result = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $this->assertSame($firstOutcome, $result['first']['outcome'], $scenario.' first');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second');

                $downloadResult = str_contains($firstOperation, 'download') ? $result['first'] : $result['second'];
                if ($expectedBytes !== null) {
                    $this->assertSame($expectedBytes, base64_decode($downloadResult['bytes_base64'], true), $scenario.' bytes');
                    $this->assertSame(0, $downloadResult['transaction_level_before_body'], $scenario.' transaction level');
                }
            }

            foreach (['student_download_first', 'student_removal_first'] as $scenario) {
                $this->assertNotNull(GroupStudentMembership::query()
                    ->where('group_id', $ids['groups'][$scenario])
                    ->where('student_id', $ids['student'])
                    ->value('ended_at'));
            }
            foreach (['teacher_download_first', 'teacher_removal_first'] as $scenario) {
                $this->assertNotNull(GroupTeacherMembership::query()
                    ->where('group_id', $ids['groups'][$scenario])
                    ->where('teacher_id', $ids['teacher'])
                    ->value('ended_at'));
            }
            foreach (['material_download_first', 'material_removal_first'] as $scenario) {
                $this->assertNotNull(LearningMaterial::query()->findOrFail($ids['materials'][$scenario])->removed_at);
                $this->assertNotNull(File::query()->findOrFail($ids['files'][$scenario])->removed_at);
            }

            $activationFirst = $this->runOrdered($workerPath, $ids, 'activation_first', 'activate', 'student_download');
            $this->assertSame('ok', $activationFirst['first']['outcome']);
            $this->assertSame('ok', $activationFirst['second']['outcome']);
            $this->assertSame('old-activation_first', base64_decode($activationFirst['second']['bytes_base64'], true));
            $this->assertSame(0, $activationFirst['second']['transaction_level_before_body']);
            $this->assertSame(TopicStatus::Active, Topic::query()->findOrFail($ids['topics']['activation_first'])->status);

            $draftFirst = $this->runOrdered($workerPath, $ids, 'student_draft_first', 'student_download', 'activate');
            $this->assertSame('not_found', $draftFirst['first']['outcome']);
            $this->assertSame('ok', $draftFirst['second']['outcome']);
            $this->assertSame(TopicStatus::Active, Topic::query()->findOrFail($ids['topics']['student_draft_first'])->status);
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
        $lockedPath = $this->unusedTempPath('s05_be_005_locked_');
        $releasePath = $this->unusedTempPath('s05_be_005_release_');
        $attemptPath = $this->unusedTempPath('s05_be_005_attempt_');
        $donePath = $this->unusedTempPath('s05_be_005_done_');
        $arguments = [
            $ids['teacher'],
            $ids['student'],
            $ids['admin'],
            $ids['groups'][$scenario],
            $ids['topics'][$scenario],
            $ids['materials'][$scenario],
            $ids['files'][$scenario],
            $scenario,
        ];

        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation, 'hold', $lockedPath, $releasePath, $attemptPath.'.first', $donePath,
        ]);
        $this->waitForFile($lockedPath, 'First download race worker did not retain its Group lock for '.$scenario.'.');

        $second = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation, 'normal', $lockedPath, $releasePath, $attemptPath, $donePath,
        ]);
        $this->waitForFile($attemptPath, 'Second download race worker did not begin for '.$scenario.'.');
        $secondBackendPid = (int) file_get_contents($attemptPath);

        try {
            $this->waitForPostgresLock($secondBackendPid, $scenario);
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $attemptPath.'.first', $donePath]);
            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }

        file_put_contents($releasePath, 'release');
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $attemptPath.'.first', $donePath]);

        return ['first' => $firstResult, 'second' => $secondResult];
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runOrdered(
        string $workerPath,
        array $ids,
        string $scenario,
        string $firstOperation,
        string $secondOperation,
    ): array {
        $arguments = [
            $ids['teacher'],
            $ids['student'],
            $ids['admin'],
            $ids['groups'][$scenario],
            $ids['topics'][$scenario],
            $ids['materials'][$scenario],
            $ids['files'][$scenario],
            $scenario,
        ];
        $unused = '-';
        $first = json_decode($this->runWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation, 'normal', $unused, $unused, $unused, $unused,
        ]), true, flags: JSON_THROW_ON_ERROR);
        $second = json_decode($this->runWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation, 'normal', $unused, $unused, $unused, $unused,
        ]), true, flags: JSON_THROW_ON_ERROR);

        return ['first' => $first, 'second' => $second];
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
        $deadline = microtime(true) + 15;

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
        $deadline = microtime(true) + 15;
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

use App\Actions\Files\DownloadLearningMaterialFile;
use App\Actions\Institution\RemoveStudentFromInstitutionGroup;
use App\Actions\Institution\RemoveTeacherFromInstitutionGroup;
use App\Actions\Teacher\ActivateTeacherTopic;
use App\Actions\Teacher\RemoveTeacherLearningMaterial;
use App\Actions\Teacher\ReplaceTeacherLearningMaterial;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupStudentMembership;
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
    $institution = Institution::factory()->create(['name' => 'S05 BE 005 download concurrency institution']);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $student = User::factory()->student($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $groups = [];
    $topics = [];
    $materials = [];
    $files = [];
    $scenarios = [
        'student_download_first', 'student_removal_first',
        'teacher_download_first', 'teacher_removal_first',
        'material_download_first', 'material_removal_first',
        'replace_download_first', 'replace_first',
        'activation_first', 'student_draft_first',
    ];

    foreach ($scenarios as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
            'name' => 'Download race '.$scenario,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $topicFactory = in_array($scenario, ['activation_first', 'student_draft_first'], true)
            ? Topic::factory()
            : Topic::factory()->active();
        $topic = $topicFactory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $file = File::factory()->create([
            'institution_id' => $institution->id,
            'uploaded_by_user_id' => $teacher->id,
            'storage_disk' => 'local',
            'storage_key' => 'learning-materials/'.$institution->id.'/'.$scenario.'.pdf',
            'size_bytes' => strlen('old-'.$scenario),
        ]);
        $material = LearningMaterial::factory()->create([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'teacher_id' => $teacher->id,
            'file_id' => $file->id,
        ]);
        Storage::disk('local')->put($file->storage_key, 'old-'.$scenario);
        $groups[$scenario] = $group->id;
        $topics[$scenario] = $topic->id;
        $materials[$scenario] = $material->id;
        $files[$scenario] = $file->id;
    }

    echo json_encode([
        'institution' => $institution->id,
        'admin' => $admin->id,
        'teacher' => $teacher->id,
        'student' => $student->id,
        'groups' => $groups,
        'topics' => $topics,
        'materials' => $materials,
        'files' => $files,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    LearningMaterial::query()->where('institution_id', $institutionId)->delete();
    File::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupStudentMembership::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    Storage::disk('local')->deleteDirectory('learning-materials/'.$institutionId);
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$student = User::query()->findOrFail($argv[4]);
$admin = User::query()->findOrFail($argv[5]);
$groupId = $argv[6];
$topicId = $argv[7];
$materialId = $argv[8];
$fileId = $argv[9];
$scenario = $argv[10];
$operation = $argv[11];
$hold = $argv[12] === 'hold';
$lockedPath = $argv[13];
$releasePath = $argv[14];
$attemptPath = $argv[15];
$donePath = $argv[16];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
if ($attemptPath !== '-') {
    file_put_contents($attemptPath, (string) $pid);
}

if ($hold) {
    DB::beginTransaction();
    Group::query()
        ->where('institution_id', $teacher->institution_id)
        ->whereKey($groupId)
        ->lockForUpdate()
        ->firstOrFail();
}

$outcome = 'ok';
$download = null;
$uploadPath = null;

try {
    if ($operation === 'material_replace') {
        $uploadPath = tempnam(sys_get_temp_dir(), 's05_be_005_replace_');
        file_put_contents($uploadPath, "%PDF-1.7\nnew-{$scenario}");
        $upload = new UploadedFile($uploadPath, 'replacement.pdf', 'application/octet-stream', UPLOAD_ERR_OK, true);
    }

    $result = match ($operation) {
        'student_download' => app(DownloadLearningMaterialFile::class)($student, $fileId),
        'teacher_download' => app(DownloadLearningMaterialFile::class)($teacher, $fileId),
        'student_membership_remove' => app(RemoveStudentFromInstitutionGroup::class)($admin, $groupId, $student->id),
        'teacher_membership_remove' => app(RemoveTeacherFromInstitutionGroup::class)($admin, $groupId, $teacher->id),
        'material_remove' => app(RemoveTeacherLearningMaterial::class)($teacher, $materialId),
        'material_replace' => app(ReplaceTeacherLearningMaterial::class)($teacher, $materialId, $upload),
        'activate' => app(ActivateTeacherTopic::class)($teacher, $topicId),
    };

    if ($result instanceof \App\Support\Files\ProtectedFileDownload) {
        $download = $result;
    }
} catch (NotFoundHttpException) {
    $outcome = 'not_found';
} finally {
    if (is_string($uploadPath) && file_exists($uploadPath)) {
        unlink($uploadPath);
    }
}

if ($hold) {
    file_put_contents($lockedPath, 'locked');
    $deadline = microtime(true) + 20;
    while (! file_exists($releasePath) && microtime(true) < $deadline) {
        usleep(5_000);
    }
    if (! file_exists($releasePath)) {
        DB::rollBack();
        fwrite(STDERR, 'Timed out waiting for deterministic download race release.');
        exit(1);
    }
    DB::commit();
}

$bytesBase64 = null;
$transactionLevelBeforeBody = null;
if ($download instanceof \App\Support\Files\ProtectedFileDownload) {
    if ($hold && $donePath !== '-') {
        $deadline = microtime(true) + 20;
        while (! file_exists($donePath) && microtime(true) < $deadline) {
            usleep(5_000);
        }
        if (! file_exists($donePath)) {
            fwrite(STDERR, 'Timed out waiting for competing download transaction completion.');
            exit(1);
        }
    }
    $transactionLevelBeforeBody = DB::transactionLevel();
    $bytes = stream_get_contents($download->stream);
    fclose($download->stream);
    $bytesBase64 = base64_encode($bytes);
}

if (! $hold && $donePath !== '-') {
    file_put_contents($donePath, 'done');
}

echo json_encode([
    'outcome' => $outcome,
    'bytes_base64' => $bytesBase64,
    'transaction_level_before_body' => $transactionLevelBeforeBody,
], JSON_THROW_ON_ERROR);
PHP;
    }
}
