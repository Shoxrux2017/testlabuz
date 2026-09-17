<?php

namespace Tests\Feature\Teacher;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherBlitzActivationConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_competing_activation_pair_question_and_settings_operations_serialize_on_committed_state(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's08_be_004_activation_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());

        try {
            foreach ([
                ['activate', 'activate'], ['activate', 'replace'], ['replace', 'activate'],
                ['activate', 'question'], ['question', 'activate'],
                ['activate', 'settings'], ['settings', 'activate'],
            ] as [$firstOperation, $secondOperation]) {
                $scenario = $firstOperation.'_then_'.$secondOperation;
                $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);
                try {
                    $result = $this->runRace($workerPath, $ids, $firstOperation, $secondOperation);
                    $first = $result['first'];
                    $final = $result['second'];
                    $this->assertSame('ok', $first['outcome'], $scenario);
                    $this->assertSame(match ($scenario) {
                        'activate_then_replace' => 'result_pair_locked',
                        'activate_then_question' => 'business_conflict',
                        default => 'ok',
                    }, $final['outcome'], $scenario);
                    $this->assertSame('active', $final['status'], $scenario);
                    $this->assertSame(0, $final['attempt_count'], $scenario);
                    $this->assertSame([$ids['student']], $final['recipient_student_ids'], $scenario);
                    $this->assertSame($ids['teacher'], $final['activated_by'], $scenario);
                    $this->assertNull($final['pair']['locked_at'], $scenario);
                    $this->assertSame($firstOperation === 'replace' ? $ids['candidate'] : $ids['assessment'], $final['pair']['blitz_assessment_id'], $scenario);

                    if ($firstOperation === 'replace') {
                        $this->assertNull($final['pair']['cohort_snapshotted_at'], $scenario.' activation must read the replaced official identity');
                    } else {
                        $this->assertSame($final['activated_at'], $final['pair']['cohort_snapshotted_at'], $scenario);
                    }

                    $expectedInstant = $firstOperation === 'activate'
                        ? '2026-09-17T09:00:00+00:00'
                        : ($firstOperation === 'settings' ? '2026-09-17T11:00:00+00:00' : '2026-09-17T10:00:00+00:00');
                    $this->assertSame($expectedInstant, $final['activated_at'], $scenario.' authoritative instant after lock waits');
                    $this->assertSame($firstOperation === 'settings' ? 'individual' : 'synchronized', $final['timer_mode'], $scenario);
                    $this->assertSame($firstOperation === 'settings' ? null : str_replace(':00:00+', ':10:00+', $expectedInstant), $final['synchronized_ends_at'], $scenario);
                    $this->assertSame(in_array('settings', [$firstOperation, $secondOperation], true) ? 'individual' : 'synchronized', $final['setting_mode'], $scenario);
                    $this->assertSame($firstOperation === 'question' ? '3.100002' : '2.000001', $final['total'], $scenario);
                    $this->assertSame($firstOperation === 'question' ? 'Committed before activation' : 'Original question', $final['question']['prompt'], $scenario);
                    $this->assertSame($first['question'], $final['question'], $scenario.' no question writes after activation');
                    $expectedRecords = $scenario === 'activate_then_activate' ? 2 : 1;
                    $this->assertCount($expectedRecords, $final['records'], $scenario);
                    foreach ($final['records'] as $record) {
                        $this->assertSame('blitz', $record['result_resource_type'], $scenario);
                        $this->assertSame($ids['assessment'], $record['result_resource_id'], $scenario);
                        $this->assertSame(200, $record['response_status'], $scenario);
                        $this->assertNotNull($record['completed_at'], $scenario);
                    }
                    if ($firstOperation === 'activate') {
                        $this->assertSame($first['activation_snapshot'], $final['activation_snapshot'], $scenario.' activation cannot restart or mutate its cohort');
                    }
                } finally {
                    $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
                }
            }
        } finally {
            unlink($workerPath);
        }
    }

    private function runRace(string $workerPath, array $ids, string $firstOperation, string $secondOperation): array
    {
        $lockedPath = $this->unusedTempPath('s08_be_004_activation_locked_');
        $releasePath = $this->unusedTempPath('s08_be_004_activation_release_');
        $attemptPath = $this->unusedTempPath('s08_be_004_activation_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
        $arguments = [$workerPath, base_path(), 'run', json_encode($ids, JSON_THROW_ON_ERROR)];
        $first = $this->startWorker([...$arguments, $firstOperation, 'hold', $lockedPath, $releasePath, $firstAttemptPath]);
        $second = null;

        try {
            $this->waitForFile($lockedPath, 'First activation worker did not retain its transaction locks.');
            $second = $this->startWorker([...$arguments, $secondOperation, 'normal', $lockedPath, $releasePath, $attemptPath]);
            $this->waitForFile($attemptPath, 'Competing activation worker did not start.');
            $this->waitForPostgresLock((int) file_get_contents($attemptPath), $firstOperation.'_then_'.$secondOperation);
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

        $this->fail('Activation worker did not enter PostgreSQL lock contention for '.$scenario.': '.json_encode($activity));
    }

    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open(array_merge([PHP_BINARY], $arguments), [
            0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w'],
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

use App\Actions\Institution\UpdateInstitutionAssessmentSettings;
use App\Actions\Teacher\ActivateTeacherBlitz;
use App\Actions\Teacher\SetTeacherTopicResultPair;
use App\Actions\Teacher\UpdateTeacherQuestion;
use App\Enums\BlitzTimerStartMode;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
Carbon::setTestNow('2026-09-17 08:00:00 UTC');
CarbonImmutable::setTestNow('2026-09-17 08:00:00 UTC');

if ($mode === 'setup') {
    $institution = Institution::factory()->create();
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $student = User::factory()->student($institution)->create();
    InstitutionSetting::factory()->configuredEducationalPolicy()->create(['institution_id' => $institution->id]);
    $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
    GroupTeacherMembership::factory()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id,
        'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id,
    ]);
    GroupStudentMembership::factory()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id,
        'student_id' => $student->id, 'assigned_by_user_id' => $admin->id,
    ]);
    $topic = Topic::factory()->active()->create([
        'institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $teacher->id,
    ]);
    $assessment = Assessment::factory()->blitz()->create([
        'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
    ]);
    BlitzTask::factory()->draft()->create(['assessment_id' => $assessment->id]);
    $question = app(QuestionConfigurationWriter::class)->create($assessment, [
        'type' => 'true_false', 'prompt' => 'Original question', 'instructions' => null,
        'points' => '2.000001', 'position' => 1, 'checking_mode' => 'automatic',
        'configuration' => ['correct_value' => true],
    ]);
    $candidate = Assessment::factory()->blitz()->create([
        'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
    ]);
    BlitzTask::factory()->draft()->create(['assessment_id' => $candidate->id]);
    $homework = Assessment::factory()->homework()->create([
        'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
    ]);
    HomeworkAssignment::factory()->draft()->create(['assessment_id' => $homework->id]);
    $pair = TopicResultPair::factory()->create([
        'institution_id' => $institution->id, 'topic_id' => $topic->id,
        'homework_assessment_id' => $homework->id, 'blitz_assessment_id' => $assessment->id,
        'designated_by_user_id' => $teacher->id,
    ]);
    echo json_encode([
        'institution' => $institution->id, 'teacher' => $teacher->id, 'admin' => $admin->id,
        'student' => $student->id, 'assessment' => $assessment->id, 'candidate' => $candidate->id,
        'topic' => $topic->id, 'homework' => $homework->id, 'pair' => $pair->id, 'question' => $question->id,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    foreach ([IdempotencyRecord::class, QuestionTrueFalseAnswer::class, Question::class,
        TopicResultPair::class, AssessmentStudent::class, BlitzTask::class, HomeworkAssignment::class,
        Assessment::class, Topic::class, GroupStudentMembership::class, GroupTeacherMembership::class,
        Group::class] as $model) {
        $model::query()->where('institution_id', $institutionId)->delete();
    }
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$ids = json_decode($argv[3], true, flags: JSON_THROW_ON_ERROR);
$operation = $argv[4];
$hold = $argv[5] === 'hold';
$lockedPath = $argv[6];
$releasePath = $argv[7];
$attemptPath = $argv[8];
$teacher = User::query()->findOrFail($ids['teacher']);
$operationTime = $hold ? '2026-09-17 09:00:00 UTC' : '2026-09-17 10:00:00 UTC';
Carbon::setTestNow($operationTime);
CarbonImmutable::setTestNow($operationTime);
DB::statement("set lock_timeout = '10s'");
file_put_contents($attemptPath, (string) DB::selectOne('select pg_backend_pid() as pid')->pid);

if ($hold) {
    DB::beginTransaction();
}

// A blocked activation's clock advances only once the setting lock has actually returned.
if (! $hold && $operation === 'activate') {
    DB::listen(function (QueryExecuted $query) use ($ids): void {
        if (str_contains($query->sql, '"institution_settings"') && str_contains(strtolower($query->sql), 'for update')) {
            $setting = InstitutionSetting::query()->whereKey($ids['institution'])->firstOrFail();
            if ($setting->blitz_timer_start_mode === BlitzTimerStartMode::Individual) {
                Carbon::setTestNow('2026-09-17 11:00:00.999999 UTC');
                CarbonImmutable::setTestNow('2026-09-17 11:00:00.999999 UTC');
            }
        }
    });
}

$outcome = 'ok';
try {
    match ($operation) {
        'activate' => app(ActivateTeacherBlitz::class)($teacher, $ids['assessment'], (string) Str::uuid()),
        'replace' => app(SetTeacherTopicResultPair::class)($teacher, $ids['topic'], $ids['homework'], $ids['candidate']),
        'question' => app(UpdateTeacherQuestion::class)($teacher, $ids['question'], [
            'prompt' => 'Committed before activation', 'points' => '3.100002',
        ]),
        'settings' => app(UpdateInstitutionAssessmentSettings::class)(
            User::query()->findOrFail($ids['admin']), '10.00000000', BlitzTimerStartMode::Individual,
            StudentResultReleaseMode::Automatic, ParentResultReleaseMode::WithStudent, 'Asia/Tashkent', 25, 15,
        ),
    };
} catch (BusinessConflictException) {
    $outcome = 'business_conflict';
} catch (ResultPairLockedException) {
    $outcome = 'result_pair_locked';
}

$blitz = BlitzTask::query()->findOrFail($ids['assessment']);
$assessment = Assessment::query()->findOrFail($ids['assessment']);
$pair = TopicResultPair::query()->findOrFail($ids['pair']);
$recipients = AssessmentStudent::query()->where('assessment_id', $ids['assessment'])->orderBy('student_id')->get();
$question = Question::query()->findOrFail($ids['question']);
$questionSnapshot = $question->getAttributes();
$questionSnapshot['configuration'] = $question->trueFalseAnswer->getAttributes();
$result = [
    'outcome' => $outcome, 'status' => $blitz->status->value,
    'activated_at' => $blitz->activated_at?->toIso8601String(), 'activated_by' => $blitz->activated_by_user_id,
    'synchronized_ends_at' => $blitz->synchronized_ends_at?->toIso8601String(),
    'timer_mode' => $blitz->timer_start_mode_snapshot?->value,
    'setting_mode' => InstitutionSetting::query()->whereKey($ids['institution'])->firstOrFail()->blitz_timer_start_mode?->value,
    'recipient_student_ids' => $recipients->pluck('student_id')->all(),
    'attempt_count' => AssessmentAttempt::query()->where('assessment_id', $ids['assessment'])->count(),
    'total' => $assessment->total_possible_points, 'question' => $questionSnapshot,
    'pair' => ['blitz_assessment_id' => $pair->blitz_assessment_id,
        'cohort_snapshotted_at' => $pair->cohort_snapshotted_at?->toIso8601String(),
        'locked_at' => $pair->locked_at?->toIso8601String()],
    'records' => IdempotencyRecord::query()->where('institution_id', $ids['institution'])->orderBy('id')->get()->map->getAttributes()->all(),
    'activation_snapshot' => [$assessment->getAttributes(), $blitz->getAttributes(), $pair->getAttributes(), $recipients->map->getAttributes()->all()],
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
    fwrite(STDERR, 'Timed out waiting for the PostgreSQL activation contention barrier release.');
    exit(1);
}

echo json_encode($result, JSON_THROW_ON_ERROR);
PHP;
    }
}
