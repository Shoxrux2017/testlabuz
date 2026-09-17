<?php

namespace Tests\Feature\Teacher;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TeacherBlitzQuestionMutationConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_question_mutations_and_active_lifecycle_state_serialize_without_partial_question_changes(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());
        $workerPath = tempnam(sys_get_temp_dir(), 's08_be_003_question_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->workerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach (['add', 'update', 'delete', 'reorder'] as $mutation) {
                foreach (['lifecycle_first', 'mutation_first'] as $order) {
                    $scenario = $mutation.'_'.$order;
                    $lifecycleFirst = $order === 'lifecycle_first';
                    $result = $this->runRace(
                        $workerPath,
                        $ids,
                        $scenario,
                        $lifecycleFirst ? 'lifecycle' : $mutation,
                        $lifecycleFirst ? $mutation : 'lifecycle',
                    );
                    $this->assertSame('ok', $result['first']['outcome'], $scenario.' first outcome');
                    $this->assertSame($lifecycleFirst ? 'business_conflict' : 'ok', $result['second']['outcome'], $scenario.' second outcome');
                    $final = $result['second'];
                    $this->assertSame('active', $final['status'], $scenario);
                    $this->assertSame('2026-09-16T10:00:00+00:00', $final['activated_at'], $scenario);
                    $this->assertSame(0, $final['attempt_count'], $scenario);
                    $this->assertSame(0, $final['recipient_count'], $scenario);

                    $expectedSnapshot = $lifecycleFirst ? $ids['snapshots'][$scenario] : $result['first']['snapshot'];
                    $this->assertSame($expectedSnapshot, $final['snapshot'], $scenario.' committed Question domain');
                    $lifecycleResult = $lifecycleFirst ? $result['first'] : $result['second'];
                    $this->assertSame($expectedSnapshot, $lifecycleResult['observed_snapshot'], $scenario.' lifecycle observed committed state');
                    $questions = $final['snapshot']['questions'];
                    $expectedCount = ! $lifecycleFirst && $mutation === 'add' ? 3 : (! $lifecycleFirst && $mutation === 'delete' ? 1 : 2);
                    $this->assertCount($expectedCount, $questions, $scenario);
                    $this->assertSame(range(1, $expectedCount), array_column($questions, 'position'), $scenario.' positions');
                    $this->assertSame($final['snapshot']['total_possible_points'], $final['question_points_sum'], $scenario.' exact total');
                    $this->assertSame(0, $final['orphan_configuration_count'], $scenario.' typed ownership');

                    foreach ($questions as $question) {
                        $this->assertLessThanOrEqual($final['activated_at'], $question['updated_at'], $scenario.' Question changed after activation');
                        $this->assertSame($question['type'] === 'true_false' ? 1 : 0, count($question['true_false_answers']), $scenario);
                        $this->assertSame($question['type'] === 'single_choice' ? 2 : 0, count($question['choice_options']), $scenario);
                    }

                    if (! $lifecycleFirst) {
                        $this->assertMutationState($mutation, $questions, $final['snapshot']['total_possible_points'], $ids['questions'][$scenario]);
                    }
                }
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    private function assertMutationState(string $mutation, array $questions, string $total, array $originalIds): void
    {
        $this->assertSame(match ($mutation) {
            'add', 'update' => '0.600006',
            'delete' => '0.200002',
            'reorder' => '0.300003',
        }, $total);

        match ($mutation) {
            'add' => $this->assertSame(['Original first', 'Concurrent add', 'Original second'], array_column($questions, 'prompt')),
            'update' => $this->assertSame(['single_choice', 'true_false'], array_column($questions, 'type')),
            'delete' => $this->assertSame([$originalIds[1]], array_column($questions, 'id')),
            'reorder' => $this->assertSame(array_reverse($originalIds), array_column($questions, 'id')),
        };
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(string $workerPath, array $ids, string $scenario, string $firstOperation, string $secondOperation): array
    {
        $lockedPath = $this->unusedTempPath('s08_be_003_locked_');
        $releasePath = $this->unusedTempPath('s08_be_003_release_');
        $attemptPath = $this->unusedTempPath('s08_be_003_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
        $arguments = [$ids['teacher'], $ids['assessments'][$scenario], implode(',', $ids['questions'][$scenario])];
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation,
            'hold', $lockedPath, $releasePath, $firstAttemptPath,
        ]);
        $second = null;

        try {
            $this->waitForFile($lockedPath, 'The first Blitz Question worker did not retain its locks.');
            $second = $this->startWorker([
                $workerPath, base_path(), 'run', ...$arguments, $secondOperation,
                'normal', $lockedPath, $releasePath, $attemptPath,
            ]);
            $this->waitForFile($attemptPath, 'The competing Blitz Question worker did not start.');
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

        $this->fail('Competing Blitz Question worker did not enter a PostgreSQL lock wait for '.$scenario.': '.json_encode($activity));
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

use App\Actions\Teacher\AddTeacherAssessmentQuestion;
use App\Actions\Teacher\DeleteTeacherQuestion;
use App\Actions\Teacher\ReorderTeacherAssessmentQuestions;
use App\Actions\Teacher\UpdateTeacherQuestion;
use App\Domain\Assessment\AssessmentPointMath;
use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\Topic;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use App\Support\Teacher\TeacherBlitzAccess;
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

function questionSnapshot(string $assessmentId): array
{
    $assessment = Assessment::query()->findOrFail($assessmentId);
    $questions = Question::query()->where('assessment_id', $assessmentId)
        ->with(['trueFalseAnswer', 'choiceOptions' => fn ($query) => $query->orderBy('position')->orderBy('id')])
        ->orderBy('position')->orderBy('id')->get();

    return [
        'total_possible_points' => $assessment->total_possible_points,
        'assessment_updated_at' => $assessment->updated_at->toIso8601String(),
        'questions' => $questions->map(fn (Question $question) => [
            ...$question->getAttributes(),
            'updated_at' => $question->updated_at->toIso8601String(),
            'true_false_answers' => $question->trueFalseAnswer === null ? [] : [$question->trueFalseAnswer->getAttributes()],
            'choice_options' => $question->choiceOptions->map(fn ($option) => $option->getAttributes())->all(),
        ])->all(),
    ];
}

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'Blitz Question concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id, 'timezone' => 'Asia/Tashkent']);
    $ids = ['institution' => $institution->id, 'teacher' => $teacher->id, 'assessments' => [], 'questions' => [], 'snapshots' => []];

    foreach (['add', 'update', 'delete', 'reorder'] as $mutation) {
        foreach (['lifecycle_first', 'mutation_first'] as $order) {
            $scenario = $mutation.'_'.$order;
            $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
            GroupTeacherMembership::factory()->create([
                'institution_id' => $institution->id, 'group_id' => $group->id,
                'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id,
            ]);
            $topic = Topic::factory()->active()->create([
                'institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $teacher->id,
            ]);
            $assessment = Assessment::factory()->blitz()->create([
                'institution_id' => $institution->id, 'topic_id' => $topic->id, 'teacher_id' => $teacher->id,
                'total_possible_points' => '0.300003',
            ]);
            $blitzFactory = BlitzTask::factory();
            $blitzFactory = in_array($mutation, ['update', 'reorder'], true) ? $blitzFactory->scheduled() : $blitzFactory->draft();
            $blitzFactory->create(['assessment_id' => $assessment->id, 'institution_id' => $institution->id]);
            $questionIds = [];

            foreach ([['Original first', '0.100001'], ['Original second', '0.200002']] as $index => [$prompt, $points]) {
                $questionIds[] = app(QuestionConfigurationWriter::class)->create($assessment, [
                    'type' => 'true_false', 'prompt' => $prompt, 'instructions' => null,
                    'points' => $points, 'position' => $index + 1, 'checking_mode' => 'automatic',
                    'configuration' => ['correct_value' => true],
                ])->id;
            }

            $ids['assessments'][$scenario] = $assessment->id;
            $ids['questions'][$scenario] = $questionIds;
            $ids['snapshots'][$scenario] = questionSnapshot($assessment->id);
        }
    }

    echo json_encode($ids, JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    QuestionChoiceOption::query()->where('institution_id', $institutionId)->delete();
    QuestionTrueFalseAnswer::query()->where('institution_id', $institutionId)->delete();
    Question::query()->where('institution_id', $institutionId)->delete();
    BlitzTask::query()->where('institution_id', $institutionId)->delete();
    Assessment::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$assessmentId = $argv[4];
$questionIds = explode(',', $argv[5]);
$operation = $argv[6];
$hold = $argv[7] === 'hold';
$lockedPath = $argv[8];
$releasePath = $argv[9];
$attemptPath = $argv[10];
$operationTime = $operation === 'lifecycle' ? '2026-09-16 10:00:00 UTC' : ($hold ? '2026-09-16 09:00:00 UTC' : '2026-09-16 11:00:00 UTC');
Carbon::setTestNow($operationTime);
CarbonImmutable::setTestNow($operationTime);
DB::statement("set lock_timeout = '10s'");
file_put_contents($attemptPath, (string) DB::selectOne('select pg_backend_pid() as pid')->pid);

if ($hold) {
    DB::beginTransaction();
}

$outcome = 'ok';
$observedSnapshot = null;
try {
    match ($operation) {
        'add' => app(AddTeacherAssessmentQuestion::class)($teacher, $assessmentId, [
            'type' => 'true_false', 'prompt' => 'Concurrent add', 'instructions' => null,
            'points' => '0.300003', 'position' => 2, 'checking_mode' => 'automatic',
            'configuration' => ['correct_value' => false],
        ]),
        'update' => app(UpdateTeacherQuestion::class)($teacher, $questionIds[0], [
            'type' => 'single_choice', 'prompt' => 'Concurrent replacement', 'points' => '0.400004',
            'configuration' => ['options' => [
                ['text' => 'Correct', 'is_correct' => true, 'position' => 1],
                ['text' => 'Incorrect', 'is_correct' => false, 'position' => 2],
            ]],
        ]),
        'delete' => app(DeleteTeacherQuestion::class)($teacher, $questionIds[0]),
        'reorder' => app(ReorderTeacherAssessmentQuestions::class)($teacher, $assessmentId, array_reverse($questionIds)),
        'lifecycle' => DB::transaction(function () use ($teacher, $assessmentId, &$observedSnapshot): void {
            $access = app(TeacherBlitzAccess::class);
            $context = $access->lockBlitz($teacher, $access->resolveBlitz($teacher, $assessmentId));
            $access->lockResultPair($teacher, $context['topic'], $context['assessment']);
            $access->lockAttempts($teacher, $context['assessment']);
            $questions = Question::query()->where('institution_id', $teacher->institution_id)
                ->where('assessment_id', $assessmentId)->orderBy('position')->orderBy('id')->lockForUpdate()->get();
            app(QuestionConfigurationWriter::class)->lockAndLoadConfigurations($questions);
            $observedSnapshot = questionSnapshot($assessmentId);
            $context['blitz']->forceFill([
                'status' => BlitzStatus::Active,
                'timer_start_mode_snapshot' => BlitzTimerStartMode::Synchronized,
                'activated_at' => now(),
                'synchronized_ends_at' => now()->addSeconds($context['blitz']->duration_seconds),
                'activated_by_user_id' => $teacher->id,
            ])->save();
        }),
    };
} catch (BusinessConflictException) {
    $outcome = 'business_conflict';
}

$blitz = BlitzTask::query()->findOrFail($assessmentId);
$snapshot = questionSnapshot($assessmentId);
$orphanConfigurationCount = 0;
foreach ([QuestionTrueFalseAnswer::class, QuestionChoiceOption::class] as $configurationClass) {
    $orphanConfigurationCount += $configurationClass::query()->where('institution_id', $teacher->institution_id)
        ->whereNotIn('question_id', Question::query()->where('institution_id', $teacher->institution_id)->select('id'))->count();
}
$result = [
    'outcome' => $outcome, 'status' => $blitz->status->value,
    'activated_at' => $blitz->activated_at?->toIso8601String(),
    'snapshot' => $snapshot, 'observed_snapshot' => $observedSnapshot,
    'question_points_sum' => app(AssessmentPointMath::class)->sum(array_column($snapshot['questions'], 'points')),
    'orphan_configuration_count' => $orphanConfigurationCount,
    'attempt_count' => AssessmentAttempt::query()->where('assessment_id', $assessmentId)->count(),
    'recipient_count' => AssessmentStudent::query()->where('assessment_id', $assessmentId)->count(),
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
