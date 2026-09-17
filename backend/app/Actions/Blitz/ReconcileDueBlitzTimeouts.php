<?php

namespace App\Actions\Blitz;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Models\BlitzTask;
use Illuminate\Database\Query\Builder;
use Throwable;

final class ReconcileDueBlitzTimeouts
{
    public function __construct(private readonly FinalizeTimedOutBlitzAttempts $finalizeTimeouts) {}

    /** @return array{candidates: int, finalized_attempts: int, failures: int} */
    public function __invoke(): array
    {
        $counts = ['candidates' => 0, 'finalized_attempts' => 0, 'failures' => 0];
        $scanNow = now();
        $candidates = BlitzTask::query()
            ->select(['institution_id', 'assessment_id'])
            ->where('status', BlitzStatus::Active->value)
            ->whereExists(fn (Builder $query) => $query
                ->selectRaw('1')
                ->from('assessment_attempts')
                ->whereColumn('assessment_attempts.institution_id', 'blitz_tasks.institution_id')
                ->whereColumn('assessment_attempts.assessment_id', 'blitz_tasks.assessment_id')
                ->where('assessment_attempts.status', AssessmentAttemptStatus::InProgress->value)
                ->where('assessment_attempts.deadline_at', '<=', $scanNow))
            ->lazyById(100, 'assessment_id');

        foreach ($candidates as $blitz) {
            $counts['candidates']++;

            try {
                $counts['finalized_attempts'] += ($this->finalizeTimeouts)(
                    $blitz->institution_id,
                    $blitz->assessment_id,
                );
            } catch (Throwable $exception) {
                report($exception);
                $counts['failures']++;
            }
        }

        return $counts;
    }
}
