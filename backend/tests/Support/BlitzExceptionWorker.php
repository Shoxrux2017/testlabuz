<?php

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Actions\Student\StartStudentBlitzAttempt;
use App\Actions\Student\SubmitStudentBlitzAttempt;
use App\Actions\Teacher\CloseTeacherBlitz;
use App\Actions\Teacher\GrantTeacherBlitzAttemptException;
use App\Exceptions\Student\StudentBlitzAttemptNotEditableException;
use App\Exceptions\Student\StudentBlitzAttemptsExhaustedException;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Exceptions\Student\StudentBlitzTimeExpiredException;
use App\Exceptions\Teacher\BlitzAttemptExceptionAlreadyGrantedException;
use App\Exceptions\Teacher\BlitzAttemptExceptionNotAllowedException;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

require dirname(__DIR__, 2).'/vendor/autoload.php';
$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();
if (DB::connection()->getDatabaseName() !== 'testlabuz_testing') {
    throw new RuntimeException('Exception workers require the isolated testing database.');
}
$input = json_decode($argv[1], true, flags: JSON_THROW_ON_ERROR);
Carbon::setTestNow($input['now']);
CarbonImmutable::setTestNow($input['now']);
DB::statement("SET lock_timeout = '10s'");
$pid = DB::selectOne('SELECT pg_backend_pid() AS pid')->pid;
echo json_encode(['event' => 'started', 'pid' => $pid])."\n";
flush();
if ($input['wait'] ?? false) {
    if (trim((string) fgets(STDIN)) !== 'run') {
        throw new RuntimeException('Worker requires explicit read barrier release.');
    }
}
$hold = $input['hold'] ?? false;
if ($hold) {
    DB::beginTransaction();
}
$result = ['outcome' => 'ok', 'status' => null, 'id' => null];
try {
    $student = User::query()->findOrFail($input['student']);
    $teacher = User::query()->findOrFail($input['teacher']);
    switch ($input['operation']) {
        case 'grant':
            $exception = app(GrantTeacherBlitzAttemptException::class)($teacher, $input['assessment'], $student->id, $input['key'],
                ['reason_type' => 'technical', 'reason' => 'Device interruption.']);
            $result['status'] = 201;
            $result['id'] = $exception->id;
            break;
        case 'close': app(CloseTeacherBlitz::class)($teacher, $input['assessment']);
            break;
        case 'timeout': app(FinalizeTimedOutBlitzAttempts::class)($student->institution_id, $input['assessment']);
            break;
        case 'submit': app(SubmitStudentBlitzAttempt::class)($student, $input['attempt'], $input['key']);
            break;
        default:
            $start = app(StartStudentBlitzAttempt::class)($student, $input['assessment'], $input['key'],
                $input['operation'], $input['operation'] === 'resume' ? $input['attempt'] : null);
            $result['status'] = $start->httpStatus;
            $result['id'] = $start->attemptId;
    }
} catch (BlitzAttemptExceptionAlreadyGrantedException) {
    $result['outcome'] = 'already_granted';
} catch (BlitzAttemptExceptionNotAllowedException) {
    $result['outcome'] = 'not_allowed';
} catch (StudentBlitzAttemptsExhaustedException) {
    $result['outcome'] = 'attempts_exhausted';
} catch (StudentBlitzAttemptNotEditableException) {
    $result['outcome'] = 'attempt_not_editable';
} catch (StudentBlitzTimeExpiredException) {
    $result['outcome'] = 'blitz_time_expired';
} catch (StudentBlitzNotActiveException) {
    $result['outcome'] = 'blitz_not_active';
}
if ($hold) {
    echo json_encode(['event' => 'held', 'pid' => $pid])."\n";
    flush();
    if (trim((string) fgets(STDIN)) !== 'commit') {
        DB::rollBack();
        throw new RuntimeException('Worker requires explicit commit barrier release.');
    }
    DB::commit();
}
echo json_encode(['event' => 'result'] + $result)."\n";
