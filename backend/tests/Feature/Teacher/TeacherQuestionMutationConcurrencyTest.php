<?php

namespace Tests\Feature\Teacher;

use App\Models\AssessmentAttempt;
use App\Models\Question;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherQuestionMutationConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_question_order_and_first_attempt_races_serialize_on_postgresql_locks(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's06_be_004_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach ([
                ['reorder_first', 'reorder', 'add', 'ok', 'ok'],
                ['add_first', 'add', 'reorder', 'ok', 'validation_failed'],
                ['mutation_first', 'mutate', 'attempt', 'ok', 'ok'],
                ['attempt_first', 'attempt', 'mutate', 'ok', 'business_conflict'],
            ] as [$scenario, $firstOperation, $secondOperation, $firstOutcome, $secondOutcome]) {
                $result = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $this->assertSame($firstOutcome, $result['first']['outcome'], $scenario.' first');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second');

                $questions = Question::query()
                    ->where('assessment_id', $ids['assessments'][$scenario])
                    ->orderBy('position')
                    ->get(['prompt', 'position']);
                $this->assertCount(
                    in_array($scenario, ['reorder_first', 'add_first'], true) ? 3 : 2,
                    $questions,
                    $scenario.' question count',
                );
                $this->assertSame(range(1, $questions->count()), $questions->pluck('position')->all(), $scenario);
                $this->assertSame(
                    in_array($scenario, ['mutation_first', 'attempt_first'], true) ? 1 : 0,
                    AssessmentAttempt::query()
                        ->where('assessment_id', $ids['assessments'][$scenario])
                        ->count(),
                    $scenario.' attempt count',
                );

                if ($scenario === 'mutation_first') {
                    $this->assertContains('Concurrent edit', $questions->pluck('prompt')->all());
                }

                if ($scenario === 'attempt_first') {
                    $this->assertNotContains('Concurrent edit', $questions->pluck('prompt')->all());
                }
            }
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
        $lockedPath = $this->unusedTempPath('s06_be_004_locked_');
        $releasePath = $this->unusedTempPath('s06_be_004_release_');
        $attemptPath = $this->unusedTempPath('s06_be_004_attempt_');
        $arguments = [
            $ids['teacher'],
            $ids['assessments'][$scenario],
            $ids['students'][$scenario],
            implode(',', $ids['questions'][$scenario]),
        ];
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation,
            'hold', $lockedPath, $releasePath, $attemptPath.'.first',
        ]);
        $this->waitForFile($lockedPath, 'The first Question worker did not retain its locks.');
        $second = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation,
            'normal', $lockedPath, $releasePath, $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'The second Question worker did not start.');
        $secondBackendPid = (int) file_get_contents($attemptPath);

        try {
            $this->waitForPostgresLock($secondBackendPid, $scenario);
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $attemptPath.'.first']);
            $this->fail($exception->getMessage()."\nFirst: {$firstOutput}\nSecond: {$secondOutput}");
        }

        file_put_contents($releasePath, 'release');
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $attemptPath.'.first']);

        return ['first' => $firstResult, 'second' => $secondResult];
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

    private function waitForPostgresLock(int $backendPid, string $scenario): void
    {
        $deadline = microtime(true) + 10;
        $activity = null;

        do {
            DB::select('select pg_stat_clear_snapshot()');
            $activity = DB::selectOne(
                'select wait_event_type, wait_event from pg_stat_activity where pid = ?',
                [$backendPid],
            );
            if ($activity !== null && $activity->wait_event_type === 'Lock') {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('Second worker never entered a PostgreSQL lock wait for '.$scenario.'. Activity: '.json_encode($activity));
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
        $this->assertSame(0, $exitCode, $stderr."\nSTDOUT: {$stdout}");

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

    private function workerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Teacher\AddTeacherAssessmentQuestion;
use App\Actions\Teacher\ReorderTeacherAssessmentQuestions;
use App\Actions\Teacher\UpdateTeacherQuestion;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S06 BE 004 concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $student = User::factory()->student($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
    $assessments = [];
    $students = [];
    $questions = [];

    foreach (['reorder_first', 'add_first', 'mutation_first', 'attempt_first'] as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
            'name' => 'Question race '.$scenario,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $topic = Topic::factory()->create([
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
        ]);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct,
            'assigned_by_user_id' => $teacher->id,
        ]);
        $questionIds = [];

        foreach ([1, 2] as $position) {
            $questionIds[] = app(QuestionConfigurationWriter::class)->create($assessment, [
                'type' => 'true_false',
                'prompt' => 'Question '.$position,
                'instructions' => null,
                'points' => 1,
                'position' => $position,
                'checking_mode' => 'automatic',
                'configuration' => ['correct_value' => true],
            ])->id;
        }

        $assessments[$scenario] = $assessment->id;
        $students[$scenario] = $student->id;
        $questions[$scenario] = $questionIds;
    }

    echo json_encode([
        'institution' => $institution->id,
        'teacher' => $teacher->id,
        'assessments' => $assessments,
        'students' => $students,
        'questions' => $questions,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    AssessmentAttempt::query()->where('institution_id', $institutionId)->delete();
    QuestionTrueFalseAnswer::query()->where('institution_id', $institutionId)->delete();
    Question::query()->where('institution_id', $institutionId)->delete();
    AssessmentStudent::query()->where('institution_id', $institutionId)->delete();
    HomeworkAssignment::query()->where('institution_id', $institutionId)->delete();
    Assessment::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$assessmentId = $argv[4];
$studentId = $argv[5];
$questionIds = explode(',', $argv[6]);
$operation = $argv[7];
$hold = $argv[8] === 'hold';
$lockedPath = $argv[9];
$releasePath = $argv[10];
$attemptPath = $argv[11];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);

if ($hold) {
    DB::beginTransaction();
}

$outcome = 'ok';

try {
    match ($operation) {
        'reorder' => app(ReorderTeacherAssessmentQuestions::class)($teacher, $assessmentId, array_reverse($questionIds)),
        'add' => app(AddTeacherAssessmentQuestion::class)($teacher, $assessmentId, [
            'type' => 'true_false',
            'prompt' => 'Concurrent add',
            'instructions' => null,
            'points' => 1,
            'position' => 2,
            'checking_mode' => 'automatic',
            'configuration' => ['correct_value' => false],
        ]),
        'mutate' => app(UpdateTeacherQuestion::class)($teacher, $questionIds[0], ['prompt' => 'Concurrent edit']),
        'attempt' => (function () use ($teacher, $assessmentId, $studentId): void {
            $assessment = Assessment::query()
                ->where('institution_id', $teacher->institution_id)
                ->whereKey($assessmentId)
                ->lockForUpdate()
                ->firstOrFail();
            $recipient = AssessmentStudent::query()
                ->where('assessment_id', $assessmentId)
                ->where('student_id', $studentId)
                ->firstOrFail();
            AssessmentAttempt::factory()->create([
                'institution_id' => $teacher->institution_id,
                'assessment_id' => $assessmentId,
                'assessment_student_id' => $recipient->id,
                'student_id' => $studentId,
                'possible_points' => $assessment->total_possible_points,
            ]);
        })(),
    };
} catch (BusinessConflictException) {
    $outcome = 'business_conflict';
} catch (ValidationException) {
    $outcome = 'validation_failed';
}

if ($hold) {
    file_put_contents($lockedPath, 'locked');
    $deadline = microtime(true) + 15;
    while (! file_exists($releasePath) && microtime(true) < $deadline) {
        usleep(5_000);
    }
    if (! file_exists($releasePath)) {
        DB::rollBack();
        fwrite(STDERR, 'Timed out waiting for deterministic race release.');
        exit(1);
    }
    DB::commit();
}

echo json_encode(['outcome' => $outcome], JSON_THROW_ON_ERROR);
PHP;
    }
}
