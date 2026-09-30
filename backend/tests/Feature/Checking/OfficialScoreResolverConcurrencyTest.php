<?php

namespace Tests\Feature\Checking;

use App\Models\AssessmentAttempt;
use App\Models\OfficialTaskScore;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Resolver race (S09-DOC-001 §8): two checking runs for two Attempts of one Student decide the
 * official score one after the other, because both lock the recipient before reading Attempts.
 * Unserialized, each run would see the other Attempt still frozen (bound 100) and store nothing.
 */
class OfficialScoreResolverConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    private string $workerPath;

    /** @var list<string> */
    private array $paths = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $this->workerPath = $this->path();
        file_put_contents($this->workerPath, $this->workerSource());
    }

    protected function tearDown(): void
    {
        foreach ($this->paths as $path) {
            if (file_exists($path)) {
                unlink($path);
            }
        }
        parent::tearDown();
    }

    public function test_two_checking_runs_for_one_student_serialize_on_the_recipient(): void
    {
        $ids = json_decode($this->runWorker(['setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            [$ready, $release, $started] = [$this->path(), $this->path(), $this->path()];
            $first = $this->startWorker(['check', $ids['first'], $ready, $release]);
            $second = null;
            try {
                $holder = json_decode($this->waitForFile($ready), true, flags: JSON_THROW_ON_ERROR);
                $second = $this->startWorker(['check', $ids['second'], '', '', $started]);
                $this->waitForRecipientLock((int) $this->waitForFile($started), $holder['pid']);
            } finally {
                file_put_contents($release, 'release');
                $results = [$this->finishWorker($first), $second === null ? null : $this->finishWorker($second)];
            }

            $this->assertSame(['{"checked":true}', '{"checked":true}'], $results);
            $this->assertSame(['50.00000000', '100.00000000'], [
                AssessmentAttempt::query()->findOrFail($ids['first'])->normalized_score,
                AssessmentAttempt::query()->findOrFail($ids['second'])->normalized_score,
            ]);
            $row = OfficialTaskScore::query()->where('institution_id', $ids['institution'])->sole();
            $this->assertSame([$ids['second'], '100.00000000'], [$row->official_attempt_id, $row->normalized_score]);
        } finally {
            $this->runWorker(['cleanup', $ids['institution']]);
        }
    }

    private function waitForRecipientLock(int $waitingPid, int $holdingPid): void
    {
        $deadline = microtime(true) + 10;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne('select wait_event_type, query, ? = any(pg_blocking_pids(pid)) as blocked from pg_stat_activity where pid = ?',
                [$holdingPid, $waitingPid]);
            if ($activity !== null && $activity->wait_event_type === 'Lock' && $activity->blocked) {
                $this->assertStringContainsString('from "assessment_students"', $activity->query);

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('The second checking run did not wait on the recipient lock: '.json_encode($activity));
    }

    private function path(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's09_be_004_race_');
        $this->assertIsString($path);
        unlink($path);
        $this->paths[] = $path;

        return $path;
    }

    private function waitForFile(string $path): string
    {
        $deadline = microtime(true) + 10;
        do {
            clearstatcache(true, $path);
            if (file_exists($path) && filesize($path) > 0) {
                return file_get_contents($path);
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        $this->fail('The checking worker did not reach its barrier.');
    }

    /** @param list<string> $arguments */
    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open([PHP_BINARY, $this->workerPath, base_path(), ...$arguments],
            [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
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

    /** @param list<string> $arguments */
    private function runWorker(array $arguments): string
    {
        return $this->finishWorker($this->startWorker($arguments));
    }

    private function workerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Checking\CheckFrozenAttempt;
use App\Models\AnswerBooleanValue;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\QuestionChoiceOption;
use App\Models\TopicResultPair;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkAnswerContext;

require $argv[1].'/vendor/autoload.php';
$app = require $argv[1].'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
if (DB::connection()->getDriverName() !== 'pgsql'
    || DB::selectOne('select current_database() as name')->name !== 'testlabuz_testing') {
    throw new LogicException('Resolver race workers require the isolated PostgreSQL testing database.');
}
Carbon::setTestNow(Carbon::parse('2026-09-30 10:00:00 UTC'));
$mode = $argv[2];

if ($mode === 'setup') {
    $fixture = new class
    {
        use BuildsStudentHomeworkAnswerContext;

        public function create(): array
        {
            [$student, $homework, $first] = $this->answerContext();
            TopicResultPair::factory()->create(['homework_assessment_id' => $homework->assessment_id]);
            $trueFalse = $this->answerQuestion($homework, 'true_false', 1);
            $choice = $this->answerQuestion($homework, 'single_choice', 2);
            $frozen = ['status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
                'finalization_reason' => 'student_submit', 'possible_points' => '2.000000'];
            DB::table('assessment_attempts')->where('id', $first->id)->update($frozen);
            $second = AssessmentAttempt::factory()->create(['assessment_student_id' => $first->assessment_student_id,
                'attempt_number' => 2, 'started_at' => now()] + $frozen);
            // #1 earns 1 of 2 points; #2 earns both.
            foreach ([$first, $second] as $attempt) {
                $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $trueFalse->id]);
                AnswerBooleanValue::factory()->create(['answer_id' => $answer->id, 'boolean_value' => true]);
            }
            $answer = AttemptAnswer::factory()->create(['attempt_id' => $second->id, 'question_id' => $choice->id]);
            $answer->selectedOptions()->attach(
                QuestionChoiceOption::query()->where('question_id', $choice->id)->where('is_correct', true)->sole()->id,
                ['institution_id' => $student->institution_id, 'created_at' => now()],
            );

            return ['institution' => $student->institution_id, 'first' => $first->id, 'second' => $second->id];
        }
    };
    echo json_encode($fixture->create(), JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    DB::transaction(function () use ($argv): void {
        foreach (['official_task_scores', 'answer_boolean_values', 'answer_choice_selections', 'attempt_answers',
            'assessment_attempts', 'question_true_false_answers', 'question_choice_options', 'questions',
            'assessment_students', 'homework_assignments', 'topic_result_pairs', 'assessments', 'topics',
            'group_student_memberships', 'group_teacher_memberships', 'groups', 'institution_settings', 'users'] as $table) {
            DB::table($table)->where('institution_id', $argv[3])->delete();
        }
        DB::table('institutions')->where('id', $argv[3])->delete();
    });
    echo '{}';
    exit(0);
}

[$attemptId, $readyPath, $releasePath] = [$argv[3], $argv[4], $argv[5]];
DB::statement("set lock_timeout = '10s'");
$pid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
if (isset($argv[6])) {
    file_put_contents($argv[6], (string) $pid);
}
$held = false;
DB::listen(function ($query) use (&$held, $readyPath, $releasePath, $pid): void {
    if ($held || $readyPath === '' || ! str_contains($query->sql, 'from "assessment_students"') || ! str_ends_with($query->sql, 'for update')) {
        return;
    }
    // Hold the recipient lock until the test has seen the second run wait on it.
    $held = true;
    file_put_contents($readyPath, json_encode(['pid' => $pid], JSON_THROW_ON_ERROR));
    $deadline = microtime(true) + 15;
    while (! file_exists($releasePath)) {
        if (microtime(true) > $deadline) {
            throw new RuntimeException('The resolver race was never released.');
        }
        usleep(5_000);
        clearstatcache(true, $releasePath);
    }
});
echo json_encode(['checked' => app(CheckFrozenAttempt::class)($attemptId)], JSON_THROW_ON_ERROR);
PHP;
    }
}
