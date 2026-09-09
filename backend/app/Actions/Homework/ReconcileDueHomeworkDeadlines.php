<?php

namespace App\Actions\Homework;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Models\HomeworkAssignment;
use Illuminate\Database\Query\Builder;
use Throwable;

final class ReconcileDueHomeworkDeadlines
{
    public function __construct(private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeAtDeadline) {}

    /** @return array{candidates: int, finalized_attempts: int, failures: int} */
    public function __invoke(): array
    {
        $counts = ['candidates' => 0, 'finalized_attempts' => 0, 'failures' => 0];
        $scanNow = now();
        $candidates = HomeworkAssignment::query()
            ->select(['institution_id', 'assessment_id'])
            ->where('status', HomeworkStatus::Active->value)
            ->whereNotNull('deadline_at')
            ->where('deadline_at', '<=', $scanNow)
            ->whereExists(fn (Builder $query) => $query
                ->selectRaw('1')
                ->from('assessment_attempts')
                ->whereColumn('assessment_attempts.institution_id', 'homework_assignments.institution_id')
                ->whereColumn('assessment_attempts.assessment_id', 'homework_assignments.assessment_id')
                ->where('assessment_attempts.status', AssessmentAttemptStatus::InProgress->value))
            ->lazyById(100, 'assessment_id');

        foreach ($candidates as $homework) {
            $counts['candidates']++;

            try {
                $counts['finalized_attempts'] += ($this->finalizeAtDeadline)(
                    $homework->institution_id,
                    $homework->assessment_id,
                );
            } catch (Throwable $exception) {
                report($exception);
                $counts['failures']++;
            }
        }

        return $counts;
    }
}
