<?php

namespace App\Actions\Student;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\IdempotencyOperation;
use App\Enums\TopicStatus;
use App\Exceptions\Student\StudentBlitzAttemptNotEditableException;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Exceptions\Student\StudentBlitzTimeExpiredException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Models\IdempotencyRecord;
use App\Models\Question;
use App\Models\User;
use App\Support\Assessment\BlitzAttemptFinalizer;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Student\StudentAttemptSubmitResult;
use App\Support\Student\StudentBlitzAttemptAccess;
use App\Support\Student\StudentBlitzHistoricalAnswerReadProof;
use App\Support\Student\StudentBlitzTiming;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use Illuminate\Support\Facades\DB;
use LogicException;

final class SubmitStudentBlitzAttempt
{
    public function __construct(
        private readonly StudentBlitzAttemptAccess $access,
        private readonly IdempotencyRequestFingerprint $fingerprints,
        private readonly IdempotencyGuard $idempotency,
        private readonly StudentHomeworkAttemptAnswerStates $answerStates,
        private readonly BlitzAttemptFinalizer $finalizer,
        private readonly FinalizeTimedOutBlitzAttempts $finalizeTimeouts,
        private readonly StudentBlitzTiming $timing,
        private readonly ShowStudentBlitzAttempt $showAttempt,
    ) {}

    public function __invoke(User $student, string $attemptId, string $idempotencyKey): StudentAttemptSubmitResult
    {
        $authorizedAttempt = $this->access->resolveAttempt($student, $attemptId);
        $authorizedAssessment = Assessment::query()->select(['id', 'topic_id'])
            ->where('institution_id', $student->institution_id)
            ->whereKey($authorizedAttempt->assessment_id)->first();

        if ($authorizedAssessment === null) {
            throw new LogicException('Authorized Blitz Attempt lost its Assessment.');
        }

        $operation = IdempotencyOperation::StudentBlitzAttemptSubmit;
        $fingerprint = $this->fingerprints->make($student, $operation, ['attempt_id' => strtolower($authorizedAttempt->id)]);

        $result = DB::transaction(function () use ($student, $authorizedAssessment, $authorizedAttempt, $operation, $idempotencyKey, $fingerprint): ?StudentAttemptSubmitResult {
            ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] = $this->access->shareBlitzForSubmit($student, $authorizedAssessment);
            $attempt = AssessmentAttempt::query()
                ->where('institution_id', $student->institution_id)->where('student_id', $student->id)
                ->where('assessment_id', $assessment->id)
                ->where('assessment_student_id', $authorizedAttempt->assessment_student_id)
                ->whereKey($authorizedAttempt->id)->lockForUpdate()->first();

            if ($attempt === null) {
                throw new LogicException('Authorized Blitz Attempt changed during locked re-resolution.');
            }

            $this->access->assertValidAnswerAttempt($student, $assessment, $attempt);
            $replay = $this->idempotency->completedReplay($student, $operation, $idempotencyKey, $fingerprint);

            if ($replay !== null) {
                return $this->replay($student, $assessment, $blitz, $attempt, $replay, $idempotencyKey, $fingerprint);
            }

            $claim = $this->idempotency->claim($student, $operation, $idempotencyKey, $fingerprint);

            if (! $claim->new) {
                return $this->replay($student, $assessment, $blitz, $attempt, $claim->record, $idempotencyKey, $fingerprint);
            }

            if ($attempt->status === AssessmentAttemptStatus::TimedOutFinalized
                && $attempt->finalization_reason === AssessmentAttemptFinalizationReason::TimeoutAutoSubmit) {
                throw new StudentBlitzTimeExpiredException;
            }

            if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
                throw new StudentBlitzAttemptNotEditableException;
            }

            if ($topic->status !== TopicStatus::Active || $blitz->status !== BlitzStatus::Active) {
                throw new StudentBlitzNotActiveException;
            }

            // All parent, Attempt and idempotency lock waits precede the one Submit decision instant.
            $submittedAt = $this->timing->now();

            if ($submittedAt->gte($attempt->deadline_at)) {
                $this->idempotency->abandon($claim);

                return null;
            }

            $questions = Question::query()->select(['id', 'institution_id', 'assessment_id', 'type', 'position'])
                ->where('institution_id', $student->institution_id)->where('assessment_id', $assessment->id)
                ->orderBy('position')->orderBy('id')->get();
            ($this->answerStates)($student->institution_id, $attempt, $questions);

            if (! $this->finalizer->finalizeByStudentSubmit($attempt, $submittedAt)) {
                throw new LogicException('A locked editable Blitz Attempt must accept Student Submit.');
            }

            $this->idempotency->complete($claim, 'assessment_attempt', $attempt->id, 200);

            return new StudentAttemptSubmitResult(
                $attempt->id, AssessmentType::Blitz,
                attempt: ($this->showAttempt)($student, $assessment, $blitz, $attempt, $submittedAt),
            );
        });

        if ($result === null) {
            // The shared timeout engine must acquire its locks after Submit releases its own.
            ($this->finalizeTimeouts)($student->institution_id, $authorizedAssessment->id);

            throw new StudentBlitzTimeExpiredException;
        }

        return $result;
    }

    private function replay(
        User $student,
        Assessment $assessment,
        BlitzTask $blitz,
        AssessmentAttempt $attempt,
        IdempotencyRecord $record,
        string $idempotencyKey,
        string $fingerprint,
    ): StudentAttemptSubmitResult {
        if ($record->result_resource_type !== 'assessment_attempt'
            || $record->result_resource_id !== $attempt->id || $record->response_status !== 200
            || $record->completed_at === null
            || ! in_array($attempt->status, [
                AssessmentAttemptStatus::Submitted,
                AssessmentAttemptStatus::WaitingForTeacherReview,
                AssessmentAttemptStatus::Checked,
            ], true)
            || $attempt->finalization_reason !== AssessmentAttemptFinalizationReason::StudentSubmit
            || $attempt->submitted_at === null || $attempt->finalized_at === null || $attempt->locked_at === null
            || ! $attempt->finalized_at->equalTo($attempt->submitted_at)
            || ! $attempt->locked_at->equalTo($attempt->submitted_at)
            || ! $attempt->finalized_at->lt($attempt->deadline_at)) {
            throw new LogicException('Completed Blitz Submit must preserve the same Student Submit execution history.');
        }

        $proof = $attempt->status === AssessmentAttemptStatus::Submitted ? null
            : StudentBlitzHistoricalAnswerReadProof::forSubmit(
                $student, $assessment, $attempt, $record, $idempotencyKey, $fingerprint,
            );

        return new StudentAttemptSubmitResult(
            $attempt->id, AssessmentType::Blitz,
            attempt: ($this->showAttempt)($student, $assessment, $blitz, $attempt, $this->timing->now(), $proof),
        );
    }
}
