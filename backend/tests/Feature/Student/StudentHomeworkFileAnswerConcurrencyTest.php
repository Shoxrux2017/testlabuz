<?php

namespace Tests\Feature\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\AnswerFile;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\Question;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class StudentHomeworkFileAnswerConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    private string $workerPath;

    private string $storageRoot;

    private array $ids;

    private array $signalPaths = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $this->workerPath = $this->signalPath();
        file_put_contents($this->workerPath, $this->workerSource());
        $this->storageRoot = storage_path('framework/testing/student-submission-concurrency-'.Str::uuid());
        config(['filesystems.disks.student_submission_concurrency' => [
            'driver' => 'local', 'root' => $this->storageRoot, 'visibility' => 'private', 'throw' => true,
        ]]);
        Storage::forgetDisk('student_submission_concurrency');
        $this->ids = $this->runWorker('setup');
    }

    protected function tearDown(): void
    {
        try {
            if (isset($this->ids)) {
                $this->runWorker('cleanup', ['institution' => $this->ids['institution']]);
            }
            foreach ($this->signalPaths as $path) {
                foreach ([$path, $path.'.pending'] as $signal) {
                    if (file_exists($signal)) {
                        unlink($signal);
                    }
                }
            }
        } finally {
            parent::tearDown();
        }
    }

    public function test_same_attempt_replacements_wait_on_postgresql_and_commit_one_complete_file_graph(): void
    {
        $attemptsBefore = $this->attemptSnapshot();
        $release = $this->signalPath();
        $firstReady = $this->signalPath();
        $secondReady = $this->signalPath();
        $secondStored = $this->signalPath();
        $first = $this->startWorker('save', $this->saveArguments('first', 'first', $firstReady, $release));
        $second = null;

        try {
            $firstState = $this->readSignal($firstReady, 'The first replacement did not retain its mutation locks.');
            $this->assertSaveResult($firstState, 'first', 'first');
            $this->disk()->assertExists($this->ids['first_key']);
            $second = $this->startWorker('save', $this->saveArguments('first', 'second', $secondReady)
                + ['stored' => $secondStored]);
            $secondStorage = $this->readSignal($secondStored, 'The second replacement did not store its preliminary blob.');
            $this->waitForPostgresLock($secondStorage['pid'], $firstState['pid'], 'assessment_attempts');
            $this->assertFileDoesNotExist($secondReady);
            $this->disk()->assertExists($firstState['stored'][0]['key']);
            $this->disk()->assertExists($secondStorage['key']);
        } finally {
            file_put_contents($release, 'release');
            $firstResult = $this->finishWorker($first);
            $secondResult = $second === null ? null : $this->finishWorker($second);
        }

        $this->assertSaveResult($firstResult, 'first', 'first');
        $this->assertSaveResult($secondResult, 'first', 'second');
        $this->assertCleanup($firstResult, $this->ids['first_key'], $this->ids['first_file']);
        $this->assertCleanup($secondResult, $firstResult['stored'][0]['key'], $this->ids['first_file']);
        $this->assertPersistedGraph('first', 'second', $secondResult['stored'][0]['key']);
        $this->assertPersistedGraph('second', 'initial-second', $this->ids['second_key']);
        $this->assertSame($attemptsBefore, $this->attemptSnapshot());
        $this->assertSame(2, count($this->disk()->allFiles()));
    }

    public function test_different_students_hold_independent_attempt_locks_with_shared_homework_question_and_setting_locks(): void
    {
        $attemptsBefore = $this->attemptSnapshot();
        $release = $this->signalPath();
        $firstReady = $this->signalPath();
        $secondReady = $this->signalPath();
        $first = $this->startWorker('save', $this->saveArguments('first', 'first', $firstReady, $release));
        $second = null;

        try {
            $firstState = $this->readSignal($firstReady, 'The first Student did not retain its mutation locks.');
            $this->assertSaveResult($firstState, 'first', 'first');
            $second = $this->startWorker('save', $this->saveArguments('second', 'second', $secondReady, $release));
            $secondState = $this->readSignal($secondReady, 'Different Students were serialized by a shared Homework, Question, or Setting.');
            $this->assertSaveResult($secondState, 'second', 'second');
            $this->assertConcurrentTransactions($firstState['pid'], $secondState['pid']);
            $this->assertFileDoesNotExist($release);
            $this->disk()->assertExists([$this->ids['first_key'], $this->ids['second_key']]);
        } finally {
            file_put_contents($release, 'release');
            $firstResult = $this->finishWorker($first);
            $secondResult = $second === null ? null : $this->finishWorker($second);
        }

        $this->assertCleanup($firstResult, $this->ids['first_key'], $this->ids['first_file']);
        $this->assertCleanup($secondResult, $this->ids['second_key'], $this->ids['second_file']);
        $this->assertPersistedGraph('first', 'first', $firstResult['stored'][0]['key']);
        $this->assertPersistedGraph('second', 'second', $secondResult['stored'][0]['key']);
        $this->assertSame($attemptsBefore, $this->attemptSnapshot());
        $this->assertSame(2, count($this->disk()->allFiles()));
    }

    public function test_shared_file_downloads_coexist_and_block_replacement_until_both_old_streams_are_open(): void
    {
        $attemptsBefore = $this->attemptSnapshot();
        $release = $this->signalPath();
        $replacementDone = $this->signalPath();
        $firstReady = $this->signalPath();
        $secondReady = $this->signalPath();
        $replacementReady = $this->signalPath();
        $replacementStored = $this->signalPath();
        $downloadArguments = [
            'student' => $this->ids['first_student'], 'file' => $this->ids['first_file'],
            'release' => $release, 'read_after' => $replacementDone,
        ];
        $first = $this->startWorker('download', $downloadArguments + ['ready' => $firstReady]);
        $second = null;
        $replacement = null;

        try {
            $firstState = $this->readSignal($firstReady, 'The first download did not open its stream under a shared File lock.');
            $this->assertDownloadLocks($firstState);
            $second = $this->startWorker('download', $downloadArguments + ['ready' => $secondReady]);
            $secondState = $this->readSignal($secondReady, 'Shared File locks serialized two read-only downloads.');
            $this->assertDownloadLocks($secondState);
            $this->assertConcurrentTransactions($firstState['pid'], $secondState['pid']);
            $replacement = $this->startWorker('save', $this->saveArguments('first', 'first', $replacementReady)
                + ['stored' => $replacementStored, 'done' => $replacementDone]);
            $stored = $this->readSignal($replacementStored, 'The replacement did not store its preliminary blob.');
            $this->waitForPostgresLock($stored['pid'], $firstState['pid'], 'files');
            $this->assertFileDoesNotExist($replacementReady);
            $this->disk()->assertExists($this->ids['first_key']);
        } finally {
            file_put_contents($release, 'release');
            try {
                $replacementResult = $replacement === null ? null : $this->finishWorker($replacement);
            } finally {
                // Release stream readers even when a failing replacement produced no completion signal.
                file_put_contents($replacementDone, 'done');
                $firstResult = $this->finishWorker($first);
                $secondResult = $second === null ? null : $this->finishWorker($second);
            }
        }

        foreach ([$firstResult, $secondResult] as $result) {
            $this->assertSame(base64_encode($this->pdf('initial-first')), $result['bytes']);
            $this->assertSame(0, $result['transaction_level_before_body']);
            $this->assertFalse($result['opened_key_exists_before_body']);
        }
        $this->assertSaveResult($replacementResult, 'first', 'first');
        $this->assertCleanup($replacementResult, $this->ids['first_key'], $this->ids['first_file']);
        $this->assertPersistedGraph('first', 'first', $replacementResult['stored'][0]['key']);
        $later = $this->runWorker('download', [
            'student' => $this->ids['first_student'], 'file' => $this->ids['first_file'],
        ]);
        $this->assertDownloadLocks($later);
        $this->assertSame(base64_encode($this->pdf('first')), $later['bytes']);
        $this->assertSame($attemptsBefore, $this->attemptSnapshot());
        $this->assertSame(2, count($this->disk()->allFiles()));
    }

    private function saveArguments(string $student, string $content, string $ready, ?string $release = null): array
    {
        return [
            'student' => $this->ids[$student.'_student'], 'attempt' => $this->ids[$student.'_attempt'],
            'question' => $this->ids['question'], 'content' => $content, 'ready' => $ready, 'release' => $release,
        ];
    }

    private function assertSaveResult(array $result, string $student, string $content): void
    {
        $this->assertSame(200, $result['status'], json_encode($result['body']));
        $this->assertSame($this->ids['question'], $result['body']['data']['question_id']);
        $this->assertSame('file_based', $result['body']['data']['type']);
        $expected = ['file' => [
            'id' => $this->ids[$student.'_file'], 'original_name' => $content.'.pdf',
            'extension' => 'pdf', 'size_bytes' => strlen($this->pdf($content)),
        ]];
        $this->assertSame($expected, $result['body']['data']['answer']);
        $this->assertSame($expected, $result['canonical']);
        $this->assertSame([
            ['table' => 'topics', 'mode' => 'share'],
            ['table' => 'assessments', 'mode' => 'share'],
            ['table' => 'homework_assignments', 'mode' => 'share'],
            ['table' => 'assessment_attempts', 'mode' => 'update'],
            ['table' => 'questions', 'mode' => 'share'],
            ['table' => 'attempt_answers', 'mode' => 'update'],
            ['table' => 'answer_files', 'mode' => 'update'],
            ['table' => 'files', 'mode' => 'update'],
            ['table' => 'institution_settings', 'mode' => 'share'],
        ], $result['locks']);
    }

    private function assertDownloadLocks(array $result): void
    {
        $this->assertSame([['table' => 'files', 'mode' => 'share']], $result['locks']);
        $this->assertCount(1, $result['opened']);
        $this->assertGreaterThan(0, $result['opened'][0]['transaction_level']);
        $this->assertSame([['table' => 'files', 'mode' => 'share']], $result['opened'][0]['locks_at_open']);
    }

    private function assertCleanup(array $result, string $oldKey, string $fileId): void
    {
        $this->assertSame([[
            'disk' => 'student_submission_concurrency', 'key' => $oldKey,
            'operation' => 'student_submission_replace_old_blob_cleanup', 'file' => $fileId,
            'transaction_level' => 0, 'deleted' => true,
        ]], $result['cleanups']);
        clearstatcache();
        $this->disk()->assertMissing($oldKey);
    }

    private function assertPersistedGraph(string $student, string $content, string $key): void
    {
        $attempt = AssessmentAttempt::query()->findOrFail($this->ids[$student.'_attempt']);
        $questions = Question::query()->whereKey($this->ids['question'])->get();
        $states = app(StudentHomeworkAttemptAnswerStates::class)($this->ids['institution'], $attempt, $questions);
        $this->assertCount(1, $states);
        $answer = $states->sole()->attemptAnswer;
        $this->assertSame($this->ids[$student.'_answer'], $answer->id);
        $this->assertSame(1, AttemptAnswer::query()->where('attempt_id', $attempt->id)->count());
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->checking_status);
        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
            $this->assertNull($answer->{$field}, $field);
        }
        $answerFile = AnswerFile::query()->where('answer_id', $answer->id)->get()->sole();
        $file = File::query()->where('uploaded_by_user_id', $attempt->student_id)->get()->sole();
        $this->assertSame($this->ids[$student.'_answer_file'], $answerFile->id);
        $this->assertSame($this->ids[$student.'_file'], $file->id);
        $this->assertSame($file->id, $answerFile->file_id);
        foreach ([$answer, $answerFile, $file] as $row) {
            $this->assertSame('2026-09-09 09:00:00', $row->created_at->format('Y-m-d H:i:s'));
        }
        $this->assertSame(['file' => [
            'id' => $file->id, 'original_name' => $content.'.pdf', 'extension' => 'pdf',
            'size_bytes' => strlen($this->pdf($content)),
        ]], $answer->getAttribute('student_answer_value'));
        $this->assertSame('application/pdf', $file->mime_type);
        $this->assertSame(hash('sha256', $this->pdf($content)), $file->checksum_sha256);
        $this->assertSame('student_submission_concurrency', $file->storage_disk);
        $this->assertSame($key, $file->storage_key);
        $this->assertSame($this->pdf($content), $this->disk()->get($key));
        foreach (['answer_choice_selections', 'answer_boolean_values', 'answer_text_values',
            'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values'] as $table) {
            $this->assertSame(0, DB::table($table)->where('answer_id', $answer->id)->count(), $table);
        }
    }

    private function attemptSnapshot(): array
    {
        return AssessmentAttempt::query()->where('assessment_id', $this->ids['assessment'])
            ->orderBy('id')->get()->map->getAttributes()->all();
    }

    private function disk(): FilesystemAdapter
    {
        return Storage::disk('student_submission_concurrency');
    }

    private function pdf(string $content): string
    {
        return "%PDF-1.7\n{$content}\n%%EOF\n";
    }

    private function assertConcurrentTransactions(int $firstPid, int $secondPid): void
    {
        $this->assertNotSame($firstPid, $secondPid);
        foreach ([$firstPid, $secondPid] as $pid) {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne('select state, cardinality(pg_blocking_pids(pid)) as blockers from pg_stat_activity where pid = ?', [$pid]);
            $this->assertSame('idle in transaction', $activity->state);
            $this->assertSame(0, $activity->blockers);
        }
    }

    private function waitForPostgresLock(int $waitingPid, int $holdingPid, string $table): void
    {
        $deadline = microtime(true) + 10;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne(
                'select wait_event_type, query, ? = any(pg_blocking_pids(pid)) as blocked_by_holder from pg_stat_activity where pid = ?',
                [$holdingPid, $waitingPid],
            );
            if ($activity !== null && $activity->wait_event_type === 'Lock' && $activity->blocked_by_holder) {
                $this->assertStringContainsString('from "'.$table.'"', $activity->query);
                $this->assertStringContainsString('for update', $activity->query);

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('PostgreSQL did not expose the required '.$table.' lock wait: '.json_encode($activity));
    }

    private function signalPath(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's07_be_006_file_race_');
        $this->assertIsString($path);
        unlink($path);
        $this->signalPaths[] = $path;

        return $path;
    }

    private function readSignal(string $path, string $message): array
    {
        $deadline = microtime(true) + 10;
        do {
            clearstatcache(true, $path);
            if (file_exists($path) && filesize($path) > 0) {
                return json_decode(file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail($message);
    }

    private function startWorker(string $mode, array $arguments = []): array
    {
        $pipes = [];
        $process = proc_open([PHP_BINARY, $this->workerPath, base_path(), $this->storageRoot, $mode,
            json_encode($arguments, JSON_THROW_ON_ERROR)], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
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

    private function runWorker(string $mode, array $arguments = []): array
    {
        return $this->finishWorker($this->startWorker($mode, $arguments));
    }

    private function workerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Files\DownloadStudentSubmissionFile;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Models\AnswerFile;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\Group;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\Topic;
use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
if (DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new LogicException('File-answer concurrency workers require the isolated PostgreSQL testing database.');
}
$storageRoot = $argv[2];
$mode = $argv[3];
$arguments = json_decode($argv[4], true, flags: JSON_THROW_ON_ERROR);
config([
    'filesystems.private_files_disk' => 'student_submission_concurrency',
    'filesystems.disks.student_submission_concurrency' => [
        'driver' => 'local', 'root' => $storageRoot, 'visibility' => 'private', 'throw' => true,
    ],
]);
Carbon::setTestNow(Carbon::parse('2026-09-09 09:00:00 UTC'));

if ($mode === 'setup') {
    $institution = Institution::factory()->create();
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create();
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
    $topic = Topic::factory()->active()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $teacher->id,
    ]);
    $assessment = Assessment::factory()->homework()->create([
        'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
        'assignment_mode' => AssessmentAssignmentMode::SelectedStudents, 'total_possible_points' => '2.000000',
    ]);
    HomeworkAssignment::factory()->active()->create([
        'institution_id' => $institution->id, 'assessment_id' => $assessment->id, 'deadline_at' => null,
    ]);
    $question = Question::factory()->fileBased()->create([
        'institution_id' => $institution->id, 'assessment_id' => $assessment->id, 'points' => '2.000000',
    ]);
    $ids = ['institution' => $institution->id, 'assessment' => $assessment->id, 'question' => $question->id];
    foreach (['first', 'second'] as $name) {
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id, 'assessment_id' => $assessment->id, 'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct, 'assigned_by_user_id' => $teacher->id,
        ]);
        $attempt = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id, 'possible_points' => '2.000000']);
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        $bytes = "%PDF-1.7\ninitial-{$name}\n%%EOF\n";
        $key = 'student-submissions/'.$institution->id.'/'.$attempt->id.'/'.$question->id.'/'.Str::uuid().'.pdf';
        $file = File::factory()->studentSubmission()->create([
            'institution_id' => $institution->id, 'uploaded_by_user_id' => $student->id,
            'original_name' => 'initial-'.$name.'.pdf', 'storage_disk' => 'student_submission_concurrency',
            'storage_key' => $key, 'mime_type' => 'application/pdf', 'extension' => 'pdf',
            'size_bytes' => strlen($bytes), 'checksum_sha256' => hash('sha256', $bytes),
        ]);
        $answerFile = AnswerFile::factory()->create(['answer_id' => $answer->id, 'file_id' => $file->id]);
        Storage::disk('student_submission_concurrency')->put($key, $bytes);
        foreach (['student' => $student->id, 'attempt' => $attempt->id, 'answer' => $answer->id,
            'answer_file' => $answerFile->id, 'file' => $file->id, 'key' => $key] as $field => $value) {
            $ids[$name.'_'.$field] = $value;
        }
    }
    echo json_encode($ids, JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $resolvedStorageRoot = realpath($storageRoot);
    $resolvedTestingRoot = realpath(storage_path('framework/testing'));
    $prefix = 'student-submission-concurrency-';
    if ($resolvedStorageRoot === false || $resolvedTestingRoot === false
        || dirname($resolvedStorageRoot) !== $resolvedTestingRoot
        || ! str_starts_with(basename($resolvedStorageRoot), $prefix)
        || ! Str::isUuid(substr(basename($resolvedStorageRoot), strlen($prefix)))) {
        throw new LogicException('Refusing cleanup outside the generated file-answer concurrency fixture directory.');
    }
    DB::transaction(function () use ($arguments): void {
        foreach ([AnswerFile::class, AttemptAnswer::class, File::class, AssessmentAttempt::class,
            Question::class, AssessmentStudent::class, HomeworkAssignment::class, Assessment::class,
            Topic::class, Group::class, InstitutionSetting::class, User::class] as $model) {
            $model::query()->where('institution_id', $arguments['institution'])->delete();
        }
        Institution::query()->whereKey($arguments['institution'])->delete();
    });
    (new \Illuminate\Filesystem\Filesystem)->deleteDirectory($resolvedStorageRoot);
    echo '{}';
    exit(0);
}

function awaitSignal(?string $path): void
{
    if ($path === null) {
        return;
    }
    $deadline = microtime(true) + 20;
    do {
        clearstatcache(true, $path);
        if (file_exists($path)) {
            return;
        }
        usleep(5_000);
    } while (microtime(true) < $deadline);
    throw new RuntimeException('Timed out waiting for the deterministic file-answer race signal.');
}

function publishSignal(string $path, array $value): void
{
    file_put_contents($path.'.pending', json_encode($value, JSON_THROW_ON_ERROR));
    if (! rename($path.'.pending', $path)) {
        throw new RuntimeException('Unable to publish the deterministic file-answer race signal.');
    }
}

Carbon::setTestNow(Carbon::parse(($arguments['content'] ?? '') === 'second'
    ? '2026-09-09 10:01:00 UTC' : '2026-09-09 10:00:00 UTC'));
DB::statement("set lock_timeout = '10s'");
$pid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
$locks = [];
$lockSnapshot = function () use (&$locks): array {
    return $locks;
};
$storage = new class($arguments['stored'] ?? null, $pid, $lockSnapshot) extends PrivateFileStorage
{
    public array $stored = [];
    public array $cleanups = [];
    public array $opened = [];

    public function __construct(
        private readonly ?string $storedPath,
        private readonly int $pid,
        private readonly Closure $lockSnapshot,
    ) {}

    public function store(UploadedFile $upload, string $storageKey): string
    {
        $disk = parent::store($upload, $storageKey);
        $event = ['disk' => $disk, 'key' => $storageKey, 'pid' => $this->pid];
        $this->stored[] = $event;
        if ($this->storedPath !== null) {
            publishSignal($this->storedPath, $event);
        }
        return $disk;
    }

    public function openReadStream(string $storedDiskName, string $storedStorageKey, string $fileId): mixed
    {
        $stream = parent::openReadStream($storedDiskName, $storedStorageKey, $fileId);
        $this->opened[] = ['disk' => $storedDiskName, 'key' => $storedStorageKey,
            'transaction_level' => DB::transactionLevel(), 'locks_at_open' => ($this->lockSnapshot)()];
        return $stream;
    }

    public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
    {
        $deleted = parent::deleteBestEffort($diskName, $storageKey, $operation, $fileId);
        $this->cleanups[] = ['disk' => $diskName, 'key' => $storageKey, 'operation' => $operation,
            'file' => $fileId, 'transaction_level' => DB::transactionLevel(), 'deleted' => $deleted];
        return $deleted;
    }
};
$app->instance(PrivateFileStorage::class, $storage);
DB::listen(function ($query) use (&$locks): void {
    if (preg_match('/from "(topics|assessments|homework_assignments|assessment_attempts|questions|attempt_answers|answer_files|files|institution_settings)".* for (share|update)$/s', $query->sql, $matches)) {
        $locks[] = ['table' => $matches[1], 'mode' => $matches[2]];
    }
});
$student = User::query()->findOrFail($arguments['student']);
$uploadPath = null;
$download = null;
DB::beginTransaction();
try {
    $result = ['pid' => $pid];
    if ($mode === 'save') {
        $uploadPath = tempnam(sys_get_temp_dir(), 's07_be_006_upload_');
        file_put_contents($uploadPath, "%PDF-1.7\n{$arguments['content']}\n%%EOF\n");
        $upload = new UploadedFile($uploadPath, $arguments['content'].'.pdf', 'application/octet-stream', UPLOAD_ERR_OK, true);
        Sanctum::actingAs($student);
        $request = Request::create('/api/v1/student/attempts/'.$arguments['attempt'].'/answers/'.$arguments['question'],
            'PUT', ['type' => 'file_based'], [], ['file' => $upload], [
                'CONTENT_TYPE' => 'multipart/form-data', 'HTTP_ACCEPT' => 'application/json',
            ]);
        $kernel = $app->make(HttpKernel::class);
        $response = $kernel->handle($request);
        $kernel->terminate($request, $response);
        $result['status'] = $response->getStatusCode();
        $result['body'] = json_decode($response->getContent(), true, flags: JSON_THROW_ON_ERROR);
        if ($result['status'] === 200) {
            $attempt = AssessmentAttempt::query()->findOrFail($arguments['attempt']);
            $questions = Question::query()->whereKey($arguments['question'])->get();
            $states = app(StudentHomeworkAttemptAnswerStates::class)($student->institution_id, $attempt, $questions);
            $result['canonical'] = $states->sole()->attemptAnswer->getAttribute('student_answer_value');
        }
    } else {
        $download = app(DownloadStudentSubmissionFile::class)($student, $arguments['file']);
    }
    if (DB::transactionLevel() !== 1) {
        throw new LogicException('The operation must retain its locks in the enclosing transaction.');
    }
    $result += ['locks' => $locks, 'stored' => $storage->stored, 'opened' => $storage->opened];
    if (isset($arguments['ready'])) {
        publishSignal($arguments['ready'], $result);
    }
    awaitSignal($arguments['release'] ?? null);
    DB::commit();
    $result['cleanups'] = $storage->cleanups;
    if (isset($arguments['done'])) {
        file_put_contents($arguments['done'], 'done');
    }
    if ($download !== null) {
        awaitSignal($arguments['read_after'] ?? null);
        $result['transaction_level_before_body'] = DB::transactionLevel();
        $result['opened_key_exists_before_body'] = Storage::disk($storage->opened[0]['disk'])->exists($storage->opened[0]['key']);
        $result['bytes'] = base64_encode(stream_get_contents($download->stream));
        fclose($download->stream);
    }
    echo json_encode($result, JSON_THROW_ON_ERROR);
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
