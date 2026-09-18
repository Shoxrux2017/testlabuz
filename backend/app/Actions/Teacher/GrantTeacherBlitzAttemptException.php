<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\IdempotencyOperation;
use App\Enums\UserRole;
use App\Exceptions\Teacher\BlitzAttemptExceptionAlreadyGrantedException;
use App\Exceptions\Teacher\BlitzAttemptExceptionNotAllowedException;
use App\Exceptions\Teacher\BlitzNormalAttemptRequiredException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\User;
use App\Support\Assessment\BlitzAttemptFinalizer;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Student\StudentBlitzAttemptSummary;
use App\Support\Student\StudentBlitzTiming;
use App\Support\Teacher\TeacherBlitzLifecycleAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class GrantTeacherBlitzAttemptException
{
    public function __construct(
        private readonly TeacherBlitzLifecycleAccess $access,
        private readonly IdempotencyGuard $idempotency,
        private readonly IdempotencyRequestFingerprint $fingerprints,
        private readonly StudentBlitzAttemptSummary $history,
        private readonly StudentBlitzTiming $timing,
        private readonly BlitzAttemptFinalizer $finalizer,
    ) {}

    public function __invoke(User $teacher, string $blitzId, string $studentId, string $key, array $reason): BlitzAttemptException
    {
        $authorized = $this->access->resolveBlitz($teacher, $blitzId);
        $this->recipient($teacher, $authorized, $studentId, false);
        $operation = IdempotencyOperation::TeacherBlitzAttemptExceptionGrant;
        $fingerprint = $this->fingerprints->make($teacher, $operation,
            ['blitz_id' => strtolower($authorized->id), 'student_id' => strtolower($studentId)], $reason);

        return DB::transaction(function () use ($teacher, $authorized, $studentId, $key, $reason, $operation, $fingerprint): BlitzAttemptException {
            ['assessment' => $assessment, 'blitz' => $blitz] = $this->access->lockBlitz($teacher, $authorized);
            $recipient = $this->recipient($teacher, $assessment, $studentId, true);
            $student = User::query()->where('institution_id', $teacher->institution_id)
                ->where('role', UserRole::Student)->where('is_active', true)
                ->whereKey($recipient->student_id)->lockForUpdate()->first();
            if ($student === null) {
                throw new NotFoundHttpException;
            }

            $claim = $this->idempotency->claim($teacher, $operation, $key, $fingerprint);
            $attempts = AssessmentAttempt::query()->where('institution_id', $teacher->institution_id)
                ->where('assessment_id', $assessment->id)->where('student_id', $student->id)
                ->orderBy('attempt_number')->orderBy('id')->lockForUpdate()->get();
            $exception = BlitzAttemptException::query()->where('institution_id', $teacher->institution_id)
                ->where('assessment_id', $assessment->id)->where('student_id', $student->id)->lockForUpdate()->first();

            if (! $claim->new) {
                $record = $claim->record;
                if ($exception === null || $record->result_resource_type !== 'blitz_attempt_exception'
                    || $record->result_resource_id !== $exception->id || $record->response_status !== 201) {
                    throw new LogicException('Completed grant must reference its exact authorized exception.');
                }
                $this->timing->assertValidTask($blitz);
                $this->history->validateHistory($student, $assessment, $blitz, $recipient->id, $attempts, $exception);
            } else {
                if ($blitz->status !== BlitzStatus::Active) {
                    throw new BlitzAttemptExceptionNotAllowedException;
                }
                if ($exception !== null) {
                    throw new BlitzAttemptExceptionAlreadyGrantedException;
                }
                if ($attempts->isEmpty()) {
                    throw new BlitzNormalAttemptRequiredException;
                }
                $this->timing->assertValidTask($blitz);
                $normal = $this->history->validateHistory($student, $assessment, $blitz, $recipient->id, $attempts);
                $grantedAt = $this->timing->now();
                if ($normal->status === AssessmentAttemptStatus::InProgress) {
                    if ($grantedAt->lt($normal->deadline_at)) {
                        throw new BlitzAttemptExceptionNotAllowedException;
                    }
                    $this->finalizer->finalizeAtTimeout($normal);
                }
                $this->history->assertTerminal($normal);
                $normal->official_score_eligible = false;
                AssessmentAttempt::withoutTimestamps(fn () => $normal->save());
                $exception = new BlitzAttemptException([
                    'institution_id' => $teacher->institution_id,
                    'assessment_id' => $assessment->id,
                    'assessment_student_id' => $recipient->id,
                    'student_id' => $student->id,
                    'invalidated_attempt_id' => $normal->id,
                    'replacement_attempt_id' => null,
                    'reason_type' => $reason['reason_type'],
                    'reason' => $reason['reason'],
                    'granted_by_user_id' => $teacher->id,
                    'granted_at' => $grantedAt,
                ]);
                $exception->created_at = $grantedAt;
                $exception->updated_at = $grantedAt;
                $exception->save();
                $this->idempotency->complete($claim, 'blitz_attempt_exception', $exception->id, 201);
            }

            $exception->setAttribute('replacement_attempt_available',
                $exception->replacement_attempt_id === null && $blitz->status === BlitzStatus::Active);

            return $exception;
        });
    }

    private function recipient(User $teacher, Assessment $assessment, string $studentId, bool $lock): AssessmentStudent
    {
        if (! Str::isUuid($studentId)) {
            throw new NotFoundHttpException;
        }
        $query = AssessmentStudent::query()->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)->where('student_id', $studentId)
            ->whereHas('student', fn ($query) => $query->where('institution_id', $teacher->institution_id)
                ->where('role', UserRole::Student)->where('is_active', true));
        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->first() ?? throw new NotFoundHttpException;
    }
}
