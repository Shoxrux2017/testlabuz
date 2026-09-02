<?php

namespace Tests\Feature\Teacher;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherHomeworkConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_first_attempt_and_membership_loss_serialize_with_fairness_relevant_updates(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's06_be_003_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach ([
                ['edit_first', 'edit', 'attempt', 'ok', 'ok'],
                ['attempt_first', 'attempt', 'edit', 'ok', 'business_conflict'],
                ['selection_first', 'select', 'remove', 'ok', 'ok'],
                ['removal_first', 'remove', 'select', 'ok', 'validation_failed'],
            ] as [$scenario, $firstOperation, $secondOperation, $firstOutcome, $secondOutcome]) {
                $result = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $this->assertSame($firstOutcome, $result['first']['outcome'], $scenario.' first');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second');
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
        $lockedPath = $this->unusedTempPath('s06_be_003_locked_');
        $releasePath = $this->unusedTempPath('s06_be_003_release_');
        $attemptPath = $this->unusedTempPath('s06_be_003_attempt_');
        $arguments = [
            $ids['teacher'],
            $ids['admin'],
            $ids['groups'][$scenario],
            $ids['topics'][$scenario],
            $ids['assessments'][$scenario],
            $ids['students'][$scenario],
        ];

        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation,
            'hold', $lockedPath, $releasePath, $attemptPath.'.first',
        ]);
        $this->waitForFile($lockedPath, 'The first Homework worker did not retain its locks.');
        $second = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation,
            'normal', $lockedPath, $releasePath, $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'The second Homework worker did not start.');
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

use App\Actions\Institution\RemoveStudentFromInstitutionGroup;
use App\Actions\Teacher\UpdateTeacherHomework;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\User;
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
    $institution = Institution::factory()->create(['name' => 'S06 BE 003 concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
    $groups = [];
    $topics = [];
    $assessments = [];
    $students = [];

    foreach (['edit_first', 'attempt_first', 'selection_first', 'removal_first'] as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
            'name' => 'Race '.$scenario,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $student = User::factory()->student($institution)->create();
        GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $student->id,
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
            'assignment_mode' => str_contains($scenario, 'first') && str_contains($scenario, 'attempt')
                ? AssessmentAssignmentMode::SelectedStudents
                : AssessmentAssignmentMode::Group,
        ]);
        HomeworkAssignment::factory()->active()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
        ]);

        if (str_contains($scenario, 'attempt')) {
            AssessmentStudent::factory()->create([
                'institution_id' => $institution->id,
                'assessment_id' => $assessment->id,
                'student_id' => $student->id,
                'assignment_source' => AssessmentAssignmentSource::Direct,
                'assigned_by_user_id' => $teacher->id,
            ]);
        }

        $groups[$scenario] = $group->id;
        $topics[$scenario] = $topic->id;
        $assessments[$scenario] = $assessment->id;
        $students[$scenario] = $student->id;
    }

    echo json_encode([
        'institution' => $institution->id,
        'teacher' => $teacher->id,
        'admin' => $admin->id,
        'groups' => $groups,
        'topics' => $topics,
        'assessments' => $assessments,
        'students' => $students,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    AssessmentAttempt::query()->where('institution_id', $institutionId)->delete();
    AssessmentStudent::query()->where('institution_id', $institutionId)->delete();
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

$teacher = User::query()->findOrFail($argv[3]);
$admin = User::query()->findOrFail($argv[4]);
$groupId = $argv[5];
$topicId = $argv[6];
$assessmentId = $argv[7];
$studentId = $argv[8];
$operation = $argv[9];
$hold = $argv[10] === 'hold';
$lockedPath = $argv[11];
$releasePath = $argv[12];
$attemptPath = $argv[13];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);

if ($hold) {
    DB::beginTransaction();
}

$outcome = 'ok';

try {
    match ($operation) {
        'edit' => app(UpdateTeacherHomework::class)($teacher, $assessmentId, [
            'deadline_at' => '2026-09-10T18:00:00+05:00',
        ]),
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
        'select' => app(UpdateTeacherHomework::class)($teacher, $assessmentId, [
            'assignment_mode' => 'selected_students',
            'student_ids' => [$studentId],
        ]),
        'remove' => app(RemoveStudentFromInstitutionGroup::class)($admin, $groupId, $studentId),
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
