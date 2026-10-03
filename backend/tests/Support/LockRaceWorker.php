<?php

use App\Actions\Checking\CheckDueFrozenAttempts;
use App\Actions\Checking\CheckFrozenAttempt;
use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Actions\Student\SubmitStudentHomeworkAttempt;
use App\Actions\Teacher\ActivateTeacherBlitz;
use App\Actions\Teacher\CloseTeacherTopicResult;
use App\Actions\Teacher\GrantTeacherBlitzAttemptException;
use App\Actions\Teacher\ReviewTeacherSubmission;
use App\Exceptions\ResultClosedException;
use App\Exceptions\ResultNotReadyForClosureException;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/*
 * One operation of a real-concurrency race (S10-BE-004). With `hold`, the worker pauses right after
 * the first query that matches the given table and lock clause, while its transaction holds that
 * lock, and continues only when the test writes `release` to stdin.
 */
require dirname(__DIR__, 2).'/vendor/autoload.php';
$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
if (DB::connection()->getDatabaseName() !== 'testlabuz_testing') {
    throw new RuntimeException('Race workers require the isolated testing database.');
}
$input = json_decode($argv[1], true, flags: JSON_THROW_ON_ERROR);
Carbon::setTestNow($input['now']);
CarbonImmutable::setTestNow($input['now']);
DB::statement("SET lock_timeout = '10s'");
$pid = DB::selectOne('SELECT pg_backend_pid() AS pid')->pid;
echo json_encode(['event' => 'started', 'pid' => $pid])."\n";
flush();

if (isset($input['hold'])) {
    $held = false;
    DB::listen(function (QueryExecuted $query) use (&$held, $input, $pid): void {
        if ($held || ! str_contains($query->sql, 'from "'.$input['hold']['table'].'"')
            || ! str_ends_with($query->sql, $input['hold']['lock'])) {
            return;
        }
        $held = true;
        echo json_encode(['event' => 'held', 'pid' => $pid])."\n";
        flush();
        if (trim((string) fgets(STDIN)) !== 'release') {
            throw new RuntimeException('The race worker requires an explicit release.');
        }
    });
}

$result = ['outcome' => 'ok'];
try {
    $actor = isset($input['actor']) ? User::query()->findOrFail($input['actor']) : null;
    switch ($input['operation']) {
        case 'close_result':
            $result['status'] = app(CloseTeacherTopicResult::class)($actor, $input['topic'], $input['student'])->result->status->value;
            break;
        case 'review':
            $result['status'] = app(ReviewTeacherSubmission::class)($actor, $input['attempt'], $input['items'])->status->value;
            break;
        case 'finalize_homework_deadline':
            $result['finalized'] = app(FinalizeHomeworkAttemptsAtDeadline::class)($input['institution'], $input['assessment']);
            break;
        case 'activate_blitz':
            $result['status'] = app(ActivateTeacherBlitz::class)($actor, $input['assessment'], $input['key'])->blitzTask->status->value;
            break;
        case 'submit_homework':
            app(SubmitStudentHomeworkAttempt::class)($actor, $input['attempt'], $input['key']);
            break;
        case 'grant_exception':
            app(GrantTeacherBlitzAttemptException::class)($actor, $input['assessment'], $input['student'], $input['key'],
                ['reason_type' => 'technical', 'reason' => 'Device interruption.']);
            break;
        case 'check_attempt':
            $result['checked'] = app(CheckFrozenAttempt::class)($input['attempt']);
            break;
        case 'sweep':
            $result['counts'] = app(CheckDueFrozenAttempts::class)();
            break;
        default:
            throw new LogicException('Unknown race operation.');
    }
} catch (ResultClosedException) {
    $result['outcome'] = 'result_closed';
} catch (ResultNotReadyForClosureException) {
    $result['outcome'] = 'result_not_ready_for_closure';
} catch (Throwable $unexpected) {
    // Reported in the result so the test fails with the cause instead of a silent worker exit.
    $result['outcome'] = 'unexpected '.$unexpected::class.': '.$unexpected->getMessage();
}
echo json_encode(['event' => 'result'] + $result)."\n";
