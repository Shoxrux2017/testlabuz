<?php

namespace Tests\Feature\Teacher;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherTopicResultPairConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_result_pair_designation_activation_replacement_and_first_activity_are_serialized(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's06_be_006_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            $initial = $this->runRace(
                $workerPath,
                $ids['scenarios']['initial'],
                'set',
                $ids['scenarios']['initial']['a'],
                'set',
                $ids['scenarios']['initial']['b'],
            );
            $this->assertSame('ok', $initial['first']['outcome']);
            $this->assertSame('ok', $initial['second']['outcome']);
            $this->assertScenarioState($workerPath, $ids['scenarios']['initial'], [
                'pair_count' => 1,
                'homework_id' => $ids['scenarios']['initial']['b'],
                'cohort_snapshotted' => false,
                'locked' => false,
            ]);

            $replacement = $this->runRace(
                $workerPath,
                $ids['scenarios']['replacement'],
                'set',
                $ids['scenarios']['replacement']['b'],
                'set',
                $ids['scenarios']['replacement']['c'],
            );
            $this->assertSame('ok', $replacement['first']['outcome']);
            $this->assertSame('ok', $replacement['second']['outcome']);
            $this->assertScenarioState($workerPath, $ids['scenarios']['replacement'], [
                'pair_count' => 1,
                'homework_id' => $ids['scenarios']['replacement']['c'],
                'cohort_snapshotted' => false,
                'locked' => false,
            ]);

            $designationActivation = $this->runRace(
                $workerPath,
                $ids['scenarios']['designation_activation'],
                'set',
                $ids['scenarios']['designation_activation']['a'],
                'activate',
                $ids['scenarios']['designation_activation']['a'],
            );
            $this->assertSame('ok', $designationActivation['first']['outcome']);
            $this->assertSame('ok', $designationActivation['second']['outcome']);
            $this->assertScenarioState($workerPath, $ids['scenarios']['designation_activation'], [
                'pair_count' => 1,
                'homework_id' => $ids['scenarios']['designation_activation']['a'],
                'cohort_snapshotted' => true,
                'locked' => false,
                'recipients_a' => 2,
            ]);

            $attemptReplacement = $this->runRace(
                $workerPath,
                $ids['scenarios']['attempt_replacement'],
                'attempt',
                $ids['scenarios']['attempt_replacement']['a'],
                'set',
                $ids['scenarios']['attempt_replacement']['b'],
            );
            $this->assertSame('ok', $attemptReplacement['first']['outcome']);
            $this->assertSame('result_pair_locked', $attemptReplacement['second']['outcome']);
            $this->assertScenarioState($workerPath, $ids['scenarios']['attempt_replacement'], [
                'pair_count' => 1,
                'homework_id' => $ids['scenarios']['attempt_replacement']['a'],
                'cohort_snapshotted' => true,
                'locked' => true,
                'attempts_a' => 1,
            ]);

            $activationReplacement = $this->runRace(
                $workerPath,
                $ids['scenarios']['activation_replacement'],
                'activate',
                $ids['scenarios']['activation_replacement']['a'],
                'set',
                $ids['scenarios']['activation_replacement']['b'],
            );
            $this->assertSame('ok', $activationReplacement['first']['outcome']);
            $this->assertSame('ok', $activationReplacement['second']['outcome']);
            $this->assertScenarioState($workerPath, $ids['scenarios']['activation_replacement'], [
                'pair_count' => 1,
                'homework_id' => $ids['scenarios']['activation_replacement']['b'],
                'cohort_snapshotted' => false,
                'locked' => false,
                'recipients_a' => 2,
                'recipients_b' => 0,
            ]);
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /**
     * @param  array<string, string>  $scenario
     * @return array{first: array<string, mixed>, second: array<string, mixed>}
     */
    private function runRace(
        string $workerPath,
        array $scenario,
        string $firstOperation,
        string $firstAssessment,
        string $secondOperation,
        string $secondAssessment,
    ): array {
        $lockedPath = $this->unusedTempPath('s06_be_006_locked_');
        $releasePath = $this->unusedTempPath('s06_be_006_release_');
        $attemptPath = $this->unusedTempPath('s06_be_006_attempt_');
        $baseArguments = [$scenario['teacher'], $scenario['topic']];
        $first = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            ...$baseArguments,
            $firstOperation,
            $firstAssessment,
            'hold',
            $lockedPath,
            $releasePath,
            $attemptPath.'.first',
        ]);
        $this->waitForFile($lockedPath, 'The first result-pair worker did not retain its locks.');
        $second = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            ...$baseArguments,
            $secondOperation,
            $secondAssessment,
            'normal',
            $lockedPath,
            $releasePath,
            $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'The second result-pair worker did not start.');
        $secondBackendPid = (int) file_get_contents($attemptPath);

        try {
            $this->waitForPostgresLock($secondBackendPid, $scenario['topic']);
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

    /** @param array<string, mixed> $expected */
    private function assertScenarioState(string $workerPath, array $scenario, array $expected): void
    {
        $state = json_decode($this->runWorker([
            $workerPath,
            base_path(),
            'inspect',
            $scenario['topic'],
            $scenario['a'],
            $scenario['b'],
        ]), true, flags: JSON_THROW_ON_ERROR);

        foreach ($expected as $key => $value) {
            $this->assertSame($value, $state[$key], $key);
        }
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

    private function waitForPostgresLock(int $backendPid, string $topicId): void
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

        $this->fail('Second worker never entered a PostgreSQL lock wait for Topic '.$topicId.'. Activity: '.json_encode($activity));
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

use App\Actions\Teacher\ActivateTeacherHomework;
use App\Actions\Teacher\SetTeacherTopicResultPair;
use App\Enums\AssessmentAssignmentSource;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S06 BE 006 concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
    $scenarios = [];

    foreach (['initial', 'replacement', 'designation_activation', 'attempt_replacement', 'activation_replacement'] as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $students = [];

        foreach (range(1, 2) as $index) {
            $student = User::factory()->student($institution)->create();
            GroupStudentMembership::factory()->create([
                'institution_id' => $institution->id,
                'group_id' => $group->id,
                'student_id' => $student->id,
                'assigned_by_user_id' => $admin->id,
            ]);
            $students[] = $student;
        }

        $topic = Topic::factory()->active()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $assessments = [];

        foreach (['a', 'b', 'c'] as $label) {
            $assessment = Assessment::factory()->homework()->groupAssignment()->create([
                'institution_id' => $institution->id,
                'teacher_id' => $teacher->id,
                'topic_id' => $topic->id,
            ]);
            $homeworkFactory = $scenario === 'attempt_replacement' && $label === 'a'
                ? HomeworkAssignment::factory()->active()
                : HomeworkAssignment::factory()->draft();
            $homeworkFactory->create([
                'assessment_id' => $assessment->id,
                'institution_id' => $institution->id,
            ]);
            $assessments[$label] = $assessment;
        }

        if (in_array($scenario, ['designation_activation', 'activation_replacement'], true)) {
            app(QuestionConfigurationWriter::class)->create($assessments['a'], [
                'type' => 'true_false',
                'prompt' => 'Concurrency question?',
                'instructions' => null,
                'points' => 1,
                'position' => 1,
                'checking_mode' => 'automatic',
                'configuration' => ['correct_value' => true],
            ]);
        }

        if ($scenario === 'replacement' || $scenario === 'activation_replacement') {
            TopicResultPair::factory()->create([
                'institution_id' => $institution->id,
                'topic_id' => $topic->id,
                'homework_assessment_id' => $assessments['a']->id,
                'designated_by_user_id' => $teacher->id,
            ]);
        }

        if ($scenario === 'attempt_replacement') {
            $recipient = AssessmentStudent::factory()->create([
                'institution_id' => $institution->id,
                'assessment_id' => $assessments['a']->id,
                'student_id' => $students[0]->id,
                'assignment_source' => AssessmentAssignmentSource::Group,
                'assigned_by_user_id' => $teacher->id,
            ]);
            TopicResultPair::factory()->create([
                'institution_id' => $institution->id,
                'topic_id' => $topic->id,
                'homework_assessment_id' => $assessments['a']->id,
                'designated_by_user_id' => $teacher->id,
                'designated_at' => now()->subMinute(),
                'cohort_snapshotted_at' => now(),
            ]);
        }

        $scenarios[$scenario] = [
            'teacher' => $teacher->id,
            'topic' => $topic->id,
            'a' => $assessments['a']->id,
            'b' => $assessments['b']->id,
            'c' => $assessments['c']->id,
        ];
    }

    echo json_encode([
        'institution' => $institution->id,
        'scenarios' => $scenarios,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    AssessmentAttempt::query()->where('institution_id', $institutionId)->delete();
    TopicResultPair::query()->where('institution_id', $institutionId)->delete();
    AssessmentStudent::query()->where('institution_id', $institutionId)->delete();
    DB::table('question_true_false_answers')->where('institution_id', $institutionId)->delete();
    Question::query()->where('institution_id', $institutionId)->delete();
    HomeworkAssignment::query()->where('institution_id', $institutionId)->delete();
    Assessment::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupStudentMembership::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

if ($mode === 'inspect') {
    $topicId = $argv[3];
    $assessmentA = $argv[4];
    $assessmentB = $argv[5];
    $pair = TopicResultPair::query()->where('topic_id', $topicId)->first();
    echo json_encode([
        'pair_count' => TopicResultPair::query()->where('topic_id', $topicId)->count(),
        'homework_id' => $pair?->homework_assessment_id,
        'cohort_snapshotted' => $pair?->cohort_snapshotted_at !== null,
        'locked' => $pair?->locked_at !== null,
        'recipients_a' => AssessmentStudent::query()->where('assessment_id', $assessmentA)->count(),
        'recipients_b' => AssessmentStudent::query()->where('assessment_id', $assessmentB)->count(),
        'attempts_a' => AssessmentAttempt::query()->where('assessment_id', $assessmentA)->count(),
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$topicId = $argv[4];
$operation = $argv[5];
$assessmentId = $argv[6];
$hold = $argv[7] === 'hold';
$lockedPath = $argv[8];
$releasePath = $argv[9];
$attemptPath = $argv[10];
$backendPid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $backendPid);

try {
    DB::transaction(function () use (
        $teacher,
        $topicId,
        $operation,
        $assessmentId,
        $hold,
        $lockedPath,
        $releasePath,
    ): void {
        if ($operation === 'set') {
            app(SetTeacherTopicResultPair::class)($teacher, $topicId, $assessmentId);
        } elseif ($operation === 'activate') {
            app(ActivateTeacherHomework::class)($teacher, $assessmentId);
        } elseif ($operation === 'attempt') {
            $assessment = Assessment::query()->whereKey($assessmentId)->lockForUpdate()->firstOrFail();
            $pair = TopicResultPair::query()
                ->where('topic_id', $topicId)
                ->lockForUpdate()
                ->firstOrFail();
            $recipient = AssessmentStudent::query()
                ->where('assessment_id', $assessment->id)
                ->orderBy('id')
                ->lockForUpdate()
                ->firstOrFail();
            $startedAt = now();

            if ($pair->homework_assessment_id !== $assessment->id || $pair->cohort_snapshotted_at === null) {
                throw new RuntimeException('The fixture official Homework is inconsistent.');
            }

            if ($pair->locked_at === null) {
                $pair->locked_at = $startedAt;
                $pair->updated_at = $startedAt;
                $pair->save();
            }

            AssessmentAttempt::factory()->create([
                'institution_id' => $assessment->institution_id,
                'assessment_id' => $assessment->id,
                'assessment_student_id' => $recipient->id,
                'student_id' => $recipient->student_id,
                'started_at' => $startedAt,
                'possible_points' => '1.000000',
            ]);
        } else {
            throw new RuntimeException('Unknown operation.');
        }

        if ($hold) {
            file_put_contents($lockedPath, 'locked');
            $deadline = microtime(true) + 15;

            do {
                clearstatcache(true, $releasePath);

                if (file_exists($releasePath)) {
                    return;
                }

                usleep(5_000);
            } while (microtime(true) < $deadline);

            throw new RuntimeException('Timed out waiting for the race release signal.');
        }
    });

    echo json_encode(['outcome' => 'ok'], JSON_THROW_ON_ERROR);
} catch (ResultPairLockedException) {
    echo json_encode(['outcome' => 'result_pair_locked'], JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    echo json_encode([
        'outcome' => 'unexpected',
        'exception' => $exception::class,
        'message' => $exception->getMessage(),
    ], JSON_THROW_ON_ERROR);
}
PHP;
    }
}
