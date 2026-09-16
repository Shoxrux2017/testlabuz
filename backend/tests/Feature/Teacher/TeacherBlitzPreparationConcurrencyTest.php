<?php

namespace Tests\Feature\Teacher;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherBlitzPreparationConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_preparation_mutations_recheck_committed_lifecycle_without_partial_recipient_or_configuration_changes(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's08_be_002_blitz_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach ([
                ['schedule_archive', 'schedule', 'archive', 'ok', 'scheduled'],
                ['archive_schedule', 'archive', 'schedule', 'task_archived', 'archived'],
                ['update_archive', 'update', 'archive', 'ok', 'draft'],
                ['archive_update', 'archive', 'update', 'task_archived', 'archived'],
            ] as [$scenario, $firstOperation, $secondOperation, $secondOutcome, $firstStatus]) {
                $result = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $this->assertSame('ok', $result['first']['outcome'], $scenario.' first outcome');
                $this->assertSame($firstStatus, $result['first']['status'], $scenario.' first locked state');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second outcome');
                $final = $result['second'];
                $this->assertSame('archived', $final['status'], $scenario.' final status');
                $this->assertNotNull($final['archived_at']);
                $this->assertTrue($final['archive_after_creation']);
                $this->assertSame($final['archived_at'], $final['blitz_updated_at']);
                $this->assertSame($final['blitz_updated_at'], $final['assessment_updated_at']);
                $this->assertSame($scenario === 'schedule_archive' ? '2026-09-16T09:00:00+00:00' : null, $final['scheduled_at']);

                foreach (['timer_start_mode_snapshot', 'activated_at', 'synchronized_ends_at', 'closed_at', 'activated_by_user_id'] as $field) {
                    $this->assertNull($final[$field], $scenario.' '.$field);
                }

                $updated = $scenario === 'update_archive';
                $this->assertSame($updated ? 900 : 600, $final['duration_seconds'], $scenario.' duration');
                $this->assertSame($updated ? 'Updated Blitz' : 'Original Blitz', $final['title'], $scenario.' title');
                $this->assertSame([$ids['students'][$scenario][$updated ? 1 : 0]], $final['student_ids'], $scenario.' recipient set');
                $this->assertSame(['direct'], $final['assignment_sources']);
                $this->assertSame($ids['questions'][$scenario], $final['question_id']);
                $this->assertSame('Original question', $final['question_prompt']);
                $this->assertTrue($final['correct_value']);
                $this->assertSame(1, $final['question_count']);
                $this->assertSame(0, $final['attempt_count']);
                $this->assertSame('1.000000', $final['total_possible_points']);
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(string $workerPath, array $ids, string $scenario, string $firstOperation, string $secondOperation): array
    {
        $lockedPath = $this->unusedTempPath('s08_be_002_locked_');
        $releasePath = $this->unusedTempPath('s08_be_002_release_');
        $attemptPath = $this->unusedTempPath('s08_be_002_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
        $arguments = [$ids['teacher'], $ids['groups'][$scenario], $ids['assessments'][$scenario], $ids['students'][$scenario][1]];
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation,
            'hold', $lockedPath, $releasePath, $firstAttemptPath,
        ]);
        $second = null;

        try {
            $this->waitForFile($lockedPath, 'The first Blitz worker did not retain its mutation locks.');
            $second = $this->startWorker([
                $workerPath, base_path(), 'run', ...$arguments, $secondOperation,
                'normal', $lockedPath, $releasePath, $attemptPath,
            ]);
            $this->waitForFile($attemptPath, 'The competing Blitz worker did not start.');
            $this->waitForPostgresLock((int) file_get_contents($attemptPath), $scenario);
        } finally {
            file_put_contents($releasePath, 'release');
            try {
                $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
                $secondResult = $second === null ? null : json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
            } finally {
                foreach ([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath] as $path) {
                    if (file_exists($path)) {
                        unlink($path);
                    }
                }
            }
        }

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
            $activity = DB::selectOne('select wait_event_type, wait_event from pg_stat_activity where pid = ?', [$backendPid]);
            if ($activity !== null && $activity->wait_event_type === 'Lock') {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('Competing Blitz worker did not enter a PostgreSQL lock wait for '.$scenario.': '.json_encode($activity));
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

    private function workerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Teacher\ArchiveTeacherBlitz;
use App\Actions\Teacher\ScheduleTeacherBlitz;
use App\Actions\Teacher\UpdateTeacherBlitz;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
Carbon::setTestNow('2026-09-16 08:00:00 UTC');
CarbonImmutable::setTestNow('2026-09-16 08:00:00 UTC');

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'Blitz preparation concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent', 'blitz_timer_start_mode' => null]);
    $ids = ['institution' => $institution->id, 'teacher' => $teacher->id, 'groups' => [], 'assessments' => [], 'students' => [], 'questions' => []];

    foreach (['schedule_archive', 'archive_schedule', 'update_archive', 'archive_update'] as $scenario) {
        $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id, 'group_id' => $group->id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id,
        ]);
        $students = [];
        foreach (range(1, 2) as $index) {
            $student = User::factory()->student($institution)->create();
            GroupStudentMembership::factory()->create([
                'institution_id' => $institution->id, 'group_id' => $group->id,
                'student_id' => $student->id, 'assigned_by_user_id' => $admin->id,
            ]);
            $students[] = $student->id;
        }
        $topic = Topic::factory()->active()->create([
            'institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $teacher->id,
        ]);
        $assessment = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
            'assignment_mode' => AssessmentAssignmentMode::SelectedStudents,
            'title' => 'Original Blitz', 'total_possible_points' => '1.000000',
        ]);
        BlitzTask::factory()->draft()->create(['assessment_id' => $assessment->id, 'institution_id' => $institution->id, 'duration_seconds' => 600]);
        AssessmentStudent::factory()->create([
            'institution_id' => $institution->id, 'assessment_id' => $assessment->id,
            'student_id' => $students[0], 'assignment_source' => AssessmentAssignmentSource::Direct,
            'assigned_by_user_id' => $teacher->id,
        ]);
        $question = Question::factory()->trueFalse()->create([
            'institution_id' => $institution->id, 'assessment_id' => $assessment->id, 'prompt' => 'Original question',
        ]);
        QuestionTrueFalseAnswer::factory()->create(['question_id' => $question->id, 'institution_id' => $institution->id, 'correct_value' => true]);
        $ids['groups'][$scenario] = $group->id;
        $ids['assessments'][$scenario] = $assessment->id;
        $ids['students'][$scenario] = $students;
        $ids['questions'][$scenario] = $question->id;
    }
    echo json_encode($ids, JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    QuestionTrueFalseAnswer::query()->where('institution_id', $institutionId)->delete();
    Question::query()->where('institution_id', $institutionId)->delete();
    AssessmentStudent::query()->where('institution_id', $institutionId)->delete();
    BlitzTask::query()->where('institution_id', $institutionId)->delete();
    Assessment::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupStudentMembership::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$groupId = $argv[4];
$assessmentId = $argv[5];
$replacementStudentId = $argv[6];
$operation = $argv[7];
$hold = $argv[8] === 'hold';
$lockedPath = $argv[9];
$releasePath = $argv[10];
$attemptPath = $argv[11];
DB::statement("set lock_timeout = '10s'");
file_put_contents($attemptPath, (string) DB::selectOne('select pg_backend_pid() as pid')->pid);

if ($hold) {
    DB::beginTransaction();
    Group::query()->where('institution_id', $teacher->institution_id)->whereKey($groupId)->lockForUpdate()->firstOrFail();
}

$outcome = 'ok';
try {
    match ($operation) {
        'schedule' => app(ScheduleTeacherBlitz::class)($teacher, $assessmentId, ['scheduled_at' => '2026-09-16T14:00:00+05:00']),
        'archive' => app(ArchiveTeacherBlitz::class)($teacher, $assessmentId),
        'update' => app(UpdateTeacherBlitz::class)($teacher, $assessmentId, [
            'title' => 'Updated Blitz', 'duration_seconds' => 900, 'student_ids' => [$replacementStudentId],
        ]),
    };
} catch (TaskArchivedException) {
    $outcome = 'task_archived';
}

$assessment = Assessment::query()->findOrFail($assessmentId);
$blitz = BlitzTask::query()->findOrFail($assessmentId);
$question = Question::query()->where('assessment_id', $assessmentId)->sole();
$recipients = AssessmentStudent::query()->where('assessment_id', $assessmentId)->orderBy('student_id')->get();
$result = [
    'outcome' => $outcome, 'status' => $blitz->status->value,
    'scheduled_at' => $blitz->scheduled_at?->toIso8601String(),
    'timer_start_mode_snapshot' => $blitz->timer_start_mode_snapshot?->value,
    'activated_at' => $blitz->activated_at?->toIso8601String(),
    'synchronized_ends_at' => $blitz->synchronized_ends_at?->toIso8601String(),
    'closed_at' => $blitz->closed_at?->toIso8601String(),
    'archived_at' => $blitz->archived_at?->toIso8601String(),
    'activated_by_user_id' => $blitz->activated_by_user_id,
    'archive_after_creation' => $blitz->archived_at?->greaterThanOrEqualTo($blitz->created_at),
    'blitz_updated_at' => $blitz->updated_at->toIso8601String(),
    'assessment_updated_at' => $assessment->updated_at->toIso8601String(),
    'duration_seconds' => $blitz->duration_seconds, 'title' => $assessment->title,
    'total_possible_points' => $assessment->total_possible_points,
    'student_ids' => $recipients->pluck('student_id')->all(),
    'assignment_sources' => $recipients->map(fn ($recipient) => $recipient->assignment_source->value)->all(),
    'question_id' => $question->id, 'question_prompt' => $question->prompt,
    'correct_value' => $question->trueFalseAnswer->correct_value,
    'question_count' => Question::query()->where('assessment_id', $assessmentId)->count(),
    'attempt_count' => AssessmentAttempt::query()->where('assessment_id', $assessmentId)->count(),
];

if ($hold) {
    file_put_contents($lockedPath, 'locked');
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
    DB::rollBack();
    fwrite(STDERR, 'Timed out waiting for the observed PostgreSQL lock contention release.');
    exit(1);
}

echo json_encode($result, JSON_THROW_ON_ERROR);
PHP;
    }
}
