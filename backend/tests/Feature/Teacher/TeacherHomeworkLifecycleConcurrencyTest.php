<?php

namespace Tests\Feature\Teacher;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherHomeworkLifecycleConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_postgresql_locks_serialize_lifecycle_snapshot_and_topic_races(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's06_be_005_homework_lifecycle_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);
        $races = [
            ['same_activate', 'activate', 'activate', 'ok', 'ok'],
            ['same_close', 'close', 'close', 'ok', 'ok'],
            ['same_archive', 'archive', 'archive', 'ok', 'ok'],
            ['removal_activate', 'remove', 'activate', 'ok', 'assessment_not_assigned'],
            ['activate_removal', 'activate', 'remove', 'ok', 'ok'],
            ['activate_topic_close', 'activate', 'topic_close', 'ok', 'topic_has_open_assessments'],
            ['topic_archive_activate', 'topic_archive', 'activate', 'topic_has_open_assessments', 'topic_not_editable'],
        ];
        $results = [];

        try {
            foreach ($races as [$scenario, $firstOperation, $secondOperation, $firstOutcome, $secondOutcome]) {
                $result = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $this->assertSame($firstOutcome, $result['first']['outcome'], $scenario.' first');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second');
                $results[$scenario] = $result;
            }

            foreach ([
                'same_activate' => ['active', 'active'],
                'same_close' => ['active', 'closed'],
                'same_archive' => ['active', 'archived'],
                'removal_activate' => ['active', 'draft'],
                'activate_removal' => ['active', 'active'],
                'activate_topic_close' => ['active', 'active'],
                'topic_archive_activate' => ['closed', 'draft'],
            ] as $scenario => [$topicStatus, $homeworkStatus]) {
                $this->assertSame($topicStatus, $results[$scenario]['second']['topic_status'], $scenario.' topic');
                $this->assertSame($homeworkStatus, $results[$scenario]['second']['homework_status'], $scenario.' homework');
            }

            foreach ([
                'same_activate' => 'activated_at',
                'same_close' => 'closed_at',
                'same_archive' => 'archived_at',
            ] as $scenario => $timestamp) {
                $this->assertNotNull($results[$scenario]['first'][$timestamp]);
                $this->assertSame($results[$scenario]['first'][$timestamp], $results[$scenario]['second'][$timestamp]);
                $this->assertSame($results[$scenario]['first']['updated_at'], $results[$scenario]['second']['updated_at']);
            }

            $this->assertSame(1, $results['same_activate']['second']['recipient_count']);
            $this->assertSame(1, $results['activate_removal']['second']['recipient_count']);
            $this->assertFalse($results['activate_removal']['second']['membership_current']);
            $this->assertSame(1, $results['removal_activate']['second']['recipient_count']);
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
        $lockedPath = $this->unusedTempPath('s06_be_005_locked_');
        $releasePath = $this->unusedTempPath('s06_be_005_release_');
        $attemptPath = $this->unusedTempPath('s06_be_005_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
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
            'hold', $lockedPath, $releasePath, $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'The first lifecycle worker did not retain its Group lock.');
        $second = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation,
            'normal', $lockedPath, $releasePath, $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'The second lifecycle worker did not begin.');
        $secondBackendPid = (int) file_get_contents($attemptPath);

        try {
            $this->waitForPostgresLock($secondBackendPid, $scenario);
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath]);
            $this->fail($exception->getMessage()."\nFirst: {$firstOutput}\nSecond: {$secondOutput}");
        }

        file_put_contents($releasePath, 'release');
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath]);

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
use App\Actions\Teacher\ActivateTeacherHomework;
use App\Actions\Teacher\ArchiveTeacherHomework;
use App\Actions\Teacher\ArchiveTeacherTopic;
use App\Actions\Teacher\CloseTeacherHomework;
use App\Actions\Teacher\CloseTeacherTopic;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\HomeworkStatus;
use App\Exceptions\Teacher\AssessmentNotAssignedException;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\TopicHasOpenAssessmentsException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\Topic;
use App\Models\User;
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
    $institution = Institution::factory()->create(['name' => 'S06 BE 005 lifecycle concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
    $groups = [];
    $topics = [];
    $assessments = [];
    $students = [];
    $scenarios = [
        'same_activate', 'same_close', 'same_archive', 'removal_activate',
        'activate_removal', 'activate_topic_close', 'topic_archive_activate',
    ];

    foreach ($scenarios as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
            'name' => 'Homework lifecycle race '.$scenario,
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
        $topicFactory = $scenario === 'topic_archive_activate'
            ? Topic::factory()->closed()
            : Topic::factory()->active();
        $topic = $topicFactory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $selected = in_array($scenario, ['removal_activate', 'activate_removal'], true);
        $assessment = Assessment::factory()->homework()->create([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'teacher_id' => $teacher->id,
            'assignment_mode' => $selected
                ? AssessmentAssignmentMode::SelectedStudents
                : AssessmentAssignmentMode::Group,
            'total_possible_points' => '1.000000',
        ]);
        $homeworkFactory = $scenario === 'same_close'
            ? HomeworkAssignment::factory()->active()
            : HomeworkAssignment::factory()->draft();
        $homeworkFactory->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
        ]);
        Question::factory()->openWritten()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
        ]);

        if ($selected) {
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
    Question::query()->where('institution_id', $institutionId)->delete();
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
    Group::query()->where('institution_id', $teacher->institution_id)->whereKey($groupId)->lockForUpdate()->firstOrFail();
}

$outcome = 'ok';

try {
    match ($operation) {
        'activate' => app(ActivateTeacherHomework::class)($teacher, $assessmentId),
        'close' => app(CloseTeacherHomework::class)($teacher, $assessmentId),
        'archive' => app(ArchiveTeacherHomework::class)($teacher, $assessmentId),
        'remove' => app(RemoveStudentFromInstitutionGroup::class)($admin, $groupId, $studentId),
        'topic_close' => app(CloseTeacherTopic::class)($teacher, $topicId),
        'topic_archive' => app(ArchiveTeacherTopic::class)($teacher, $topicId),
    };
} catch (AssessmentNotAssignedException) {
    $outcome = 'assessment_not_assigned';
} catch (TopicHasOpenAssessmentsException) {
    $outcome = 'topic_has_open_assessments';
} catch (TopicNotEditableException) {
    $outcome = 'topic_not_editable';
} catch (BusinessConflictException) {
    $outcome = 'business_conflict';
}

if ($hold) {
    file_put_contents($lockedPath, 'locked');
    $deadline = microtime(true) + 15;
    while (! file_exists($releasePath) && microtime(true) < $deadline) {
        usleep(5_000);
    }
    if (! file_exists($releasePath)) {
        DB::rollBack();
        fwrite(STDERR, 'Timed out waiting for deterministic lifecycle race release.');
        exit(1);
    }
    DB::commit();
}

$topic = Topic::query()->findOrFail($topicId);
$homework = HomeworkAssignment::query()->findOrFail($assessmentId);
echo json_encode([
    'outcome' => $outcome,
    'topic_status' => $topic->status->value,
    'homework_status' => $homework->status->value,
    'activated_at' => $homework->activated_at?->toIso8601String(),
    'closed_at' => $homework->closed_at?->toIso8601String(),
    'archived_at' => $homework->archived_at?->toIso8601String(),
    'updated_at' => $homework->updated_at?->toIso8601String(),
    'recipient_count' => AssessmentStudent::query()->where('assessment_id', $assessmentId)->count(),
    'membership_current' => GroupStudentMembership::query()
        ->where('group_id', $groupId)
        ->where('student_id', $studentId)
        ->whereNull('ended_at')
        ->exists(),
], JSON_THROW_ON_ERROR);
PHP;
    }
}
