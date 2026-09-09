<?php

namespace App\Actions\Homework;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\HomeworkStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\HomeworkAssignment;
use App\Support\Assessment\HomeworkAttemptFinalizer;
use Carbon\CarbonInterface;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use LogicException;

final class FinalizeHomeworkAttemptsAtDeadline
{
    public function __construct(private readonly HomeworkAttemptFinalizer $finalizer) {}

    public function __invoke(string $institutionId, string $assessmentId): int
    {
        return DB::transaction(function () use ($institutionId, $assessmentId): int {
            $assessment = Assessment::query()
                ->where('institution_id', $institutionId)
                ->whereKey($assessmentId)
                ->where('type', AssessmentType::Homework->value)
                ->lockForUpdate()
                ->first();

            if ($assessment === null) {
                return 0;
            }

            $homework = HomeworkAssignment::query()
                ->where('institution_id', $institutionId)
                ->where('assessment_id', $assessment->id)
                ->lockForUpdate()
                ->first();
            $observedAt = now();

            if ($homework === null || $homework->status !== HomeworkStatus::Active
                || $homework->deadline_at === null || $observedAt->lt($homework->deadline_at)) {
                return 0;
            }

            $attempts = AssessmentAttempt::query()
                ->where('institution_id', $homework->institution_id)
                ->where('assessment_id', $homework->assessment_id)
                ->where('status', AssessmentAttemptStatus::InProgress->value)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            return $this->finalizeLocked($homework, $attempts, $observedAt);
        });
    }

    /**
     * The caller holds the Homework and Attempt row locks through commit.
     *
     * @param  Collection<int, AssessmentAttempt>  $lockedAttempts
     */
    public function finalizeLocked(
        HomeworkAssignment $homework,
        Collection $lockedAttempts,
        CarbonInterface $observedAt,
    ): ?int {
        foreach ($lockedAttempts as $attempt) {
            if ($attempt->institution_id !== $homework->institution_id
                || $attempt->assessment_id !== $homework->assessment_id) {
                throw new LogicException('A locked Attempt does not belong to the Homework aggregate.');
            }
        }

        if ($homework->deadline_at === null || $observedAt->lt($homework->deadline_at)) {
            return null;
        }

        $finalized = 0;

        foreach ($lockedAttempts as $attempt) {
            if ($this->finalizer->finalizeAtDeadline($attempt, $homework->deadline_at)) {
                $finalized++;
            }
        }

        return $finalized;
    }
}
