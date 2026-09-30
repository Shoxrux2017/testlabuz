<?php

namespace App\Support\Checking;

use App\Models\Assessment;
use App\Models\TopicResultPair;

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
}
