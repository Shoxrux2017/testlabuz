<?php

namespace Tests\Feature\Teacher;

use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Concurrent review saves of one submission (docs/09 §23.1, §34.7): the second save waits on
 * the Student's recipient lock, then re-evaluates and writes; the answer keeps the value of the
 * last commit and the Attempt is scored from it.
 */
class TeacherSubmissionReviewConcurrencyTest extends TestCase
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

    public function test_two_saves_of_one_answer_serialize_and_the_last_commit_wins(): void
    {
        $ids = json_decode($this->runWorker(['setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            [$ready, $release, $started] = [$this->path(), $this->path(), $this->path()];
            $first = $this->startWorker(['review', $ids['teacher'], $ids['attempt'], $ids['answer'], '1', 'First.', $ready, $release]);
            $second = null;
            try {
                $holder = json_decode($this->waitForFile($ready), true, flags: JSON_THROW_ON_ERROR);
                $second = $this->startWorker(['review', $ids['teacher'], $ids['attempt'], $ids['answer'], '2', 'Second.', '', '', $started]);
                $this->waitForRecipientLock((int) $this->waitForFile($started), $holder['pid']);
            } finally {
                file_put_contents($release, 'release');
                $results = [$this->finishWorker($first), $second === null ? null : $this->finishWorker($second)];
            }

            $this->assertSame(['{"status":"checked"}', '{"status":"checked"}'], $results);
            $answer = AttemptAnswer::query()->findOrFail($ids['answer']);
            $this->assertSame(['teacher_checked', '2.00000000', 'Second.'], [$answer->getRawOriginal('checking_status'),
                $answer->awarded_points, $answer->feedback]);
            $attempt = AssessmentAttempt::query()->findOrFail($ids['attempt']);
            $this->assertSame(['checked', '2.00000000', '50.00000000'], [$attempt->getRawOriginal('status'),
                $attempt->earned_points, $attempt->normalized_score]);
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
        $this->fail('The second review save did not wait on the recipient lock: '.json_encode($activity));
    }

    private function path(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's09_be_006_race_');
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
        $this->fail('The review worker did not reach its barrier.');
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

use App\Actions\Teacher\ReviewTeacherSubmission;
use App\Models\AnswerTextValue;
use App\Models\AttemptAnswer;
use App\Models\GroupTeacherMembership;
use App\Models\User;
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
    throw new LogicException('Review race workers require the isolated PostgreSQL testing database.');
}
Carbon::setTestNow(Carbon::parse('2026-09-30 10:00:00 UTC'));
$mode = $argv[2];

if ($mode === 'setup') {
    $fixture = new class
    {
        use BuildsStudentHomeworkAnswerContext;

        public function create(): array
        {
            [$student, $homework, $attempt] = $this->answerContext();
            $teacher = $homework->assessment->teacher;
            GroupTeacherMembership::factory()->create([
                'institution_id' => $teacher->institution_id, 'group_id' => $homework->assessment->topic->group_id,
                'teacher_id' => $teacher->id, 'assigned_by_user_id' => $teacher->id,
            ]);
            $written = $this->answerQuestion($homework, 'open_written');
            $written->update(['points' => '4.000000']);
            $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $written->id]);
            AnswerTextValue::factory()->create(['answer_id' => $answer->id, 'text_value' => 'DNS resolves names.']);
            DB::table('attempt_answers')->where('id', $answer->id)->update(['checking_status' => 'waiting_for_teacher_review']);
            DB::table('assessment_attempts')->where('id', $attempt->id)->update([
                'status' => 'waiting_for_teacher_review', 'submitted_at' => now(), 'finalized_at' => now(),
                'locked_at' => now(), 'finalization_reason' => 'student_submit', 'possible_points' => '4.000000',
            ]);

            return ['institution' => $student->institution_id, 'teacher' => $teacher->id, 'attempt' => $attempt->id, 'answer' => $answer->id];
        }
    };
    echo json_encode($fixture->create(), JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    DB::transaction(function () use ($argv): void {
        foreach (['official_task_scores', 'answer_text_values', 'attempt_answers', 'assessment_attempts', 'questions',
            'assessment_students', 'homework_assignments', 'assessments', 'topics', 'group_student_memberships',
            'group_teacher_memberships', 'groups', 'institution_settings', 'users'] as $table) {
            DB::table($table)->where('institution_id', $argv[3])->delete();
        }
        DB::table('institutions')->where('id', $argv[3])->delete();
    });
    echo '{}';
    exit(0);
}

[$teacherId, $attemptId, $answerId, $points, $feedback, $readyPath, $releasePath] = array_slice($argv, 3, 7);
DB::statement("set lock_timeout = '10s'");
$pid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
if (isset($argv[10])) {
    file_put_contents($argv[10], (string) $pid);
}
$held = false;
DB::listen(function ($query) use (&$held, $readyPath, $releasePath, $pid): void {
    if ($held || $readyPath === '' || ! str_contains($query->sql, 'from "assessment_students"') || ! str_ends_with($query->sql, 'for update')) {
        return;
    }
    // Hold the recipient lock until the test has seen the second save wait on it.
    $held = true;
    file_put_contents($readyPath, json_encode(['pid' => $pid], JSON_THROW_ON_ERROR));
    $deadline = microtime(true) + 15;
    while (! file_exists($releasePath)) {
        if (microtime(true) > $deadline) {
            throw new RuntimeException('The review race was never released.');
        }
        usleep(5_000);
        clearstatcache(true, $releasePath);
    }
});
$detail = app(ReviewTeacherSubmission::class)(User::query()->findOrFail($teacherId), $attemptId,
    [['answer_id' => $answerId, 'awarded_points' => (int) $points, 'feedback' => $feedback]]);
echo json_encode(['status' => $detail->status->value], JSON_THROW_ON_ERROR);
PHP;
    }
}
