<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\HomeworkAssignment;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

class StudentHomeworkAttemptSummary
{
    /** @return array<string, mixed> */
    public function __invoke(User $student, Assessment $assessment, CarbonInterface $readAt): array
    {
        $homework = $assessment->relationLoaded('homeworkAssignment') ? $assessment->getRelation('homeworkAssignment') : null;
        $attempts = $assessment->relationLoaded('attempts') ? $assessment->getRelation('attempts') : null;
        $recipientId = $assessment->getAttribute('student_recipient_id');

        if (! $homework instanceof HomeworkAssignment || ! $attempts instanceof Collection || ! is_string($recipientId)) {
            throw new LogicException('Student Homework summary requires a loaded assignment and Attempt graph.');
        }

        $inProgress = null;
        $latest = null;

        foreach ($attempts as $attempt) {
            $this->assertValidAttempt($attempt, $student, $assessment, $recipientId);

            if ($attempt->status === AssessmentAttemptStatus::InProgress) {
                if ($inProgress !== null) {
                    throw new LogicException('Homework has multiple in-progress Attempts for one recipient.');
                }

                $inProgress = $attempt;
            }

            if ($latest === null || $attempt->attempt_number > $latest->attempt_number) {
                $latest = $attempt;
            }
        }

        $used = $attempts->count();
        $available = $homework->status === HomeworkStatus::Active
            && ($homework->deadline_at === null || $readAt->lt($homework->deadline_at));

        return [
            'attempts' => [
                'allowed' => 3,
                'used' => $used,
                'remaining' => $available ? max(0, 3 - $used) : 0,
                'official_score_policy' => 'highest_valid_completed',
            ],
            'my_status' => $inProgress !== null ? AssessmentAttemptStatus::InProgress->value : ($latest?->status->value ?? 'not_started'),
            'in_progress_attempt' => $inProgress === null ? null : [
                'id' => $inProgress->id,
                'attempt_number' => $inProgress->attempt_number,
                'started_at' => $inProgress->started_at->copy()->utc()->format('Y-m-d\TH:i:s\Z'),
            ],
        ];
    }

    private function assertValidAttempt(AssessmentAttempt $attempt, User $student, Assessment $assessment, string $recipientId): void
    {
        if ($attempt->institution_id !== $student->institution_id
            || $attempt->assessment_id !== $assessment->id
            || $attempt->student_id !== $student->id
            || $attempt->assessment_student_id !== $recipientId) {
            throw new LogicException('Homework Attempt does not match the authoritative recipient.');
        }

        if (! in_array($attempt->status, [
            AssessmentAttemptStatus::InProgress,
            AssessmentAttemptStatus::Submitted,
            AssessmentAttemptStatus::WaitingForTeacherReview,
            AssessmentAttemptStatus::Checked,
        ], true) || $attempt->finalization_reason === AssessmentAttemptFinalizationReason::TimeoutAutoSubmit) {
            throw new LogicException('Homework Attempt contains an invalid Homework state.');
        }

        if (($attempt->status === AssessmentAttemptStatus::InProgress && $attempt->finalization_reason !== null)
            || ($attempt->status === AssessmentAttemptStatus::Submitted && ! in_array($attempt->finalization_reason, [
                AssessmentAttemptFinalizationReason::StudentSubmit,
                AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize,
                AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit,
            ], true))) {
            throw new LogicException('Homework Attempt contains an invalid finalization reason.');
        }
    }
}
