<?php

namespace Tests\Feature\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class StudentHomeworkAnswerConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_same_attempt_multi_row_replacements_wait_on_the_attempt_and_commit_one_complete_payload(): void
    {
        $this->verifyRace(sameAttempt: true);
    }

    public function test_different_students_can_hold_independent_attempt_locks_on_the_same_homework_and_question(): void
    {
        $this->verifyRace(sameAttempt: false);
    }

    private function verifyRace(bool $sameAttempt): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's07_be_005_answer_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            $attemptsBefore = AssessmentAttempt::query()->where('assessment_id', $ids['assessment'])
                ->orderBy('id')->get()->map->getAttributes()->all();
            $results = $this->runRace($workerPath, $ids, $sameAttempt);

            foreach ($results as $worker => $result) {
                $this->assertSame(200, $result['status'], json_encode($result['body']));
                $this->assertSame($ids['question'], $result['body']['data']['question_id']);
                $this->assertSame('multiple_choice', $result['body']['data']['type']);
                $this->assertSame($ids[$worker.'_options'], $result['body']['data']['answer']['selected_option_ids']);
                $this->assertSame([
                    ['table' => 'topics', 'mode' => 'share'],
                    ['table' => 'assessments', 'mode' => 'share'],
                    ['table' => 'homework_assignments', 'mode' => 'share'],
                    ['table' => 'assessment_attempts', 'mode' => 'update'],
                    ['table' => 'questions', 'mode' => 'share'],
                    ['table' => 'attempt_answers', 'mode' => 'update'],
                ], $result['locks']);
            }

            $this->assertPersistedAnswer(
                $ids['first_attempt'],
                $ids['first_answer'],
                $ids['question'],
                $sameAttempt ? $ids['second_options'] : $ids['first_options'],
            );
            $this->assertPersistedAnswer(
                $ids['second_attempt'],
                $ids['second_answer'],
                $ids['question'],
                $sameAttempt ? [$ids['initial_option']] : $ids['second_options'],
            );
            $this->assertSame($attemptsBefore, AssessmentAttempt::query()
                ->where('assessment_id', $ids['assessment'])->orderBy('id')->get()->map->getAttributes()->all());
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    private function assertPersistedAnswer(string $attemptId, string $answerId, string $questionId, array $optionIds): void
    {
        $answers = AttemptAnswer::query()->where('attempt_id', $attemptId)->where('question_id', $questionId)->get();
        $this->assertCount(1, $answers);
        $answer = $answers->sole();
        $this->assertSame($answerId, $answer->id);
        $this->assertSame('2026-09-09 09:00:00', $answer->created_at->format('Y-m-d H:i:s'));
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->checking_status);
        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
            $this->assertNull($answer->{$field}, $field);
        }

        $persistedOptionIds = DB::table('answer_choice_selections')->where('answer_id', $answerId)
            ->orderBy('option_id')->pluck('option_id')->all();
        sort($optionIds);
        $this->assertSame($optionIds, $persistedOptionIds);
        $this->assertSame(count($optionIds), count(array_unique($persistedOptionIds)));
        foreach (['answer_boolean_values', 'answer_text_values', 'answer_matching_pairs',
            'answer_ordering_items', 'answer_fill_blank_values', 'answer_files'] as $table) {
            $this->assertSame(0, DB::table($table)->where('answer_id', $answerId)->count(), $table);
        }
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(string $workerPath, array $ids, bool $sameAttempt): array
    {
        $firstLockedPath = $this->unusedTempPath('s07_be_005_first_locked_');
        $secondLockedPath = $this->unusedTempPath('s07_be_005_second_locked_');
        $releasePath = $this->unusedTempPath('s07_be_005_release_');
        $startedPath = $this->unusedTempPath('s07_be_005_started_');
        $first = $this->startWorker([
            $workerPath, base_path(), 'save', $ids['first_student'], $ids['first_attempt'], $ids['question'],
            json_encode(array_reverse($ids['first_options']), JSON_THROW_ON_ERROR), 'hold',
            $firstLockedPath, $releasePath, $startedPath.'.first', '2026-09-09 10:00:00 UTC',
        ]);
        $second = null;

        try {
            $this->waitForFile($firstLockedPath, 'The first save did not retain its locks after resolving its canonical answer.');
            $firstReady = json_decode(file_get_contents($firstLockedPath), true, flags: JSON_THROW_ON_ERROR);
            $this->assertSame(200, $firstReady['status'], json_encode($firstReady['body']));
            $second = $this->startWorker([
                $workerPath, base_path(), 'save',
                $ids[$sameAttempt ? 'first_student' : 'second_student'],
                $ids[$sameAttempt ? 'first_attempt' : 'second_attempt'], $ids['question'],
                json_encode(array_reverse($ids['second_options']), JSON_THROW_ON_ERROR), $sameAttempt ? 'normal' : 'hold',
                $secondLockedPath, $releasePath, $startedPath, '2026-09-09 10:01:00 UTC',
            ]);
            $this->waitForFile($startedPath, 'The second save worker did not begin.');

            if ($sameAttempt) {
                $this->waitForPostgresAttemptLock((int) file_get_contents($startedPath), $firstReady['pid']);
                $this->assertFileDoesNotExist($secondLockedPath);
            } else {
                $this->waitForFile($secondLockedPath, 'Different Students were serialized on their shared Homework or Question.');
                $secondReady = json_decode(file_get_contents($secondLockedPath), true, flags: JSON_THROW_ON_ERROR);
                $this->assertSame(200, $secondReady['status'], json_encode($secondReady['body']));
                $this->assertNotSame($firstReady['pid'], $secondReady['pid']);
                $this->assertFileDoesNotExist($releasePath);
                foreach ([$firstReady['pid'], $secondReady['pid']] as $pid) {
                    DB::select('select pg_stat_clear_snapshot()');
                    $activity = DB::selectOne('select state, cardinality(pg_blocking_pids(pid)) as blocker_count from pg_stat_activity where pid = ?', [$pid]);
                    $this->assertSame('idle in transaction', $activity->state);
                    $this->assertSame(0, $activity->blocker_count);
                }
            }
        } finally {
            file_put_contents($releasePath, 'release');
            try {
                $firstOutput = $this->finishWorker($first);
                $secondOutput = $second === null ? null : $this->finishWorker($second);
            } finally {
                foreach ([$firstLockedPath, $secondLockedPath, $releasePath, $startedPath, $startedPath.'.first'] as $path) {
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

    private function waitForPostgresAttemptLock(int $waitingPid, int $holdingPid): void
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
                $this->assertStringContainsString('from "assessment_attempts"', $activity->query);
                $this->assertStringContainsString('for update', $activity->query);

                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('The second replacement never waited on the first Attempt lock: '.json_encode($activity));
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

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\Group;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;

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
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
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
    $question = Question::factory()->multipleChoice()->create([
        'institution_id' => $institution->id, 'assessment_id' => $assessment->id, 'points' => '2.000000',
    ]);
    $options = [];
    for ($position = 1; $position <= 5; $position++) {
        $options[] = QuestionChoiceOption::factory()->create([
            'institution_id' => $institution->id, 'question_id' => $question->id,
            'position' => $position, 'is_correct' => $position <= 2,
        ])->id;
    }
    $ids = [
        'institution' => $institution->id, 'assessment' => $assessment->id, 'question' => $question->id,
        'first_options' => array_slice($options, 0, 2), 'second_options' => array_slice($options, 2, 2),
        'initial_option' => $options[4],
    ];
    foreach (['first', 'second'] as $name) {
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id, 'assessment_id' => $assessment->id, 'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct, 'assigned_by_user_id' => $teacher->id,
        ]);
        $attempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id, 'possible_points' => '2.000000',
        ]);
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        DB::table('answer_choice_selections')->insert([
            'institution_id' => $institution->id, 'answer_id' => $answer->id,
            'option_id' => $options[4], 'created_at' => now(),
        ]);
        $ids[$name.'_student'] = $student->id;
        $ids[$name.'_attempt'] = $attempt->id;
        $ids[$name.'_answer'] = $answer->id;
    }
    echo json_encode($ids, JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    DB::transaction(function () use ($institutionId): void {
        DB::table('answer_choice_selections')->where('institution_id', $institutionId)->delete();
        foreach ([AttemptAnswer::class, AssessmentAttempt::class, QuestionChoiceOption::class,
            Question::class, AssessmentStudent::class, HomeworkAssignment::class, Assessment::class,
            Topic::class, Group::class, InstitutionSetting::class, User::class] as $model) {
            $model::query()->where('institution_id', $institutionId)->delete();
        }
        Institution::query()->whereKey($institutionId)->delete();
    });
    echo '{}';
    exit(0);
}

[$studentId, $attemptId, $questionId, $selectedOptionJson, $hold, $lockedPath,
    $releasePath, $startedPath, $observedAt] = array_slice($argv, 3);
Carbon::setTestNow(Carbon::parse($observedAt));
DB::statement("set lock_timeout = '10s'");
$pid = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($startedPath, (string) $pid);
$locks = [];
DB::listen(function ($query) use (&$locks): void {
    if (preg_match('/from "(topics|assessments|homework_assignments|assessment_attempts|questions|attempt_answers)".* for (share|update)$/s', $query->sql, $matches)) {
        $locks[] = ['table' => $matches[1], 'mode' => $matches[2]];
    }
});
Sanctum::actingAs(User::query()->findOrFail($studentId));
$request = Request::create('/api/v1/student/attempts/'.$attemptId.'/answers/'.$questionId, 'PUT', [], [], [], [
    'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
], json_encode([
    'type' => 'multiple_choice', 'selected_option_ids' => json_decode($selectedOptionJson, true, flags: JSON_THROW_ON_ERROR),
], JSON_THROW_ON_ERROR));
$kernel = $app->make(HttpKernel::class);

DB::beginTransaction();
try {
    $response = $kernel->handle($request);
    $kernel->terminate($request, $response);
    if (DB::transactionLevel() !== 1) {
        throw new LogicException('Answer save must leave the enclosing transaction and its locks intact.');
    }
    $result = [
        'pid' => $pid, 'status' => $response->getStatusCode(),
        'body' => json_decode($response->getContent(), true, flags: JSON_THROW_ON_ERROR), 'locks' => $locks,
    ];
    file_put_contents($lockedPath, json_encode($result, JSON_THROW_ON_ERROR));
    if ($hold === 'hold') {
        $deadline = microtime(true) + 15;
        do {
            clearstatcache(true, $releasePath);
            if (file_exists($releasePath)) {
                DB::commit();
                echo json_encode($result, JSON_THROW_ON_ERROR);
                exit(0);
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);
        throw new RuntimeException('Timed out waiting for the deterministic answer-save race release.');
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
