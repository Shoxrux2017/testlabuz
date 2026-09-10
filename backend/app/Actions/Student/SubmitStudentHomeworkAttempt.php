<?php

namespace App\Actions\Student;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\IdempotencyOperation;
use App\Enums\TopicStatus;
use App\Exceptions\Student\AttemptNotEditableException;
use App\Exceptions\Student\StudentHomeworkArchivedException;
use App\Exceptions\Student\StudentHomeworkClosedException;
use App\Exceptions\Student\StudentHomeworkDeadlinePassedException;
use App\Exceptions\Student\StudentHomeworkNotActiveException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\IdempotencyRecord;
use App\Models\Question;
use App\Models\User;
use App\Support\Assessment\HomeworkAttemptFinalizer;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Student\StudentHomeworkAttemptAccess;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use App\Support\Student\StudentHomeworkAttemptSubmitResult;
use Illuminate\Support\Facades\DB;
use LogicException;

final class SubmitStudentHomeworkAttempt
{
    public function __construct(
        private readonly StudentHomeworkAttemptAccess $access,
        private readonly IdempotencyRequestFingerprint $fingerprints,
        private readonly IdempotencyGuard $idempotency,
        private readonly StudentHomeworkAttemptAnswerStates $answerStates,
        private readonly HomeworkAttemptFinalizer $finalizer,
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeAtDeadline,
    ) {}

    public function __invoke(User $student, string $attemptId, string $idempotencyKey): StudentHomeworkAttemptSubmitResult
    {
        $preliminaryAttempt = $this->access->resolveAttempt($student, $attemptId);
        $preliminaryAssessment = Assessment::query()
            ->select(['id', 'topic_id'])
            ->where('institution_id', $student->institution_id)
            ->whereKey($preliminaryAttempt->assessment_id)->first();

        if ($preliminaryAssessment === null) {
            throw new LogicException('Authorized Homework Attempt lost its Assessment.');
        }

        $operation = IdempotencyOperation::StudentHomeworkAttemptSubmit;
        $fingerprint = $this->fingerprints->make($student, $operation, ['attempt_id' => strtolower($preliminaryAttempt->id)]);

        $result = DB::transaction(function () use ($student, $preliminaryAssessment, $preliminaryAttempt, $operation, $idempotencyKey, $fingerprint): StudentHomeworkAttemptSubmitResult|array {
            ['topic' => $topic, 'assessment' => $assessment, 'homework' => $homework, 'attempt' => $attempt] = $this->access->lockForSubmit($student, $preliminaryAssessment, $preliminaryAttempt);
            $replay = $this->idempotency->completedReplay($student, $operation, $idempotencyKey, $fingerprint);

            if ($replay !== null) {
                return $this->replay($attempt, $replay);
            }

            $claim = $this->idempotency->claim($student, $operation, $idempotencyKey, $fingerprint);

            if (! $claim->new) {
                return $this->replay($attempt, $claim->record);
            }

            // Eligibility and all explicit finalization fields use the instant after every lock wait.
            $submittedAt = now();

            match ($homework->status) {
                HomeworkStatus::Closed => throw new StudentHomeworkClosedException,
                HomeworkStatus::Archived => throw new StudentHomeworkArchivedException,
                HomeworkStatus::Active => null,
                default => throw new StudentHomeworkNotActiveException,
            };

            if ($topic->status !== TopicStatus::Active) {
                throw new StudentHomeworkNotActiveException;
            }

            if ($homework->deadline_at !== null && $submittedAt->gte($homework->deadline_at)) {
                $this->idempotency->abandon($claim);

                return ['institutionId' => $student->institution_id, 'assessmentId' => $assessment->id];
            }

            if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
                throw new AttemptNotEditableException;
            }

            $questions = Question::query()
                ->select(['id', 'institution_id', 'assessment_id', 'type', 'position'])
                ->where('institution_id', $student->institution_id)
                ->where('assessment_id', $assessment->id)
                ->orderBy('position')
                ->orderBy('id')
                ->get();
            ($this->answerStates)($student->institution_id, $attempt, $questions);

            if (! $this->finalizer->finalizeByStudentSubmit($attempt, $submittedAt)) {
                throw new LogicException('A locked editable Homework Attempt must accept Student Submit.');
            }

            $this->idempotency->complete($claim, 'assessment_attempt', $attempt->id, 200);

            return new StudentHomeworkAttemptSubmitResult($attempt->id);
        });

        if (is_array($result)) {
            // Public reconciliation owns all due Attempts; release the local Submit locks first.
            ($this->finalizeAtDeadline)($result['institutionId'], $result['assessmentId']);

            throw new StudentHomeworkDeadlinePassedException;
        }

        return $result;
    }

    private function replay(AssessmentAttempt $attempt, IdempotencyRecord $record): StudentHomeworkAttemptSubmitResult
    {
        if ($record->result_resource_type !== 'assessment_attempt'
            || $record->result_resource_id !== $attempt->id
            || $record->response_status !== 200) {
            throw new LogicException('Completed Submit must reference the same successful Homework Attempt.');
        }

        return new StudentHomeworkAttemptSubmitResult($attempt->id);
    }
}
