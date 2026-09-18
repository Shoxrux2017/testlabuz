<?php

namespace App\Actions\Student;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use App\Enums\IdempotencyOperation;
use App\Enums\TopicStatus;
use App\Exceptions\Student\StudentBlitzAttemptNotEditableException;
use App\Exceptions\Student\StudentBlitzAttemptsExhaustedException;
use App\Exceptions\Student\StudentBlitzConflictException;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Exceptions\Student\StudentBlitzTimeExpiredException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\IdempotencyRecord;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Student\StudentBlitzAccess;
use App\Support\Student\StudentBlitzAttemptAccess;
use App\Support\Student\StudentBlitzAttemptStartResult;
use App\Support\Student\StudentBlitzAttemptSummary;
use App\Support\Student\StudentBlitzHistoricalAnswerReadProof;
use App\Support\Student\StudentBlitzTiming;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class StartStudentBlitzAttempt
{
    public function __construct(
        private readonly StudentBlitzAccess $access,
        private readonly StudentBlitzAttemptAccess $attemptAccess,
        private readonly StudentBlitzAttemptSummary $attemptSummary,
        private readonly StudentBlitzTiming $timing,
        private readonly IdempotencyRequestFingerprint $fingerprints,
        private readonly IdempotencyGuard $idempotency,
        private readonly ShowStudentBlitzAttempt $showAttempt,
        private readonly FinalizeTimedOutBlitzAttempts $finalizeTimeouts,
    ) {}

    public function __invoke(User $student, string $blitzId, string $idempotencyKey, string $intent, ?string $attemptId = null): StudentBlitzAttemptStartResult
    {
        $authorized = $this->access->resolveAssigned($student, $blitzId);
        $operation = IdempotencyOperation::StudentBlitzAttemptStart;
        $body = ['intent' => $intent];

        if ($intent === 'resume' && $attemptId !== null) {
            $attemptId = strtolower($attemptId);
            $body['attempt_id'] = $attemptId;
        } elseif ($intent !== 'start_normal' || $attemptId !== null) {
            throw new LogicException('Blitz Start requires a validated explicit execution intent.');
        }

        $fingerprint = $this->fingerprints->make($student, $operation, ['blitz_id' => strtolower($authorized->id)], $body);

        $result = DB::transaction(function () use ($student, $authorized, $operation, $idempotencyKey, $fingerprint, $intent, $attemptId): ?StudentBlitzAttemptStartResult {
            ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] = $this->attemptAccess->lockBlitz($student, $authorized);
            $pair = $this->attemptAccess->lockPair($student, $topic);
            $recipient = $this->attemptAccess->lockRecipient($student, $assessment, $authorized->getAttribute('student_recipient_id'));
            $claim = $this->idempotency->claim($student, $operation, $idempotencyKey, $fingerprint);
            $official = $pair !== null && $pair->blitz_assessment_id === $assessment->id;
            $attempts = $this->attemptAccess->lockAttempts($student, $assessment, $official ? $pair : null);

            if ($claim->new && ($topic->status !== TopicStatus::Active || $blitz->status !== BlitzStatus::Active)) {
                throw new StudentBlitzNotActiveException;
            }

            $this->timing->assertValidTask($blitz);

            if ($assessment->total_possible_points <= 0) {
                throw new LogicException('Active Blitz requires a positive Assessment points snapshot.');
            }

            $studentAttempts = $attempts->where('assessment_id', $assessment->id)->where('student_id', $student->id)->values();
            $current = $this->attemptSummary->validateHistory($student, $assessment, $blitz, $recipient->id, $studentAttempts);

            // Every parent, idempotency and activity lock wait precedes the authoritative decision instant.
            $serverNow = $this->timing->now();

            if (! $claim->new) {
                $this->assertReplay($claim->record, $current, $intent, $attemptId);
                $historicalReadProof = in_array($current->status, [AssessmentAttemptStatus::WaitingForTeacherReview, AssessmentAttemptStatus::Checked], true)
                    ? StudentBlitzHistoricalAnswerReadProof::forStart($student, $assessment, $current, $claim->record, $idempotencyKey, $fingerprint, $intent, $attemptId)
                    : null;

                return new StudentBlitzAttemptStartResult(
                    ($this->showAttempt)($student, $assessment, $blitz, $current, $serverNow, $historicalReadProof),
                    $claim->record->response_status,
                );
            }

            if ($official) {
                $this->assertOfficialPair($pair, $assessment, $recipient, $attempts->isNotEmpty());
            }

            if ($intent === 'resume') {
                if ($current === null || $current->id !== $attemptId) {
                    throw new NotFoundHttpException;
                }

                if ($current->status === AssessmentAttemptStatus::TimedOutFinalized) {
                    throw new StudentBlitzTimeExpiredException;
                }

                if ($current->status !== AssessmentAttemptStatus::InProgress) {
                    throw new StudentBlitzAttemptNotEditableException;
                }
            } elseif ($current !== null && $current->status !== AssessmentAttemptStatus::InProgress) {
                if ($current->status === AssessmentAttemptStatus::TimedOutFinalized) {
                    throw new StudentBlitzTimeExpiredException;
                }

                throw new StudentBlitzAttemptsExhaustedException;
            }

            if ($current !== null && $serverNow->gte($current->deadline_at)) {
                $this->idempotency->abandon($claim);

                return null;
            }

            $this->timing->assertExecutable($blitz, $current, $serverNow);

            if ($current !== null) {
                $this->idempotency->complete($claim, 'assessment_attempt', $current->id, 200);

                return new StudentBlitzAttemptStartResult(
                    ($this->showAttempt)($student, $assessment, $blitz, $current, $serverNow), 200,
                );
            }

            if ($official && $pair->locked_at === null) {
                $pair->locked_at = $serverNow;
                $pair->updated_at = $serverNow;
                $pair->save();
            }

            $attempt = AssessmentAttempt::query()->create([
                'institution_id' => $student->institution_id,
                'assessment_id' => $assessment->id,
                'assessment_student_id' => $recipient->id,
                'student_id' => $student->id,
                'attempt_number' => 1,
                'status' => AssessmentAttemptStatus::InProgress,
                'started_at' => $serverNow,
                'deadline_at' => $blitz->timer_start_mode_snapshot === BlitzTimerStartMode::Synchronized
                    ? $blitz->synchronized_ends_at : $serverNow->addSeconds($blitz->duration_seconds),
                'submitted_at' => null,
                'finalized_at' => null,
                'finalization_reason' => null,
                'locked_at' => null,
                'official_score_eligible' => true,
                'earned_points' => null,
                'possible_points' => $assessment->total_possible_points,
                'normalized_score' => null,
                'scoring_completed_at' => null,
            ]);
            $this->idempotency->complete($claim, 'assessment_attempt', $attempt->id, 201);

            return new StudentBlitzAttemptStartResult(
                ($this->showAttempt)($student, $assessment, $blitz, $attempt, $serverNow), 201,
            );
        });

        if ($result === null) {
            // Release Start's pair, recipient and activity locks before aggregate reconciliation.
            ($this->finalizeTimeouts)($student->institution_id, $authorized->id);

            throw new StudentBlitzTimeExpiredException;
        }

        if ($result->attempt->status === AssessmentAttemptStatus::InProgress
            && $this->timing->now()->gte($result->attempt->deadline_at)) {
            ($this->finalizeTimeouts)($student->institution_id, $authorized->id);
            $attempt = $this->attemptAccess->resolveAttempt($student, $result->attemptId);
            $assessment = $this->access->readQuery($student)->whereKey($authorized->id)->firstOrFail();

            return new StudentBlitzAttemptStartResult(
                ($this->showAttempt)($student, $assessment, $assessment->getRelation('blitzTask'), $attempt, $this->timing->now()),
                $result->httpStatus,
            );
        }

        return $result;
    }

    private function assertReplay(IdempotencyRecord $record, ?AssessmentAttempt $attempt, string $intent, ?string $attemptId): void
    {
        if ($record->result_resource_type !== 'assessment_attempt'
            || ! is_string($record->result_resource_id) || ! Str::isUuid($record->result_resource_id)
            || ! in_array($record->response_status, [200, 201], true) || $record->completed_at === null
            || $attempt === null || $attempt->id !== $record->result_resource_id
            || ($intent === 'start_normal' && $attempt->attempt_number !== 1)
            || ($intent === 'resume' && ($attempt->id !== $attemptId || $record->response_status !== 200))) {
            throw new LogicException('Completed Blitz Start must reference its authorized intent-specific Attempt.');
        }
    }

    private function assertOfficialPair(TopicResultPair $pair, Assessment $assessment, AssessmentStudent $recipient, bool $hasActivity): void
    {
        if ($assessment->assignment_mode !== AssessmentAssignmentMode::Group
            || $recipient->assignment_source !== AssessmentAssignmentSource::Group
            || $pair->homework_assessment_id === null || $pair->blitz_assessment_id !== $assessment->id
            || $pair->cohort_snapshotted_at === null
            || (($pair->locked_at !== null) !== $hasActivity)) {
            throw new StudentBlitzConflictException;
        }
    }
}
