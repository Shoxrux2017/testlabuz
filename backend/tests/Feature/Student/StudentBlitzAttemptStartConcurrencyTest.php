<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\IdempotencyOperation;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Models\IdempotencyRecord;
use App\Models\TopicResultPair;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentBlitzAttemptStartConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    #[DataProvider('executionRaces')]
    public function test_start_and_explicit_resume_serialize_with_competing_execution_and_lifecycle_changes(
        string $scenario,
        string $firstOperation,
        string $secondOperation,
        ?int $firstStatus,
        string $secondOutcome,
        ?int $secondStatus,
        int $recordCount,
    ): void {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's08_be_005_blitz_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup', $scenario]), true, flags: JSON_THROW_ON_ERROR);

        try {
            $before = $ids['attempt'] === null ? null : AssessmentAttempt::query()->findOrFail($ids['attempt'])->getAttributes();
            $pairBefore = $ids['pair'] === null ? null : TopicResultPair::query()->findOrFail($ids['pair'])->getAttributes();
            $results = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
            $this->assertSame('ok', $results['first']['outcome']);
            $this->assertSame($firstStatus, $results['first']['http_status']);
            $this->assertSame($secondOutcome, $results['second']['outcome']);
            $this->assertSame($secondStatus, $results['second']['http_status']);

            $attempts = AssessmentAttempt::query()->where('assessment_id', $ids['assessment'])->orderBy('student_id')->get();
            $records = IdempotencyRecord::query()->where('institution_id', $ids['institution'])
                ->where('operation', IdempotencyOperation::StudentBlitzAttemptStart->value)->get();
            $this->assertCount($recordCount, $records);
            $this->assertCount($scenario === 'closed_first' ? 0 : ($scenario === 'official_students' ? 2 : 1), $attempts);

            foreach ($records as $record) {
                $this->assertNotNull($record->completed_at);
                $this->assertSame('assessment_attempt', $record->result_resource_type);
                $this->assertTrue($attempts->contains('id', $record->result_resource_id));
                $this->assertContains($record->response_status, [200, 201]);
            }
            foreach ($attempts as $attempt) {
                $this->assertSame(1, $attempt->attempt_number);
                $this->assertTrue($attempt->started_at->copy()->addSeconds(600)->equalTo($attempt->deadline_at));
                $this->assertSame('000000', $attempt->started_at->format('u'));
                $this->assertSame('000000', $attempt->deadline_at->format('u'));
                $this->assertSame(0, $attempt->answers()->count());
                $this->assertSame(1, $attempts->where('student_id', $attempt->student_id)->count());
            }

            if ($scenario === 'closed_first') {
                $this->assertNull($results['second']['attempt_id']);
            } elseif ($scenario === 'official_students') {
                $firstAttempt = $attempts->firstWhere('student_id', $ids['student']);
                $secondAttempt = $attempts->firstWhere('student_id', $ids['other_student']);
                $this->assertSame($firstAttempt->id, $results['first']['attempt_id']);
                $this->assertSame($secondAttempt->id, $results['second']['attempt_id']);
                $this->assertSame('2026-09-17 10:00:00', $firstAttempt->started_at->format('Y-m-d H:i:s'));
                $this->assertSame('2026-09-17 10:01:00', $secondAttempt->started_at->format('Y-m-d H:i:s'));
                $this->assertSame(1, $results['first']['pair_updates']);
                $this->assertSame(0, $results['second']['pair_updates']);
                $pair = TopicResultPair::query()->findOrFail($ids['pair']);
                $this->assertTrue($pair->locked_at->equalTo($firstAttempt->started_at));
                $this->assertTrue($pair->updated_at->equalTo($firstAttempt->started_at));
                foreach (['institution_id', 'topic_id', 'homework_assessment_id', 'blitz_assessment_id', 'cohort_snapshotted_at'] as $attribute) {
                    $this->assertSame($pairBefore[$attribute], $pair->getRawOriginal($attribute));
                }
            } else {
                $attempt = $attempts->sole();
                foreach (['first', 'second'] as $worker) {
                    if ($results[$worker]['http_status'] !== null) {
                        $this->assertSame($attempt->id, $results[$worker]['attempt_id']);
                        $this->assertSame($attempt->deadline_at->format('Y-m-d H:i:s'), $results[$worker]['deadline_at']);
                    }
                }
                if ($before !== null) {
                    $this->assertSame($before['id'], $attempt->id);
                    $this->assertSame($before['started_at'], $attempt->getRawOriginal('started_at'));
                    $this->assertSame($before['deadline_at'], $attempt->getRawOriginal('deadline_at'));
                    if ($scenario === 'resume') {
                        $this->assertSame($before, $attempt->getAttributes());
                    }
                } else {
                    $this->assertSame('2026-09-17 10:00:00', $attempt->started_at->format('Y-m-d H:i:s'));
                }
            }

            $terminal = in_array($scenario, ['terminal_first', 'resume_before_terminal', 'start_before_close'], true);
            foreach ($attempts as $attempt) {
                $this->assertSame($terminal ? AssessmentAttemptStatus::Submitted : AssessmentAttemptStatus::InProgress, $attempt->status);
            }
            $this->assertSame(
                in_array($scenario, ['closed_first', 'start_before_close'], true) ? BlitzStatus::Closed : BlitzStatus::Active,
                BlitzTask::query()->findOrFail($ids['assessment'])->status,
            );
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    public static function executionRaces(): array
    {
        return [
            'same Start key replays one create' => ['same_key', 'start_normal', 'start_normal', 201, 'ok', 201, 1],
            'different Start keys return one Attempt' => ['different_keys', 'start_normal', 'start_normal', 201, 'ok', 200, 2],
            'explicit Resume keys retain exact Attempt' => ['resume', 'resume', 'resume', 200, 'ok', 200, 2],
            'terminalization wins before exact Resume' => ['terminal_first', 'terminalize', 'resume', null, 'attempt_not_editable', null, 0],
            'exact Resume wins before terminalization' => ['resume_before_terminal', 'resume', 'terminalize', 200, 'ok', null, 1],
            'two Students first-start official pair' => ['official_students', 'start_normal', 'start_normal', 201, 'ok', 201, 2],
            'Closed lifecycle wins before Start' => ['closed_first', 'close', 'start_normal', null, 'blitz_not_active', null, 0],
            'Start wins before controlled Close' => ['start_before_close', 'start_normal', 'close', 201, 'ok', null, 1],
        ];
    }

    private function runRace(string $workerPath, array $ids, string $scenario, string $firstOperation, string $secondOperation): array
    {
        $lockedPath = $this->unusedTempPath('s08_blitz_locked_');
        $releasePath = $this->unusedTempPath('s08_blitz_release_');
        $startedPath = $this->unusedTempPath('s08_blitz_started_');
        $firstKey = (string) Str::uuid();
        $secondKey = $scenario === 'same_key' ? $firstKey : (string) Str::uuid();
        $encodedIds = json_encode($ids, JSON_THROW_ON_ERROR);
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', $encodedIds, $firstOperation, $firstKey, 'hold',
            $lockedPath, $releasePath, $startedPath.'.first', '2026-09-17 10:00:00 UTC', $ids['student'],
        ]);
        $second = null;

        try {
            $this->waitForFile($lockedPath, 'The first Blitz worker did not retain its locks.');
            $firstPid = (int) file_get_contents($lockedPath);
            $second = $this->startWorker([
                $workerPath, base_path(), 'run', $encodedIds, $secondOperation, $secondKey, 'normal',
                $lockedPath, $releasePath, $startedPath, '2026-09-17 10:01:00 UTC',
                $scenario === 'official_students' ? $ids['other_student'] : $ids['student'],
            ]);
            $this->waitForFile($startedPath, 'The second Blitz worker did not begin.');
            $this->waitForPostgresLock((int) file_get_contents($startedPath), $firstPid);
        } finally {
            file_put_contents($releasePath, 'release');
            try {
                $firstOutput = $this->finishWorker($first);
                $secondOutput = $second === null ? null : $this->finishWorker($second);
            } finally {
                foreach ([$lockedPath, $releasePath, $startedPath, $startedPath.'.first'] as $path) {
                    if (file_exists($path)) {
                        unlink($path);
                    }
                }
            }
        }

        return [
            'first' => json_decode($firstOutput, true, flags: JSON_THROW_ON_ERROR),
            'second' => json_decode($secondOutput, true, flags: JSON_THROW_ON_ERROR),
        ];
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

    private function waitForPostgresLock(int $waitingPid, int $holdingPid): void
    {
        $deadline = microtime(true) + 10;
        $activity = null;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne(
                'select wait_event_type, query, ? = any(pg_blocking_pids(pid)) as blocked_by_first from pg_stat_activity where pid = ?',
                [$holdingPid, $waitingPid],
            );
            if ($activity !== null && $activity->wait_event_type === 'Lock' && $activity->blocked_by_first) {
                $this->assertStringContainsString('"topics"', $activity->query);
                $this->assertStringContainsString('for update', $activity->query);

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('The second Blitz worker never waited on its parent lock: '.json_encode($activity));
    }

    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open([PHP_BINARY, ...$arguments], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
        $this->assertIsResource($process);
        fclose($pipes[0]);

        return ['process' => $process, 'pipes' => $pipes];
    }

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

use App\Actions\Student\StartStudentBlitzAttempt;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Exceptions\Student\StudentBlitzAttemptNotEditableException;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use App\Support\Student\StudentBlitzAttemptAccess;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
Carbon::setTestNow(Carbon::parse('2026-09-17 09:59:00 UTC'));
$mode = $argv[2];

if ($mode === 'setup') {
    $scenario = $argv[3];
    $institution = Institution::factory()->create();
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $teacher = User::factory()->teacher($institution)->create();
    $student = User::factory()->student($institution)->create(['must_change_password' => false]);
    $otherStudent = User::factory()->student($institution)->create(['must_change_password' => false]);
    $topic = Topic::factory()->active()->create(['institution_id' => $institution->id, 'teacher_id' => $teacher->id]);
    $assessment = Assessment::factory()->blitz()->groupAssignment()->create([
        'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
        'total_possible_points' => '2.000000',
    ]);
    BlitzTask::factory()->activeIndividual()->create(['assessment_id' => $assessment->id]);
    foreach ([$student, $otherStudent] as $recipientStudent) {
        AssessmentStudent::factory()->create([
            'assessment_id' => $assessment->id, 'student_id' => $recipientStudent->id,
            'assigned_by_user_id' => $teacher->id,
        ]);
    }
    app(QuestionConfigurationWriter::class)->create($assessment, [
        'type' => 'true_false', 'prompt' => 'Concurrent Blitz question', 'instructions' => null,
        'points' => 2, 'position' => 1, 'checking_mode' => 'automatic',
        'configuration' => ['correct_value' => true],
    ]);
    $attempt = null;
    if (in_array($scenario, ['resume', 'terminal_first', 'resume_before_terminal'], true)) {
        $recipient = AssessmentStudent::query()->where('assessment_id', $assessment->id)->where('student_id', $student->id)->sole();
        $attempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id, 'started_at' => now(),
            'deadline_at' => now()->addSeconds(600), 'possible_points' => '2.000000',
        ]);
    }
    $pair = null;
    if ($scenario === 'official_students') {
        $homework = Assessment::factory()->homework()->groupAssignment()->create([
            'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
        ]);
        HomeworkAssignment::factory()->active()->create(['assessment_id' => $homework->id]);
        foreach ([$student, $otherStudent] as $recipientStudent) {
            AssessmentStudent::factory()->create([
                'assessment_id' => $homework->id, 'student_id' => $recipientStudent->id,
                'assigned_by_user_id' => $teacher->id,
            ]);
        }
        $pair = TopicResultPair::factory()->create([
            'homework_assessment_id' => $homework->id, 'blitz_assessment_id' => $assessment->id,
            'designated_by_user_id' => $teacher->id, 'cohort_snapshotted_at' => now(),
        ]);
    }
    echo json_encode([
        'institution' => $institution->id, 'student' => $student->id, 'other_student' => $otherStudent->id,
        'assessment' => $assessment->id, 'attempt' => $attempt?->id, 'pair' => $pair?->id,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    DB::transaction(function () use ($institutionId): void {
        foreach ([IdempotencyRecord::class, AttemptAnswer::class, AssessmentAttempt::class,
            QuestionTrueFalseAnswer::class, Question::class, AssessmentStudent::class, TopicResultPair::class,
            BlitzTask::class, HomeworkAssignment::class, Assessment::class, Topic::class, Group::class,
            InstitutionSetting::class, User::class] as $model) {
            $model::query()->where('institution_id', $institutionId)->delete();
        }
        Institution::query()->whereKey($institutionId)->delete();
    });
    echo '{}';
    exit(0);
}

[$encodedIds, $operation, $key, $hold, $lockedPath, $releasePath, $startedPath, $observedAt, $studentId] = array_slice($argv, 3);
$ids = json_decode($encodedIds, true, flags: JSON_THROW_ON_ERROR);
Carbon::setTestNow(Carbon::parse($observedAt));
DB::statement("set lock_timeout = '10s'");
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($startedPath, (string) $pid);
if ($hold === 'hold') {
    DB::beginTransaction();
}
$outcome = 'ok';
$attemptId = null;
$httpStatus = null;
$deadlineAt = null;
$pairUpdates = 0;
DB::listen(function (QueryExecuted $query) use (&$pairUpdates): void {
    if (str_starts_with($query->sql, 'update "topic_result_pairs"')) {
        $pairUpdates++;
    }
});

try {
    $student = User::query()->findOrFail($studentId);
    if (in_array($operation, ['start_normal', 'resume'], true)) {
        $result = app(StartStudentBlitzAttempt::class)(
            $student, $ids['assessment'], $key, $operation, $operation === 'resume' ? $ids['attempt'] : null,
        );
        $attemptId = $result->attemptId;
        $httpStatus = $result->httpStatus;
        $deadlineAt = $result->attempt->deadline_at->format('Y-m-d H:i:s');
    } else {
        // Controlled future lifecycle mutation uses the same parent-first boundary without adding a public endpoint.
        DB::transaction(function () use ($student, $ids, $operation): void {
            $access = app(StudentBlitzAttemptAccess::class);
            $authorized = Assessment::query()->where('institution_id', $student->institution_id)->findOrFail($ids['assessment']);
            ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] = $access->lockBlitz($student, $authorized);
            $pair = $access->lockPair($student, $topic);
            $recipient = AssessmentStudent::query()->where('institution_id', $student->institution_id)
                ->where('assessment_id', $assessment->id)->where('student_id', $student->id)->sole();
            $access->lockRecipient($student, $assessment, $recipient->id);
            $attempts = $access->lockAttempts($student, $assessment, $pair);
            if ($operation === 'close') {
                $blitz->status = BlitzStatus::Closed;
                $blitz->closed_at = now();
                $blitz->save();
            } else {
                $attempts = $attempts->where('id', $ids['attempt']);
                if ($attempts->count() !== 1) {
                    throw new RuntimeException('Controlled terminalization lost its exact Attempt.');
                }
            }
            foreach ($attempts as $attempt) {
                $attempt->update([
                    'status' => AssessmentAttemptStatus::Submitted,
                    'submitted_at' => $operation === 'close' ? null : now(),
                    'finalized_at' => now(), 'locked_at' => now(),
                    'finalization_reason' => $operation === 'close'
                        ? AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize
                        : AssessmentAttemptFinalizationReason::StudentSubmit,
                ]);
            }
        });
    }
} catch (StudentBlitzAttemptNotEditableException) {
    $outcome = 'attempt_not_editable';
} catch (StudentBlitzNotActiveException) {
    $outcome = 'blitz_not_active';
}

if ($hold === 'hold') {
    file_put_contents($lockedPath, (string) $pid);
    $deadline = microtime(true) + 15;
    do {
        clearstatcache(true, $releasePath);
        if (file_exists($releasePath)) {
            DB::commit();
            echo json_encode(['outcome' => $outcome, 'attempt_id' => $attemptId, 'http_status' => $httpStatus,
                'deadline_at' => $deadlineAt, 'pair_updates' => $pairUpdates], JSON_THROW_ON_ERROR);
            exit(0);
        }
        usleep(5_000);
    } while (microtime(true) < $deadline);
    DB::rollBack();
    throw new RuntimeException('Timed out waiting for deterministic Blitz race release.');
}
echo json_encode(['outcome' => $outcome, 'attempt_id' => $attemptId, 'http_status' => $httpStatus,
    'deadline_at' => $deadlineAt, 'pair_updates' => $pairUpdates], JSON_THROW_ON_ERROR);
PHP;
    }
}
