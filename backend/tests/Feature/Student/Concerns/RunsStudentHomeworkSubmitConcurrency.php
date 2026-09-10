<?php

namespace Tests\Feature\Student\Concerns;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

trait RunsStudentHomeworkSubmitConcurrency
{
    use RefreshDatabase;

    protected array $ids;

    private string $workerPath;

    private string $storageRoot;

    private array $signalPaths = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $this->workerPath = $this->signalPath();
        file_put_contents($this->workerPath, $this->workerSource());
        $this->storageRoot = storage_path('framework/testing/homework-submit-concurrency-'.Str::uuid());
        config(['filesystems.disks.homework_submit_concurrency' => [
            'driver' => 'local', 'root' => $this->storageRoot, 'visibility' => 'private', 'throw' => true,
        ]]);
        Storage::forgetDisk('homework_submit_concurrency');
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

    protected function arguments(string $student = 'first', array $overrides = []): array
    {
        return array_replace($this->ids, [
            'student' => $this->ids[$student.'_student'], 'attempt' => $this->ids[$student.'_attempt'],
            'key' => (string) Str::uuid(), 'observed_at' => '2026-09-09 09:30:00 UTC',
            'content' => 'replacement',
        ], $overrides);
    }

    protected function race(string $firstOperation, string $secondOperation, array $firstOverrides = [], array $secondOverrides = [], string $waitTable = 'assessment_attempts'): array
    {
        $release = $this->signalPath();
        $ready = $this->signalPath();
        $started = $this->signalPath();
        $stored = $this->signalPath();
        $first = $this->startWorker($firstOperation, $this->arguments(overrides: $firstOverrides) + ['ready' => $ready, 'release' => $release]);
        $second = null;

        try {
            $held = $this->readSignal($ready);
            $second = $this->startWorker($secondOperation, $this->arguments(overrides: $secondOverrides + [
                'observed_at' => '2026-09-09 09:31:00 UTC',
            ]) + ['started' => $started, 'stored' => $stored]);
            $secondStarted = $this->readSignal($started);
            $this->waitForPostgresLock($secondStarted['pid'], $held['pid'], $waitTable);
            if ($secondOperation === 'file') {
                $storedBlob = $this->readSignal($stored);
                Storage::disk('homework_submit_concurrency')->assertExists($storedBlob['key']);
            }
        } finally {
            file_put_contents($release, 'release');
            try {
                $firstResult = $this->finishWorker($first);
            } finally {
                $secondResult = $second === null ? null : $this->finishWorker($second);
            }
        }

        return ['first' => $firstResult, 'second' => $secondResult, 'held' => $held];
    }

    protected function assertSubmitSuccess(array $result, string $student = 'first'): void
    {
        $this->assertSame(200, $result['status'], json_encode($result['body']));
        $this->assertSame($this->ids[$student.'_attempt'], $result['body']['data']['id']);
        $this->assertSame('submitted', $result['body']['data']['status']);
        $this->assertSame('student_submit', $result['body']['data']['finalization_reason']);
        $this->assertSame('Homework submitted successfully.', $result['body']['message']);
        $attempt = $result['snapshot']['attempt'];
        $this->assertSame('student_submit', $attempt['finalization_reason']);
        $this->assertNotNull($attempt['submitted_at']);
        $this->assertSame($attempt['submitted_at'], $attempt['finalized_at']);
        $this->assertSame($attempt['submitted_at'], $attempt['locked_at']);
        $this->assertSame($attempt['submitted_at'], $attempt['updated_at']);
        foreach (['earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertNull($attempt[$field]);
        }
    }

    protected function submitLocks(): array
    {
        return [
            ['table' => 'topics', 'mode' => 'share'],
            ['table' => 'assessments', 'mode' => 'share'],
            ['table' => 'homework_assignments', 'mode' => 'share'],
            ['table' => 'assessment_attempts', 'mode' => 'update'],
        ];
    }

    protected function assertSubmitGate(array $result): void
    {
        $this->assertSame($this->submitLocks(), $result['locks']);
        $this->assertSame([['transaction_level' => 1, 'locks' => $this->submitLocks()]], $result['gate_reads']);
    }

    protected function waitForPostgresLock(int $waitingPid, int $holdingPid, string $table): void
    {
        $deadline = microtime(true) + 10;
        $activity = null;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne(
                'select wait_event_type, query, ? = any(pg_blocking_pids(pid)) as blocked_by_holder from pg_stat_activity where pid = ?',
                [$holdingPid, $waitingPid],
            );
            if ($activity !== null && $activity->wait_event_type === 'Lock' && $activity->blocked_by_holder) {
                $this->assertStringContainsString('from "'.$table.'"', $activity->query);

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('PostgreSQL did not expose the required '.$table.' lock wait: '.json_encode($activity));
    }

    protected function signalPath(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's07_be_007_race_');
        $this->assertIsString($path);
        unlink($path);
        $this->signalPaths[] = $path;

        return $path;
    }

    protected function readSignal(string $path, string $message = 'The worker did not reach its deterministic transaction marker.'): array
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

    protected function startWorker(string $mode, array $arguments = []): array
    {
        $pipes = [];
        $process = proc_open([PHP_BINARY, $this->workerPath, base_path(), $this->storageRoot, $mode,
            json_encode($arguments, JSON_THROW_ON_ERROR)], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
        $this->assertIsResource($process);
        fclose($pipes[0]);

        return ['process' => $process, 'pipes' => $pipes];
    }

    protected function finishWorker(array $worker): array
    {
        $stdout = stream_get_contents($worker['pipes'][1]);
        $stderr = stream_get_contents($worker['pipes'][2]);
        fclose($worker['pipes'][1]);
        fclose($worker['pipes'][2]);
        $exitCode = proc_close($worker['process']);
        $this->assertSame(0, $exitCode, $stderr."\nSTDOUT: {$stdout}");

        return json_decode(trim($stdout), true, flags: JSON_THROW_ON_ERROR);
    }

    protected function runWorker(string $mode, array $arguments = []): array
    {
        return $this->finishWorker($this->startWorker($mode, $arguments));
    }

    private function workerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Actions\Student\SubmitStudentHomeworkAttempt;
use App\Actions\Teacher\CloseTeacherHomework;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Models\AnswerFile;
use App\Models\AnswerTextValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\Topic;
use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Database\Events\TransactionCommitted;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
if (DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new LogicException('Submit concurrency workers require the isolated PostgreSQL testing database.');
}
$storageRoot = $argv[2];
$mode = $argv[3];
$arguments = json_decode($argv[4], true, flags: JSON_THROW_ON_ERROR);
config([
    'filesystems.private_files_disk' => 'homework_submit_concurrency',
    'filesystems.disks.homework_submit_concurrency' => [
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
    GroupTeacherMembership::factory()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id,
        'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id,
    ]);
    $topic = Topic::factory()->active()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $teacher->id,
    ]);
    $assessment = Assessment::factory()->homework()->create([
        'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
        'assignment_mode' => AssessmentAssignmentMode::SelectedStudents, 'total_possible_points' => '2.000000',
    ]);
    HomeworkAssignment::factory()->active()->create([
        'assessment_id' => $assessment->id, 'deadline_at' => Carbon::parse('2026-09-09 10:00:00 UTC'),
    ]);
    $textQuestion = Question::factory()->openWritten()->create(['assessment_id' => $assessment->id, 'position' => 1]);
    $fileQuestion = Question::factory()->fileBased()->create(['assessment_id' => $assessment->id, 'position' => 2]);
    $ids = ['institution' => $institution->id, 'teacher' => $teacher->id, 'assessment' => $assessment->id,
        'text_question' => $textQuestion->id, 'file_question' => $fileQuestion->id];
    foreach (['first', 'second'] as $name) {
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $recipient = AssessmentStudent::factory()->create([
            'assessment_id' => $assessment->id, 'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct, 'assigned_by_user_id' => $teacher->id,
        ]);
        // The other Student sorts first so a blocked all-Attempt reconciler has not yet locked the route Attempt.
        $attemptId = ($name === 'first' ? 'e' : 'a').substr((string) Str::uuid(), 1);
        $attempt = AssessmentAttempt::factory()->create([
            'id' => $attemptId, 'assessment_student_id' => $recipient->id, 'possible_points' => '2.000000',
        ]);
        $textAnswer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $textQuestion->id]);
        AnswerTextValue::factory()->create(['answer_id' => $textAnswer->id, 'text_value' => 'initial-'.$name]);
        $fileAnswer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $fileQuestion->id]);
        $bytes = "%PDF-1.7\ninitial-{$name}\n%%EOF\n";
        $key = 'student-submissions/'.$institution->id.'/'.$attempt->id.'/'.$fileQuestion->id.'/'.Str::uuid().'.pdf';
        $file = File::factory()->studentSubmission()->create([
            'institution_id' => $institution->id, 'uploaded_by_user_id' => $student->id,
            'original_name' => 'initial-'.$name.'.pdf', 'storage_disk' => 'homework_submit_concurrency',
            'storage_key' => $key, 'mime_type' => 'application/pdf', 'extension' => 'pdf',
            'size_bytes' => strlen($bytes), 'checksum_sha256' => hash('sha256', $bytes),
        ]);
        $answerFile = AnswerFile::factory()->create(['answer_id' => $fileAnswer->id, 'file_id' => $file->id]);
        Storage::disk('homework_submit_concurrency')->put($key, $bytes);
        foreach (['student' => $student->id, 'attempt' => $attempt->id, 'text_answer' => $textAnswer->id,
            'file_answer' => $fileAnswer->id, 'answer_file' => $answerFile->id, 'file' => $file->id, 'key' => $key] as $field => $value) {
            $ids[$name.'_'.$field] = $value;
        }
    }
    echo json_encode($ids, JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $resolvedRoot = realpath($storageRoot);
    $testingRoot = realpath(storage_path('framework/testing'));
    $prefix = 'homework-submit-concurrency-';
    if ($resolvedRoot === false || $testingRoot === false || dirname($resolvedRoot) !== $testingRoot
        || ! str_starts_with(basename($resolvedRoot), $prefix)
        || ! Str::isUuid(substr(basename($resolvedRoot), strlen($prefix)))) {
        throw new LogicException('Refusing cleanup outside the generated Submit concurrency fixture directory.');
    }
    DB::transaction(function () use ($arguments): void {
        foreach ([IdempotencyRecord::class, AnswerTextValue::class, AnswerFile::class, AttemptAnswer::class,
            File::class, AssessmentAttempt::class, Question::class, AssessmentStudent::class,
            HomeworkAssignment::class, Assessment::class, Topic::class, GroupTeacherMembership::class,
            Group::class, InstitutionSetting::class, User::class] as $model) {
            $model::query()->where('institution_id', $arguments['institution'])->delete();
        }
        Institution::query()->whereKey($arguments['institution'])->delete();
    });
    (new \Illuminate\Filesystem\Filesystem)->deleteDirectory($resolvedRoot);
    echo '{}';
    exit(0);
}

function publishSignal(string $path, array $value): void
{
    file_put_contents($path.'.pending', json_encode($value, JSON_THROW_ON_ERROR));
    if (! rename($path.'.pending', $path)) {
        throw new RuntimeException('Unable to publish the Submit race marker.');
    }
}

function awaitSignal(string $path): void
{
    $deadline = microtime(true) + 20;
    do {
        clearstatcache(true, $path);
        if (file_exists($path)) {
            return;
        }
        usleep(5_000);
    } while (microtime(true) < $deadline);
    throw new RuntimeException('Timed out waiting for the deterministic Submit race release.');
}

function snapshot(array $arguments): array
{
    $attempt = AssessmentAttempt::query()->whereKey($arguments['attempt'])->firstOrFail();
    return [
        'attempt' => $attempt->getAttributes(),
        'records' => IdempotencyRecord::query()->where('institution_id', $arguments['institution'])
            ->where('user_id', $arguments['student'])->orderBy('id')->get()->map->getAttributes()->all(),
        'answers' => AttemptAnswer::query()->where('attempt_id', $attempt->id)->orderBy('id')->get()->map->getAttributes()->all(),
        'text' => AnswerTextValue::query()->whereIn('answer_id', $attempt->answers()->select('id'))->firstOrFail()->getAttributes(),
        'answer_file' => AnswerFile::query()->whereIn('answer_id', $attempt->answers()->select('id'))->firstOrFail()->getAttributes(),
        'file' => File::query()->where('uploaded_by_user_id', $attempt->student_id)->firstOrFail()->getAttributes(),
        'homework_status' => HomeworkAssignment::query()->whereKey($arguments['assessment'])->firstOrFail()->status->value,
    ];
}

Carbon::setTestNow(Carbon::parse($arguments['observed_at']));
DB::statement("set lock_timeout = '10s'");
$pid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
$locks = [];
$gateReads = [];
$commits = [];
$deadlineEntries = [];
$held = false;
$storage = new class($arguments['stored'] ?? null, $pid) extends PrivateFileStorage
{
    public array $stored = [];
    public array $cleanups = [];

    public function __construct(private readonly ?string $storedPath, private readonly int $pid) {}

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

    public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
    {
        $deleted = parent::deleteBestEffort($diskName, $storageKey, $operation, $fileId);
        $this->cleanups[] = ['key' => $storageKey, 'operation' => $operation, 'deleted' => $deleted,
            'transaction_level' => DB::transactionLevel()];
        return $deleted;
    }
};
$app->instance(PrivateFileStorage::class, $storage);
Event::listen(TransactionCommitted::class, function () use (&$commits): void {
    $commits[] = DB::transactionLevel();
});
DB::connection()->beforeExecuting(function ($sql) use (&$deadlineEntries, &$commits, $arguments): void {
    if (! str_starts_with($sql, 'select') || ! str_contains($sql, 'from "assessments"')
        || ! str_ends_with($sql, 'for update')) {
        return;
    }
    foreach (debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS) as $frame) {
        if (($frame['class'] ?? null) === FinalizeHomeworkAttemptsAtDeadline::class
            && ($frame['function'] ?? null) === '__invoke') {
            $entry = ['transaction_level' => DB::transactionLevel(), 'preceding_commits' => $commits];
            $deadlineEntries[] = $entry;
            if (isset($arguments['deadline_entry'])) {
                publishSignal($arguments['deadline_entry'], $entry);
            }
            return;
        }
    }
});
DB::listen(function ($query) use (&$locks, &$gateReads, &$held, $mode, $arguments, $pid): void {
    if (preg_match('/from "([a-z_]+)".* for (share|update)$/s', $query->sql, $matches)
        && $matches[1] !== 'idempotency_records') {
        $locks[] = ['table' => $matches[1], 'mode' => $matches[2]];
        if ($mode === 'submit' && $matches[1] === 'assessment_attempts' && isset($arguments['time_after_attempt_lock'])) {
            Carbon::setTestNow(Carbon::parse($arguments['time_after_attempt_lock']));
        }
    }
    if (str_starts_with($query->sql, 'select') && str_contains($query->sql, 'from "attempt_answers"')) {
        $classes = array_column(debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS), 'class');
        if (in_array(StudentHomeworkAttemptAnswerStates::class, $classes, true)
            && in_array(SubmitStudentHomeworkAttempt::class, $classes, true)) {
            $gateReads[] = ['transaction_level' => DB::transactionLevel(), 'locks' => $locks];
        }
    }
    $pause = match ($mode) {
        'submit' => str_starts_with($query->sql, 'update "idempotency_records"'),
        'answer' => str_starts_with($query->sql, 'insert into "answer_text_values"'),
        'file' => str_starts_with($query->sql, 'update "files"'),
        'close', 'deadline' => str_starts_with($query->sql, 'update "assessment_attempts"'),
        'probe' => str_contains($query->sql, 'from "assessment_attempts"') && str_ends_with($query->sql, 'for update'),
        default => false,
    };
    if ($pause && ! $held && isset($arguments['ready'])) {
        $held = true;
        if (DB::transactionLevel() !== 1) {
            throw new LogicException('The race must pause inside the operation-owned transaction.');
        }
        publishSignal($arguments['ready'], ['pid' => $pid, 'locks' => $locks,
            'gate_reads' => $gateReads, 'snapshot' => snapshot($arguments)]);
        awaitSignal($arguments['release']);
    }
});
if (isset($arguments['started'])) {
    publishSignal($arguments['started'], ['pid' => $pid]);
}
$uploadPath = null;
try {
    $result = ['pid' => $pid];
    if ($mode === 'deadline') {
        $result['finalized_count'] = app(FinalizeHomeworkAttemptsAtDeadline::class)($arguments['institution'], $arguments['assessment']);
    } elseif ($mode === 'close') {
        app(CloseTeacherHomework::class)(User::query()->findOrFail($arguments['teacher']), $arguments['assessment']);
    } elseif ($mode === 'probe') {
        $result['probe'] = DB::transaction(fn () => AssessmentAttempt::query()
            ->where('institution_id', $arguments['institution'])->whereKey($arguments['attempt'])
            ->lockForUpdate()->firstOrFail()->getAttributes());
    } else {
        Sanctum::actingAs(User::query()->findOrFail($arguments['student']));
        if ($mode === 'submit') {
            $request = Request::create('/api/v1/student/attempts/'.$arguments['attempt'].'/submit', 'POST', [], [], [], [
                'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
                'HTTP_IDEMPOTENCY_KEY' => $arguments['key'],
            ], '{}');
        } elseif ($mode === 'answer') {
            $request = Request::create('/api/v1/student/attempts/'.$arguments['attempt'].'/answers/'.$arguments['text_question'],
                'PUT', [], [], [], ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'],
                json_encode(['type' => 'open_written', 'text' => $arguments['content']], JSON_THROW_ON_ERROR));
        } else {
            $uploadPath = tempnam(sys_get_temp_dir(), 's07_be_007_upload_');
            file_put_contents($uploadPath, "%PDF-1.7\n{$arguments['content']}\n%%EOF\n");
            $upload = new UploadedFile($uploadPath, $arguments['content'].'.pdf', 'application/octet-stream', UPLOAD_ERR_OK, true);
            $request = Request::create('/api/v1/student/attempts/'.$arguments['attempt'].'/answers/'.$arguments['file_question'],
                'PUT', ['type' => 'file_based'], [], ['file' => $upload], [
                    'CONTENT_TYPE' => 'multipart/form-data', 'HTTP_ACCEPT' => 'application/json',
                ]);
        }
        $kernel = $app->make(HttpKernel::class);
        $response = $kernel->handle($request);
        $kernel->terminate($request, $response);
        $result['status'] = $response->getStatusCode();
        $result['body'] = json_decode($response->getContent(), true, flags: JSON_THROW_ON_ERROR);
    }
    $result += ['locks' => $locks, 'gate_reads' => $gateReads, 'snapshot' => snapshot($arguments),
        'stored' => $storage->stored, 'cleanups' => $storage->cleanups, 'deadline_entries' => $deadlineEntries,
        'transaction_level' => DB::transactionLevel()];
    echo json_encode($result, JSON_THROW_ON_ERROR);
} finally {
    if ($uploadPath !== null && file_exists($uploadPath)) {
        unlink($uploadPath);
    }
}
PHP;
    }
}
