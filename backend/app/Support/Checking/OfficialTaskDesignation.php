<?php

namespace App\Support\Checking;

use App\Models\Assessment;
use App\Models\TopicResultPair;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/** Whether a task is the Homework or the Blitz of its Topic result pair, the only tasks with an official score. */
final class OfficialTaskDesignation
{
    public function isOfficial(Assessment $assessment): bool
    {
        return TopicResultPair::query()
            ->where('institution_id', $assessment->institution_id)
            ->where('topic_id', $assessment->topic_id)
            ->where(fn ($query) => $query->where('homework_assessment_id', $assessment->id)
                ->orWhere('blitz_assessment_id', $assessment->id))
            ->exists();
    }

    /**
     * The same rule for many tasks of one Institution in one query.
     *
     * @param  Collection<int, Assessment>  $assessments
     * @return list<string> The ids of the official tasks
     */
    public function officialIds(string $institutionId, Collection $assessments): array
    {
        if ($assessments->isEmpty()) {
            return [];
        }

        $topics = $assessments->mapWithKeys(fn (Assessment $assessment): array => [$assessment->id => $assessment->topic_id]);
        $pairs = TopicResultPair::query()
            ->select(['topic_id', 'homework_assessment_id', 'blitz_assessment_id'])
            ->where('institution_id', $institutionId)
            ->whereIn('topic_id', $topics->unique()->values())
            ->where(fn ($query) => $query->whereIn('homework_assessment_id', $topics->keys())
                ->orWhereIn('blitz_assessment_id', $topics->keys()))
            ->get();

        return $topics->keys()->filter(fn (string $id): bool => $pairs->contains(fn (TopicResultPair $pair): bool => $pair->topic_id === $topics[$id]
            && ($pair->homework_assessment_id === $id || $pair->blitz_assessment_id === $id)))->values()->all();
    }

    /**
     * The same rule as one uncorrelated set of `(institution_id, assessment_id)` rows over every
     * Institution, which a planner can hash instead of probing the pairs per row. A pair's tasks
     * belong to its Topic (same-Topic foreign keys), so no Topic filter is needed.
     */
    public function officialTaskKeys(): Builder
    {
        return DB::query()->select(['institution_id', 'homework_assessment_id'])->from('topic_result_pairs')
            ->unionAll(DB::query()->select(['institution_id', 'blitz_assessment_id'])->from('topic_result_pairs')
                ->whereNotNull('blitz_assessment_id'));
    }
}
