<?php

namespace Tests\Feature\Teacher;

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class TeacherBlitzCloseConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    #[DataProvider('competingOperations')]
    public function test_close_serializes_timeout_answers_files_and_repeat_close(string $firstOperation, string $secondOperation, bool $due): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's08_be_007_close_worker_');
        file_put_contents($workerPath, $this->workerSource());
        $ids = $this->runWorker([$workerPath, base_path(), 'setup']);
        try {
            $results = $this->runRace($workerPath, $ids, $firstOperation, $secondOperation, $due);
            $first = $results['first'];
            $last = $results['second'];
            $this->assertSame('ok', $first['outcome']);
            $this->assertSame(in_array($secondOperation, ['typed', 'file'], true) ? 'blitz_not_active' : 'ok', $last['outcome']);
            $this->assertSame('closed', $last['blitz']['status']);
            $this->assertSame($due ? 'timed_out_finalized' : 'submitted', $last['attempt']['status']);
            $this->assertSame($due ? 'timeout_auto_submit' : 'task_closed_auto_finalize', $last['attempt']['finalization_reason']);
            $instant = $due ? '2026-09-17 09:10:00' : ($firstOperation === 'close' ? '2026-09-17 09:01:00' : '2026-09-17 09:02:00');
            $this->assertTrue(CarbonImmutable::parse($instant, 'UTC')->equalTo($last['attempt']['finalized_at']));
            $this->assertTrue(CarbonImmutable::parse($instant, 'UTC')->equalTo($last['attempt']['locked_at']));
            $this->assertNull($last['attempt']['submitted_at']);
            $this->assertSame(1, $first['attempt_writes'] + $last['attempt_writes']);
            $this->assertSame($first['pair'], $last['pair']);
            $this->assertSame($ids['pair_before'], $last['pair']);
            $this->assertSame($ids['recipients_before'], $last['recipients']);
            $this->assertSame($first['answers'], $last['answers']);
            if (in_array($firstOperation, ['close', 'timeout'], true)) {
                $this->assertSame($first['attempt'], $last['attempt']);
                $this->assertSame($ids['answers_before'], $last['answers']);
            }
            if ($firstOperation === 'close') {
                $this->assertSame($first['blitz'], $last['blitz']);
            }
            if ($secondOperation === 'timeout') {
                $this->assertSame(0, $last['finalized']);
            }
            if ($firstOperation === 'timeout') {
                $this->assertSame(1, $first['finalized']);
            }
            $this->assertSame($firstOperation === 'typed' ? 'committed typed answer' : 'initial answer', $last['text']);
            $this->assertSame($firstOperation === 'file' ? 'replacement.pdf' : 'initial.pdf', $last['file']['original_name']);
            $this->assertSame($ids['file'], $last['file']['id']);
            $this->assertTrue($last['current_blob_exists']);
            $this->assertCount(1, $last['blob_keys']);
            foreach ($last['answers'] as $answer) {
                $this->assertSame('pending', $answer['checking_status']);
                foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
                    $this->assertNull($answer[$field]);
                }
            }
            if ($secondOperation === 'file') {
                $this->assertCount(1, $last['stored']);
                $this->assertSame([['key' => $last['stored'][0], 'operation' => 'student_submission_compensation', 'deleted' => true]], $last['cleanups']);
                $this->assertNotContains($last['stored'][0], $last['blob_keys']);
                $this->assertSame($ids['original_key'], $last['file']['storage_key']);
                $this->assertSame($ids['original_bytes'], $last['current_blob']);
            }
            if ($firstOperation === 'file') {
                $this->assertSame([['key' => $ids['original_key'], 'operation' => 'student_submission_replace_old_blob_cleanup', 'deleted' => true]], $first['cleanups']);
                $this->assertSame("%PDF-1.7\nreplacement\n%%EOF\n", $last['current_blob']);
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', json_encode($ids, JSON_THROW_ON_ERROR)]);
            unlink($workerPath);
        }
    }

    public static function competingOperations(): array
    {
        return [
            'close before due reconciler' => ['close', 'timeout', true],
            'due reconciler before close' => ['timeout', 'close', true],
            'close before typed write' => ['close', 'typed', false],
            'typed write before close' => ['typed', 'close', false],
            'close before file write' => ['close', 'file', false],
            'file write before close' => ['file', 'close', false],
            'concurrent close' => ['close', 'close', false],
        ];
    }

    private function runRace(string $workerPath, array $ids, string $firstOperation, string $secondOperation, bool $due): array
    {
        $ready = $this->signalPath();
        $release = $this->signalPath();
        $started = $this->signalPath();
        $staged = $this->signalPath();
        $arguments = [$workerPath, base_path(), 'run', json_encode($ids, JSON_THROW_ON_ERROR)];
        $first = $this->startWorker([...$arguments, $firstOperation, 'hold', $due ? 'due' : 'future', $ready, $release, $started.'.first', $staged.'.first']);
        $second = null;
        try {
            $this->waitForFile($ready);
            $firstPid = (int) file_get_contents($ready);
            $second = $this->startWorker([...$arguments, $secondOperation, 'normal', $due ? 'due' : 'future', $ready, $release, $started, $staged]);
            $this->waitForFile($started);
            if ($secondOperation === 'file') {
                $this->waitForFile($staged);
            }
            $this->waitForLock((int) file_get_contents($started), $firstPid);
        } finally {
            file_put_contents($release, 'release');
            try {
                $firstResult = $this->finishWorker($first);
                $secondResult = $second === null ? null : $this->finishWorker($second);
            } finally {
                foreach ([$ready, $release, $started, $started.'.first', $staged, $staged.'.first'] as $path) {
                    if (file_exists($path)) {
                        unlink($path);
                    }
                }
            }
        }

        return ['first' => $firstResult, 'second' => $secondResult];
    }

    private function signalPath(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's08_be_007_close_signal_');
        unlink($path);

        return $path;
    }

    private function waitForFile(string $path): void
    {
        $deadline = microtime(true) + 10;
        do {
            clearstatcache(true, $path);
            if (file_exists($path) && filesize($path) > 0) {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('Close race did not reach its deterministic transaction barrier.');
    }

    private function waitForLock(int $waitingPid, int $blockingPid): void
    {
        $deadline = microtime(true) + 10;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $state = DB::selectOne('select wait_event_type, ? = any(pg_blocking_pids(pid)) as blocked_by_first from pg_stat_activity where pid = ?', [$blockingPid, $waitingPid]);
            if ($state !== null && $state->wait_event_type === 'Lock' && $state->blocked_by_first) {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('Competing operation did not wait on the winning PostgreSQL transaction.');
    }

    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open([PHP_BINARY, ...$arguments], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
        $this->assertIsResource($process);
        fclose($pipes[0]);

        return ['process' => $process, 'pipes' => $pipes];
    }

    private function finishWorker(array $worker): array
    {
        $stdout = stream_get_contents($worker['pipes'][1]);
        $stderr = stream_get_contents($worker['pipes'][2]);
        fclose($worker['pipes'][1]);
        fclose($worker['pipes'][2]);
        $exitCode = proc_close($worker['process']);
        $this->assertSame(0, $exitCode, $stderr."\nSTDOUT: {$stdout}");

        return json_decode(trim($stdout), true, flags: JSON_THROW_ON_ERROR);
    }

    private function runWorker(array $arguments): array
    {
        return $this->finishWorker($this->startWorker($arguments));
    }

    private function workerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Actions\Student\SaveStudentBlitzAttemptAnswer;
use App\Actions\Student\SaveStudentBlitzFileAnswer;
use App\Actions\Teacher\CloseTeacherBlitz;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Models\AnswerFile;
use App\Models\AnswerTextValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
if (DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new LogicException('Close concurrency workers require the isolated PostgreSQL testing database.');
}
$mode = $argv[2];
Carbon::setTestNow('2026-09-17 09:00:00 UTC');
CarbonImmutable::setTestNow('2026-09-17 09:00:00 UTC');
$ids = $mode === 'setup' ? [] : json_decode($argv[3], true, flags: JSON_THROW_ON_ERROR);
$storageRoot = $ids['storage_root'] ?? storage_path('framework/testing/blitz-close-'.Str::uuid());
config(['filesystems.private_files_disk' => 'blitz_close_race', 'filesystems.disks.blitz_close_race' => [
    'driver' => 'local', 'root' => $storageRoot, 'visibility' => 'private', 'throw' => true,
]]);

if ($mode === 'setup') {
    $fixture = new class
    {
        use BuildsTeacherBlitzContext;

        public function create(): array
        {
            [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext(TopicStatus::Active);
            $student = $this->eligibleBlitzStudent($institution, $admin, $group, ['must_change_password' => false]);
            $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Active,
                assessmentAttributes: ['total_possible_points' => '2.000000']);
            $attempt = $this->blitzAttempt($assessment, $student, $teacher, [
                'started_at' => now(), 'deadline_at' => now()->addMinutes(10), 'possible_points' => '2.000000',
            ]);
            $pair = $this->officialBlitzPair($assessment, $teacher, true);

            return [$institution, $teacher, $student, $assessment, $attempt, $pair];
        }
    };
    [$institution, $teacher, $student, $assessment, $attempt, $pair] = $fixture->create();
    $typedQuestion = Question::factory()->openWritten()->create(['assessment_id' => $assessment->id, 'institution_id' => $institution->id, 'position' => 1]);
    $fileQuestion = Question::factory()->fileBased()->create(['assessment_id' => $assessment->id, 'institution_id' => $institution->id, 'position' => 2]);
    $typedAnswer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $typedQuestion->id]);
    AnswerTextValue::factory()->create(['answer_id' => $typedAnswer->id, 'text_value' => 'initial answer']);
    $fileAnswer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $fileQuestion->id]);
    $bytes = "%PDF-1.7\ninitial\n%%EOF\n";
    $key = 'student-submissions/'.$institution->id.'/'.$attempt->id.'/'.$fileQuestion->id.'/'.Str::uuid().'.pdf';
    $file = File::factory()->studentSubmission()->create([
        'institution_id' => $institution->id, 'uploaded_by_user_id' => $student->id,
        'original_name' => 'initial.pdf', 'storage_disk' => 'blitz_close_race', 'storage_key' => $key,
        'mime_type' => 'application/pdf', 'extension' => 'pdf', 'size_bytes' => strlen($bytes), 'checksum_sha256' => hash('sha256', $bytes),
    ]);
    AnswerFile::factory()->create(['answer_id' => $fileAnswer->id, 'file_id' => $file->id]);
    Storage::disk('blitz_close_race')->put($key, $bytes);
    echo json_encode([
        'institution' => $institution->id, 'teacher' => $teacher->id, 'student' => $student->id,
        'assessment' => $assessment->id, 'attempt' => $attempt->id, 'pair' => $pair->id,
        'typed_question' => $typedQuestion->id, 'file_question' => $fileQuestion->id,
        'typed_answer' => $typedAnswer->id, 'file' => $file->id, 'original_key' => $key, 'original_bytes' => $bytes,
        'storage_root' => $storageRoot, 'pair_before' => $pair->fresh()->getAttributes(),
        'recipients_before' => AssessmentStudent::query()->where('assessment_id', $assessment->id)->orderBy('id')->get()->map->getAttributes()->all(),
        'answers_before' => AttemptAnswer::query()->where('attempt_id', $attempt->id)->orderBy('id')->get()->map->getAttributes()->all(),
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $resolvedRoot = realpath($storageRoot);
    $testingRoot = realpath(storage_path('framework/testing'));
    if ($resolvedRoot === false || $testingRoot === false || dirname($resolvedRoot) !== $testingRoot
        || ! str_starts_with(basename($resolvedRoot), 'blitz-close-')
        || ! Str::isUuid(substr(basename($resolvedRoot), strlen('blitz-close-')))) {
        throw new LogicException('Refusing cleanup outside generated close fixture storage.');
    }
    DB::transaction(function () use ($ids): void {
        foreach ([AnswerFile::class, AnswerTextValue::class, AttemptAnswer::class, File::class, AssessmentAttempt::class,
            Question::class, TopicResultPair::class, AssessmentStudent::class, BlitzTask::class, Assessment::class,
            Topic::class, GroupStudentMembership::class, GroupTeacherMembership::class, Group::class,
            InstitutionSetting::class, User::class] as $model) {
            $model::query()->where('institution_id', $ids['institution'])->delete();
        }
        Institution::query()->whereKey($ids['institution'])->delete();
    });
    (new \Illuminate\Filesystem\Filesystem)->deleteDirectory($resolvedRoot);
    echo '{}';
    exit(0);
}

$operation = $argv[4];
$hold = $argv[5] === 'hold';
$due = $argv[6] === 'due';
$ready = $argv[7];
$release = $argv[8];
$started = $argv[9];
$staged = $argv[10];
$instant = $due ? ($hold ? '2026-09-17 09:10:00 UTC' : '2026-09-17 09:12:00 UTC')
    : ($hold ? '2026-09-17 09:01:00 UTC' : '2026-09-17 09:02:00 UTC');
Carbon::setTestNow($instant);
CarbonImmutable::setTestNow($instant);
DB::statement("set lock_timeout = '10s'");
$pid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($started, (string) $pid);
$attemptWrites = 0;
DB::listen(function ($query) use (&$attemptWrites): void {
    if (str_starts_with($query->sql, 'update "assessment_attempts"')) {
        $attemptWrites++;
    }
});
$storage = new class($staged) extends PrivateFileStorage
{
    public array $stored = [];
    public array $cleanups = [];
    public function __construct(private readonly string $staged) {}
    public function store(UploadedFile $upload, string $key): string
    {
        $disk = parent::store($upload, $key);
        $this->stored[] = $key;
        file_put_contents($this->staged, $key);
        return $disk;
    }
    public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
    {
        $deleted = parent::deleteBestEffort($diskName, $storageKey, $operation, $fileId);
        $this->cleanups[] = ['key' => $storageKey, 'operation' => $operation, 'deleted' => $deleted];
        return $deleted;
    }
};
$app->instance(PrivateFileStorage::class, $storage);
$teacher = User::query()->findOrFail($ids['teacher']);
$student = User::query()->findOrFail($ids['student']);
$outcome = 'ok';
$finalized = null;
$uploadPath = null;
if ($hold) {
    DB::beginTransaction();
}
try {
    try {
        if ($operation === 'close') {
            app(CloseTeacherBlitz::class)($teacher, $ids['assessment']);
        } elseif ($operation === 'timeout') {
            $finalized = app(FinalizeTimedOutBlitzAttempts::class)($ids['institution'], $ids['assessment']);
        } elseif ($operation === 'typed') {
            app(SaveStudentBlitzAttemptAnswer::class)($student, $ids['attempt'], $ids['typed_question'], ['type' => 'open_written', 'text' => 'committed typed answer']);
        } else {
            $uploadPath = tempnam(sys_get_temp_dir(), 's08_be_007_close_upload_');
            file_put_contents($uploadPath, "%PDF-1.7\nreplacement\n%%EOF\n");
            $upload = new UploadedFile($uploadPath, 'replacement.pdf', 'application/pdf', UPLOAD_ERR_OK, true);
            app(SaveStudentBlitzFileAnswer::class)($student, $ids['attempt'], $ids['file_question'], $upload);
        }
    } catch (StudentBlitzNotActiveException) {
        $outcome = 'blitz_not_active';
    }
    $snapshot = [
        'outcome' => $outcome, 'finalized' => $finalized, 'attempt_writes' => $attemptWrites,
        'attempt' => AssessmentAttempt::query()->findOrFail($ids['attempt'])->getAttributes(),
        'blitz' => BlitzTask::query()->findOrFail($ids['assessment'])->getAttributes(),
        'pair' => TopicResultPair::query()->findOrFail($ids['pair'])->getAttributes(),
        'recipients' => AssessmentStudent::query()->where('assessment_id', $ids['assessment'])->orderBy('id')->get()->map->getAttributes()->all(),
        'answers' => AttemptAnswer::query()->where('attempt_id', $ids['attempt'])->orderBy('id')->get()->map->getAttributes()->all(),
        'text' => AnswerTextValue::query()->where('answer_id', $ids['typed_answer'])->value('text_value'),
        'file' => File::query()->findOrFail($ids['file'])->getAttributes(),
    ];
    if ($hold) {
        file_put_contents($ready, (string) $pid);
        $deadline = microtime(true) + 15;
        do {
            clearstatcache(true, $release);
            if (file_exists($release)) {
                break;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        if (! file_exists($release)) {
            throw new RuntimeException('Timed out waiting for close race barrier release.');
        }
        DB::commit();
    }
    $disk = Storage::disk('blitz_close_race');
    $snapshot += [
        'stored' => $storage->stored, 'cleanups' => $storage->cleanups,
        'blob_keys' => $disk->allFiles(), 'current_blob_exists' => $disk->exists($snapshot['file']['storage_key']),
        'current_blob' => $disk->get($snapshot['file']['storage_key']),
    ];
    echo json_encode($snapshot, JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    if (DB::transactionLevel() > 0) {
        DB::rollBack();
    }
    throw $exception;
} finally {
    if ($uploadPath !== null && file_exists($uploadPath)) {
        unlink($uploadPath);
    }
}
PHP;
    }
}
