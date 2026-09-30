<?php

namespace App\Support\Checking;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\OfficialTaskScore;
use App\Models\TopicResultPair;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;

/**
 * Keeps a Student's official_task_scores row equal to the live evaluation: the row exists
 * exactly while the official score is ready, and only for the Topic pair's Homework and Blitz.
 */
final class OfficialTaskScoreResolver
{
    public function __construct(private readonly OfficialScoreEvaluator $evaluator) {}

    /**
     * The caller holds the Student's scoring locks (S09-DOC-001 §8) and passes all of the
     * recipient's Attempts as locked and changed in its transaction. Returns true when it wrote.
     *
     * @param  Collection<int, AssessmentAttempt>  $attempts
     */
    public function resolve(Assessment $assessment, AssessmentStudent $recipient, Collection $attempts, CarbonInterface $resolvedAt): bool
    {
        if (! $this->isOfficial($assessment)) {
            return false;
        }

        // The official row is the last lock of the scoring order.
        $row = OfficialTaskScore::query()
            ->where('institution_id', $assessment->institution_id)
            ->where('assessment_id', $assessment->id)
            ->where('student_id', $recipient->student_id)
            ->lockForUpdate()
            ->first();
        $evaluation = $this->evaluator->evaluate($assessment, $recipient, $attempts);
        $official = $evaluation->official;

        if ($official === null) {
            return $row?->delete() ?? false;
        }

        $score = (string) $official->normalized_score;

        if ($row === null) {
            $row = new OfficialTaskScore([
                'institution_id' => $assessment->institution_id,
                'assessment_id' => $assessment->id,
                'student_id' => $recipient->student_id,
                'selected_by_user_id' => null,
            ]);
            $row->created_at = $resolvedAt;
        }

        if ($row->official_attempt_id !== $official->id || $row->normalized_score !== $score) {
            $row->official_attempt_id = $official->id;
            $row->normalized_score = $score;
            $row->selected_at = $resolvedAt;
        }

        $row->selection_policy_code = $evaluation->policy;

        if (! $row->isDirty()) {
            return false;
        }

        $row->updated_at = $resolvedAt;

        return $row->save();
    }

    private function isOfficial(Assessment $assessment): bool
    {
        return TopicResultPair::query()
            ->where('institution_id', $assessment->institution_id)
            ->where('topic_id', $assessment->topic_id)
            ->where(fn ($query) => $query->where('homework_assessment_id', $assessment->id)
                ->orWhere('blitz_assessment_id', $assessment->id))
            ->exists();
    }
}
