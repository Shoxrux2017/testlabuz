<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\IdempotencyOperation;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentHomeworkAttemptStartConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    #[DataProvider('startRaces')]
    public function test_actual_start_serializes_with_start_question_mutation_and_close_on_postgresql(
        string $scenario,
        string $firstOperation,
        string $secondOperation,
        ?int $firstStatus,
        string $secondOutcome,
        ?int $secondStatus,
        int $recordCount,
    ): void {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's07_be_004_start_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            $results = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
            $this->assertSame('ok', $results['first']['outcome']);
            $this->assertSame($firstStatus, $results['first']['http_status']);
            $this->assertSame($secondOutcome, $results['second']['outcome']);
            $this->assertSame($secondStatus, $results['second']['http_status']);

            $attempts = AssessmentAttempt::query()->where('assessment_id', $ids['assessment'])->get();
            $records = IdempotencyRecord::query()
                ->where('institution_id', $ids['institution'])
                ->where('user_id', $ids['student'])
                ->where('operation', IdempotencyOperation::StudentHomeworkAttemptStart->value)
                ->get();
            $this->assertCount($recordCount, $records);
            $this->assertCount($scenario === 'close_first' ? 0 : 1, $attempts);

            foreach ($records as $record) {
                $this->assertNotNull($record->completed_at);
                $this->assertSame('assessment_attempt', $record->result_resource_type);
                $this->assertSame($attempts->sole()->id, $record->result_resource_id);
            }

            $expectedStatuses = $scenario === 'different_keys' ? [200, 201] : ($recordCount === 0 ? [] : [201]);
            $this->assertSame($expectedStatuses, $records->pluck('response_status')->sort()->values()->all());

            $question = Question::query()->findOrFail($ids['question']);
            $assessment = Assessment::query()->findOrFail($ids['assessment']);
            $mutationWon = $scenario === 'mutation_first';
            $expectedPoints = $mutationWon ? '5.000000' : '2.000000';
            $this->assertSame($mutationWon ? 'Concurrent scoring definition' : 'Original question', $question->prompt);
            $this->assertSame($expectedPoints, $question->points);
            $this->assertSame($expectedPoints, $assessment->total_possible_points);
            $this->assertSame(! $mutationWon, QuestionTrueFalseAnswer::query()->findOrFail($question->id)->correct_value);

            $homework = HomeworkAssignment::query()->findOrFail($ids['assessment']);
            $closeRan = in_array($scenario, ['start_before_close', 'close_first'], true);
            $this->assertSame($closeRan ? HomeworkStatus::Closed : HomeworkStatus::Active, $homework->status);

            if ($scenario === 'close_first') {
                $this->assertNull($results['second']['attempt_id']);

                return;
            }

            $attempt = $attempts->sole();
            $this->assertSame(1, $attempt->attempt_number);
            $this->assertSame($expectedPoints, $attempt->possible_points);
            $this->assertNull($attempt->deadline_at);
            $this->assertSame(0, $attempt->answers()->count());
            $this->assertSame(
                $scenario === 'mutation_first' ? '2026-09-09 10:01:00' : '2026-09-09 10:00:00',
                $attempt->started_at->format('Y-m-d H:i:s'),
            );

            foreach (['first' => $firstOperation, 'second' => $secondOperation] as $worker => $operation) {
                if ($operation === 'start') {
                    $this->assertSame($attempt->id, $results[$worker]['attempt_id']);
                }
            }

            if ($scenario === 'start_before_close') {
                $this->assertSame(AssessmentAttemptStatus::Submitted, $attempt->status);
                $this->assertSame(AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize, $attempt->finalization_reason);
                $this->assertNull($attempt->submitted_at);
                $this->assertTrue($homework->closed_at->equalTo($attempt->finalized_at));
                $this->assertTrue($homework->closed_at->equalTo($attempt->locked_at));
                $this->assertTrue($attempt->started_at->lessThan($homework->closed_at));
            } else {
                $this->assertSame(AssessmentAttemptStatus::InProgress, $attempt->status);
                $this->assertNull($attempt->submitted_at);
                $this->assertNull($attempt->finalized_at);
                $this->assertNull($attempt->locked_at);
                $this->assertNull($attempt->finalization_reason);
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /** @return array<string, array{string, string, string, ?int, string, ?int, int}> */
    public static function startRaces(): array
    {
        return [
            'same key replays the first create' => ['same_key', 'start', 'start', 201, 'ok', 201, 1],
            'different keys create then resume' => ['different_keys', 'start', 'start', 201, 'ok', 200, 2],
            'Question mutation commits before Start' => ['mutation_first', 'mutate', 'start', null, 'ok', 201, 1],
            'Start prevents Question mutation' => ['start_before_mutation', 'start', 'mutate', 201, 'business_conflict', null, 1],
            'Start commits before Teacher close' => ['start_before_close', 'start', 'close', 201, 'ok', null, 1],
            'Teacher close prevents Start' => ['close_first', 'close', 'start', null, 'task_closed', null, 0],
        ];
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(
        string $workerPath,
        array $ids,
        string $scenario,
        string $firstOperation,
        string $secondOperation,
    ): array {
        $lockedPath = $this->unusedTempPath('s07_be_004_locked_');
        $releasePath = $this->unusedTempPath('s07_be_004_release_');
        $startedPath = $this->unusedTempPath('s07_be_004_started_');
        $firstKey = (string) Str::uuid();
        $secondKey = $scenario === 'same_key' ? $firstKey : (string) Str::uuid();
        $arguments = [$ids['teacher'], $ids['student'], $ids['assessment'], $ids['question']];
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation, $firstKey, 'hold',
            $lockedPath, $releasePath, $startedPath.'.first', '2026-09-09 10:00:00 UTC',
        ]);
        $second = null;

        try {
            $this->waitForFile($lockedPath, 'The first worker did not retain its operation locks.');
            $firstBackendPid = (int) file_get_contents($lockedPath);
            $second = $this->startWorker([
                $workerPath, base_path(), 'run', ...$arguments, $secondOperation, $secondKey, 'normal',
                $lockedPath, $releasePath, $startedPath, '2026-09-09 10:01:00 UTC',
            ]);
            $this->waitForFile($startedPath, 'The second worker did not begin.');
            $this->waitForPostgresLock((int) file_get_contents($startedPath), $firstBackendPid, $scenario);
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

    private function waitForPostgresLock(int $waitingPid, int $holdingPid, string $scenario): void
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
                $this->assertStringContainsString('"topics"', $activity->query, $scenario);
                $this->assertStringContainsString('for update', $activity->query, $scenario);

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('The second worker never waited on the first transaction for '.$scenario.': '.json_encode($activity));
    }

    /** @return array{process: resource, pipes: array<int, resource>} */
    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open([PHP_BINARY, ...$arguments], [
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

use App\Actions\Student\StartStudentHomeworkAttempt;
use App\Actions\Teacher\CloseTeacherHomework;
use App\Actions\Teacher\UpdateTeacherQuestion;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Exceptions\Student\StudentHomeworkClosedException;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
Carbon::setTestNow(Carbon::parse('2026-09-09 09:00:00 UTC'));
$mode = $argv[2];

if ($mode === 'setup') {
    $institution = Institution::factory()->create();
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create();
    $student = User::factory()->student($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
    $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
    GroupTeacherMembership::factory()->create([
        'institution_id' => $institution->id,
        'group_id' => $group->id,
        'teacher_id' => $teacher->id,
        'assigned_by_user_id' => $admin->id,
    ]);
    $topic = Topic::factory()->active()->create([
        'institution_id' => $institution->id,
        'group_id' => $group->id,
        'teacher_id' => $teacher->id,
    ]);
    $assessment = Assessment::factory()->homework()->create([
        'institution_id' => $institution->id,
        'topic_id' => $topic->id,
        'teacher_id' => $teacher->id,
        'assignment_mode' => AssessmentAssignmentMode::SelectedStudents,
        'total_possible_points' => '2.000000',
    ]);
    HomeworkAssignment::factory()->active()->create([
        'institution_id' => $institution->id,
        'assessment_id' => $assessment->id,
        'deadline_at' => null,
    ]);
    AssessmentStudent::factory()->create([
        'institution_id' => $institution->id,
        'assessment_id' => $assessment->id,
        'student_id' => $student->id,
        'assignment_source' => AssessmentAssignmentSource::Direct,
        'assigned_by_user_id' => $teacher->id,
    ]);
    $question = app(QuestionConfigurationWriter::class)->create($assessment, [
        'type' => 'true_false',
        'prompt' => 'Original question',
        'instructions' => null,
        'points' => 2,
        'position' => 1,
        'checking_mode' => 'automatic',
        'configuration' => ['correct_value' => true],
    ]);

    echo json_encode([
        'institution' => $institution->id,
        'teacher' => $teacher->id,
        'student' => $student->id,
        'assessment' => $assessment->id,
        'question' => $question->id,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    DB::transaction(function () use ($institutionId): void {
        foreach ([IdempotencyRecord::class, AttemptAnswer::class, AssessmentAttempt::class,
            QuestionTrueFalseAnswer::class, Question::class, AssessmentStudent::class,
            HomeworkAssignment::class, Assessment::class, Topic::class, GroupTeacherMembership::class,
            Group::class, InstitutionSetting::class, User::class] as $model) {
            $model::query()->where('institution_id', $institutionId)->delete();
        }
        Institution::query()->whereKey($institutionId)->delete();
    });
    echo '{}';
    exit(0);
}

[$teacherId, $studentId, $assessmentId, $questionId, $operation, $key, $hold,
    $lockedPath, $releasePath, $startedPath, $observedAt] = array_slice($argv, 3);
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

try {
    if ($operation === 'start') {
        $student = User::query()->findOrFail($studentId);
        $result = app(StartStudentHomeworkAttempt::class)($student, $assessmentId, $key);
        $attemptId = $result->attemptId;
        $httpStatus = $result->httpStatus;
    } elseif ($operation === 'mutate') {
        $teacher = User::query()->findOrFail($teacherId);
        app(UpdateTeacherQuestion::class)($teacher, $questionId, [
            'prompt' => 'Concurrent scoring definition',
            'points' => 5,
            'configuration' => ['correct_value' => false],
        ]);
    } else {
        $teacher = User::query()->findOrFail($teacherId);
        app(CloseTeacherHomework::class)($teacher, $assessmentId);
    }
} catch (BusinessConflictException) {
    $outcome = 'business_conflict';
} catch (StudentHomeworkClosedException) {
    $outcome = 'task_closed';
}

if ($hold === 'hold') {
    file_put_contents($lockedPath, (string) $pid);
    $deadline = microtime(true) + 15;
    do {
        clearstatcache(true, $releasePath);
        if (file_exists($releasePath)) {
            DB::commit();
            echo json_encode(['outcome' => $outcome, 'attempt_id' => $attemptId, 'http_status' => $httpStatus], JSON_THROW_ON_ERROR);
            exit(0);
        }
        usleep(5_000);
    } while (microtime(true) < $deadline);
    DB::rollBack();
    throw new RuntimeException('Timed out waiting for deterministic Start race release.');
}

echo json_encode(['outcome' => $outcome, 'attempt_id' => $attemptId, 'http_status' => $httpStatus], JSON_THROW_ON_ERROR);
PHP;
    }
}
