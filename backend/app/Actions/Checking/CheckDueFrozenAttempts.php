<?php

namespace App\Actions\Checking;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use Throwable;

/**
 * The scheduled sweep: checks every Attempt still frozen, including history frozen
 * before Stage 9, one isolated transaction per Attempt.
 */
final class CheckDueFrozenAttempts
{
    public function __construct(private readonly CheckFrozenAttempt $checkFrozenAttempt) {}

    /** @return array{candidates: int, checked_attempts: int, failures: int} */
    public function __invoke(): array
    {
        $counts = ['candidates' => 0, 'checked_attempts' => 0, 'failures' => 0];
        $candidates = AssessmentAttempt::query()
            ->select(['id'])
            ->whereIn('status', [AssessmentAttemptStatus::Submitted->value, AssessmentAttemptStatus::TimedOutFinalized->value])
            ->lazyById(100);

        foreach ($candidates as $attempt) {
            $counts['candidates']++;

            try {
                if (($this->checkFrozenAttempt)($attempt->id)) {
                    $counts['checked_attempts']++;
                }
            } catch (Throwable $exception) {
                report($exception);
                $counts['failures']++;
            }
        }

        return $counts;
    }
}
