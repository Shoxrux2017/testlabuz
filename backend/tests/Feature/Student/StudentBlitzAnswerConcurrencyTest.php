<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentBlitzAnswerConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    #[DataProvider('serializedMutations')]
    public function test_attempt_lock_serializes_complete_answers_deadline_observation_and_terminal_winners(string $scenario): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's08_be_006_typed_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup', $scenario]), true, flags: JSON_THROW_ON_ERROR);
        try {
            $attemptBefore = AssessmentAttempt::query()->findOrFail($ids['attempt'])->getAttributes();
            $results = $this->runRace($workerPath, $ids, $scenario);
            $this->assertSame(200, $results['first']['status'], json_encode($results['first']['body']));
            $expectedFailure = match ($scenario) {
                'deadline' => 'blitz_time_expired', 'terminal' => 'attempt_not_editable', default => null,
            };
            $this->assertSame($expectedFailure === null ? 200 : 409, $results['second']['status'], json_encode($results['second']['body']));
            if ($expectedFailure !== null) {
                $this->assertSame($expectedFailure, $results['second']['body']['code']);
            }
            foreach ([$results['second'], ...($scenario === 'terminal' ? [] : [$results['first']])] as $result) {
                $expectedLocks = [
                    ['table' => 'topics', 'mode' => 'share'], ['table' => 'assessments', 'mode' => 'share'],
                    ['table' => 'blitz_tasks', 'mode' => 'share'], ['table' => 'assessment_attempts', 'mode' => 'update'],
                    ['table' => 'questions', 'mode' => 'share'], ['table' => 'attempt_answers', 'mode' => 'update'],
                ];
                if ($scenario === 'deadline' && $result['status'] === 409) {
                    array_push($expectedLocks,
                        ['table' => 'assessments', 'mode' => 'update'],
                        ['table' => 'blitz_tasks', 'mode' => 'update'],
                        ['table' => 'assessment_attempts', 'mode' => 'update'],
                    );
                }
                $this->assertSame($expectedLocks, $result['locks']);
            }
            $firstExpected = match ($scenario) {
                'clear-last' => [], 'terminal' => $ids['initial_options'],
                'different', 'deadline' => $ids['first_options'], default => $ids['second_options'],
            };
            $this->assertAnswer($ids['attempt'], $ids['question'], $firstExpected);
            $this->assertAnswer($ids['attempt'], $ids['other_question'], $scenario === 'different' ? $ids['other_options'] : []);
            $attempt = AssessmentAttempt::query()->findOrFail($ids['attempt']);
            if ($scenario === 'terminal') {
                $this->assertSame(AssessmentAttemptStatus::Submitted, $attempt->status);
                $this->assertSame('2026-09-17 12:01:00', $attempt->finalized_at->format('Y-m-d H:i:s'));
            } elseif ($scenario === 'deadline') {
                $transitionFields = array_flip(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at']);
                $this->assertSame(array_diff_key($attemptBefore, $transitionFields), array_diff_key($attempt->getAttributes(), $transitionFields));
                $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $attempt->status);
                $this->assertNull($attempt->submitted_at);
                $this->assertEquals($attempt->deadline_at, $attempt->finalized_at);
                $this->assertEquals($attempt->deadline_at, $attempt->locked_at);
                $this->assertSame('timeout_auto_submit', $attempt->finalization_reason->value);
            } else {
                $this->assertSame($attemptBefore, $attempt->getAttributes());
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    public static function serializedMutations(): array
    {
        return array_map(fn (string $scenario): array => [$scenario], ['create', 'replace', 'different', 'clear-first', 'clear-last', 'deadline', 'terminal']);
    }

    private function assertAnswer(string $attemptId, string $questionId, array $options): void
    {
        $answers = AttemptAnswer::query()->where('attempt_id', $attemptId)->where('question_id', $questionId)->get();
        $this->assertCount($options === [] ? 0 : 1, $answers);
        if ($options === []) {
            return;
        }
        $answer = $answers->sole();
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->checking_status);
        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
            $this->assertNull($answer->{$field});
        }
        $actual = DB::table('answer_choice_selections')->where('answer_id', $answer->id)->pluck('option_id')->all();
        $this->assertEqualsCanonicalizing($options, $actual);
        $this->assertCount(count(array_unique($actual)), $actual);
        foreach (['answer_boolean_values', 'answer_text_values', 'answer_matching_pairs',
            'answer_ordering_items', 'answer_fill_blank_values', 'answer_files'] as $table) {
            $this->assertSame(0, DB::table($table)->where('answer_id', $answer->id)->count());
        }
    }

    private function runRace(string $workerPath, array $ids, string $scenario): array
    {
        $firstReadyPath = $this->unusedTempPath();
        $secondReadyPath = $this->unusedTempPath();
        $releasePath = $this->unusedTempPath();
        $startedPath = $this->unusedTempPath();
        $first = $this->startWorker([$workerPath, base_path(), $scenario === 'terminal' ? 'finalize' : 'save',
            $ids['student'], $ids['attempt'], $ids['question'],
            json_encode($scenario === 'clear-first' ? [] : $ids['first_options'], JSON_THROW_ON_ERROR),
            'hold', $firstReadyPath, $releasePath, $startedPath.'.first', '2026-09-17 12:01:00 UTC']);
        $second = null;
        try {
            $this->waitForFile($firstReadyPath);
            $firstReady = json_decode(file_get_contents($firstReadyPath), true, flags: JSON_THROW_ON_ERROR);
            $this->assertSame(200, $firstReady['status'], json_encode($firstReady['body']));
            $secondOptions = match ($scenario) {
                'clear-last' => [], 'different' => $ids['other_options'], default => $ids['second_options'],
            };
            $second = $this->startWorker([$workerPath, base_path(), 'save', $ids['student'], $ids['attempt'],
                $ids[$scenario === 'different' ? 'other_question' : 'question'], json_encode($secondOptions, JSON_THROW_ON_ERROR),
                'normal', $secondReadyPath, $releasePath, $startedPath,
                $scenario === 'deadline' ? $ids['deadline'] : '2026-09-17 12:02:00 UTC']);
            $this->waitForFile($startedPath);
            $this->waitForAttemptLock((int) file_get_contents($startedPath), $firstReady['pid']);
            $this->assertFileDoesNotExist($secondReadyPath);
        } finally {
            file_put_contents($releasePath, 'release');
            try {
                $firstOutput = $this->finishWorker($first);
                $secondOutput = $second === null ? '{}' : $this->finishWorker($second);
            } finally {
                foreach ([$firstReadyPath, $secondReadyPath, $releasePath, $startedPath, $startedPath.'.first'] as $path) {
                    if (file_exists($path)) {
                        unlink($path);
                    }
                }
            }
        }

        return ['first' => json_decode($firstOutput, true, flags: JSON_THROW_ON_ERROR),
            'second' => json_decode($secondOutput, true, flags: JSON_THROW_ON_ERROR)];
    }

    private function waitForAttemptLock(int $waitingPid, int $holdingPid): void
    {
        $deadline = microtime(true) + 10;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne('select wait_event_type, query, ? = any(pg_blocking_pids(pid)) as blocked_by_first from pg_stat_activity where pid = ?', [$holdingPid, $waitingPid]);
            if ($activity !== null && $activity->wait_event_type === 'Lock' && $activity->blocked_by_first) {
                $this->assertStringContainsString('from "assessment_attempts"', $activity->query);
                $this->assertStringContainsString('for update', $activity->query);

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('The competing Blitz write did not wait on the decisive Attempt lock: '.json_encode($activity));
    }

    private function unusedTempPath(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's08_be_006_typed_barrier_');
        $this->assertIsString($path);
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
        $this->fail('The concurrent Blitz worker did not reach its deterministic barrier.');
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
        $this->assertSame(0, proc_close($worker['process']), $stderr."\nSTDOUT: {$stdout}");

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

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\QuestionChoiceOption;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
if (DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new LogicException('Typed-answer concurrency workers require the isolated PostgreSQL testing database.');
}
Carbon::setTestNow(Carbon::parse('2026-09-17 12:00:00 UTC'));
$mode = $argv[2];

if ($mode === 'setup') {
    $fixture = new class
    {
        use BuildsStudentBlitzAnswerContext;

        public function create(string $scenario): array
        {
            [$student, $blitz, $attempt] = $this->answerContext();
            $question = $this->answerQuestion($blitz, 'multiple_choice');
            $other = $this->answerQuestion($blitz, 'multiple_choice', 2);
            $options = QuestionChoiceOption::query()->where('question_id', $question->id)->orderBy('position')->pluck('id')->all();
            $otherOptions = QuestionChoiceOption::query()->where('question_id', $other->id)->orderBy('position')->limit(2)->pluck('id')->all();
            if ($scenario !== 'create') {
                $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
                $answer->selectedOptions()->attach($options[0], ['institution_id' => $student->institution_id, 'created_at' => now()]);
            }

            return ['institution' => $student->institution_id, 'student' => $student->id, 'attempt' => $attempt->id,
                'question' => $question->id, 'other_question' => $other->id, 'initial_options' => [$options[0]],
                'first_options' => array_slice($options, 0, 2), 'second_options' => array_slice($options, 2, 2),
                'other_options' => $otherOptions, 'deadline' => $attempt->deadline_at->format('Y-m-d H:i:s').' UTC'];
        }
    };
    echo json_encode($fixture->create($argv[3]), JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    DB::transaction(function () use ($argv): void {
        foreach (['answer_choice_selections', 'attempt_answers', 'assessment_attempts', 'question_choice_options',
            'questions', 'assessment_students', 'blitz_tasks', 'assessments', 'topics', 'group_student_memberships',
            'group_teacher_memberships', 'groups', 'institution_settings', 'users'] as $table) {
            DB::table($table)->where('institution_id', $argv[3])->delete();
        }
        DB::table('institutions')->where('id', $argv[3])->delete();
    });
    echo '{}';
    exit(0);
}

[$studentId, $attemptId, $questionId, $optionsJson, $hold, $readyPath, $releasePath, $startedPath, $observedAt] = array_slice($argv, 3);
DB::statement("set lock_timeout = '10s'");
$pid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($startedPath, (string) $pid);
$locks = [];
DB::listen(function ($query) use (&$locks, $observedAt): void {
    if (preg_match('/from "(topics|assessments|blitz_tasks|assessment_attempts|questions|attempt_answers)".* for (share|update)$/s', $query->sql, $matches)) {
        $locks[] = ['table' => $matches[1], 'mode' => $matches[2]];
        if ($matches[1] === 'assessment_attempts') {
            Carbon::setTestNow(Carbon::parse($observedAt));
        }
    }
});
DB::beginTransaction();
try {
    if ($mode === 'finalize') {
        $attempt = AssessmentAttempt::query()->whereKey($attemptId)->lockForUpdate()->firstOrFail();
        $attempt->update(['status' => AssessmentAttemptStatus::Submitted, 'submitted_at' => now(),
            'finalized_at' => now(), 'locked_at' => now(), 'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit]);
        $status = 200;
        $body = [];
    } else {
        Sanctum::actingAs(User::query()->findOrFail($studentId));
        $request = Request::create('/api/v1/student/attempts/'.$attemptId.'/answers/'.$questionId, 'PUT', [], [], [], [
            'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
        ], json_encode(['type' => 'multiple_choice', 'selected_option_ids' => json_decode($optionsJson, true, flags: JSON_THROW_ON_ERROR)], JSON_THROW_ON_ERROR));
        $kernel = $app->make(HttpKernel::class);
        $response = $kernel->handle($request);
        $kernel->terminate($request, $response);
        $status = $response->getStatusCode();
        $body = json_decode($response->getContent(), true, flags: JSON_THROW_ON_ERROR);
    }
    if (DB::transactionLevel() !== 1) {
        throw new LogicException('Blitz mutation must retain the outer transaction and Attempt lock.');
    }
    $result = ['pid' => $pid, 'status' => $status, 'body' => $body, 'locks' => $locks];
    file_put_contents($readyPath, json_encode($result, JSON_THROW_ON_ERROR));
    if ($hold === 'hold') {
        $deadline = microtime(true) + 15;
        do {
            clearstatcache(true, $releasePath);
            if (file_exists($releasePath)) {
                break;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        if (! file_exists($releasePath)) {
            throw new RuntimeException('Timed out waiting for the deterministic Blitz race release.');
        }
    }
    DB::commit();
    echo json_encode($result, JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    DB::rollBack();
    throw $exception;
}
PHP;
    }
}
