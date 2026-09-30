<?php

namespace App\Actions\Checking;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Support\Checking\OfficialScoreEvaluator;
use App\Support\Checking\OfficialTaskScoreResolver;
use App\Support\Checking\RecipientScoringLock;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * The sweep's official-score repair (BR-ATT-021): re-resolves every official-task Student who
 * has a checked eligible Attempt and no pending eligible one, but whose stored row is missing
 * or differs from the best checked eligible Attempt. Such a state should not exist; a pending
 * Attempt is left to the writer that checks or reviews it.
 */
final class RepairOfficialTaskScores
{
    public function __construct(
        private readonly RecipientScoringLock $scoringLock,
        private readonly OfficialTaskScoreResolver $officialScores,
    ) {}

    /** @return array{repaired: int, failures: int} */
    public function __invoke(): array
    {
        $counts = ['repaired' => 0, 'failures' => 0];

        // Materialized first: every repair removes its Student from the candidate set.
        foreach ($this->candidates()->get() as $candidate) {
            try {
                $repaired = DB::transaction(function () use ($candidate): bool {
                    $locked = $this->scoringLock->lock($candidate->institution_id, $candidate->assessment_id, $candidate->assessment_student_id);

                    return $this->officialScores->resolve($locked->assessment, $locked->recipient, $locked->attempts, now());
                });

                if ($repaired) {
                    $counts['repaired']++;
                }
            } catch (Throwable $exception) {
                report($exception);
                $counts['failures']++;
            }
        }

        return $counts;
    }

    private function candidates(): Builder
    {
        $pending = array_map(fn (AssessmentAttemptStatus $status): string => $status->value, OfficialScoreEvaluator::PENDING);
        // Each official recipient's best checked eligible Attempt: highest score, then lowest number.
        $best = AssessmentAttempt::query()->toBase()
            ->selectRaw('distinct on (assessment_student_id) institution_id, assessment_id, assessment_student_id, student_id, id, normalized_score')
            ->where('official_score_eligible', true)
            ->where('status', AssessmentAttemptStatus::Checked->value)
            ->whereExists(fn (Builder $query) => $query->selectRaw('1')->from('topic_result_pairs')
                ->whereColumn('topic_result_pairs.institution_id', 'assessment_attempts.institution_id')
                ->where(fn (Builder $pair) => $pair
                    ->whereColumn('topic_result_pairs.homework_assessment_id', 'assessment_attempts.assessment_id')
                    ->orWhereColumn('topic_result_pairs.blitz_assessment_id', 'assessment_attempts.assessment_id')))
            ->whereNotExists(fn (Builder $query) => $query->selectRaw('1')->from('assessment_attempts as pending')
                ->whereColumn('pending.institution_id', 'assessment_attempts.institution_id')
                ->whereColumn('pending.assessment_student_id', 'assessment_attempts.assessment_student_id')
                ->where('pending.official_score_eligible', true)
                ->whereIn('pending.status', $pending))
            ->orderBy('assessment_student_id')
            ->orderByDesc('normalized_score')
            ->orderBy('attempt_number')
            ->orderBy('id');

        return DB::query()->fromSub($best, 'best')
            ->leftJoin('official_task_scores as official', fn ($join) => $join
                ->on('official.institution_id', '=', 'best.institution_id')
                ->on('official.assessment_id', '=', 'best.assessment_id')
                ->on('official.student_id', '=', 'best.student_id'))
            ->where(fn (Builder $query) => $query->whereNull('official.id')
                ->orWhereColumn('official.official_attempt_id', '<>', 'best.id')
                ->orWhereColumn('official.normalized_score', '<>', 'best.normalized_score'))
            ->select(['best.institution_id', 'best.assessment_id', 'best.assessment_student_id'])
            ->orderBy('best.assessment_student_id');
    }
}
