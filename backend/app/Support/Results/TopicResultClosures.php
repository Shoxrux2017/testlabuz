<?php

namespace App\Support\Results;

use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultOutcome;
use App\Models\AssessmentAttempt;
use App\Models\Topic;
use App\Models\TopicResult;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonInterface;

/**
 * Closure of Topic results (docs/09 §25.8-25.10), run inside the caller's Topic lock. The official
 * Attempts of the affected Students are locked FOR SHARE first, in one query in id order, because the
 * Homework deadline and Blitz timeout finalizers lock Attempts without the Topic; the results are then
 * computed live and each closable one is frozen into its snapshot (docs/09 §25.8). A closed result is
 * never written again.
 */
final class TopicResultClosures
{
    public function __construct(private readonly TopicResultReader $reader) {}

    /**
     * Whether the Student's Topic result is closed (the `result_closed` guards, docs/09 §25.11). The
     * caller holds the Topic lock, shared or exclusive, so a closure cannot commit in between.
     */
    public function isClosed(string $institutionId, string $topicId, string $studentId): bool
    {
        return TopicResult::query()
            ->where('institution_id', $institutionId)
            ->where('topic_id', $topicId)
            ->where('student_id', $studentId)
            ->whereNotNull('closed_at')
            ->exists();
    }

    /**
     * The Student's outcome, or null when the Student is not in the Topic's cohort. The closure
     * instant is taken after the Attempt lock wait, like every other decision instant.
     */
    public function closeOne(User $teacher, Topic $locked, string $studentId): ?TopicResultActionOutcome
    {
        $this->lockOfficialAttempts($locked, $studentId);
        $result = $this->reader->forStudent($locked, $studentId);

        return $result === null ? null : $this->close($teacher, $locked, [$result], TopicResultClosureReason::Teacher, now())[0];
    }

    /**
     * Every cohort result: closed by the Teacher (closable results) or at Topic archive (every
     * terminal result, since no further work is possible, docs/09 §25.3).
     *
     * @param  ?CarbonInterface  $closedAt  The archive's own transition instant; otherwise taken after the Attempt lock wait
     * @return list<TopicResultActionOutcome>
     */
    public function closeAll(User $actor, Topic $locked, TopicResultClosureReason $reason, ?CarbonInterface $closedAt = null): array
    {
        $this->lockOfficialAttempts($locked, null);

        return $this->close($actor, $locked, $this->reader->forTopic($locked), $reason, $closedAt ?? now());
    }

    /**
     * @param  list<TopicResultView>  $results
     * @return list<TopicResultActionOutcome>
     */
    private function close(User $actor, Topic $locked, array $results, TopicResultClosureReason $reason, CarbonInterface $closedAt): array
    {
        $rows = TopicResult::query()
            ->where('institution_id', $locked->institution_id)
            ->where('topic_id', $locked->id)
            ->whereIn('student_id', array_map(fn (TopicResultView $result): string => $result->student->id, $results))
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('student_id');

        return array_map(function (TopicResultView $result) use ($actor, $locked, $rows, $reason, $closedAt): TopicResultActionOutcome {
            $row = $rows->get($result->student->id);

            if ($row?->closed_at !== null) {
                return TopicResultActionOutcome::AlreadyDone;
            }

            if (! ($reason === TopicResultClosureReason::TopicArchived ? $result->terminal : $result->closable)) {
                return TopicResultActionOutcome::NotReady;
            }

            ($row ?? new TopicResult([
                'institution_id' => $locked->institution_id,
                'topic_id' => $locked->id,
                'student_id' => $result->student->id,
            ]))->fill($this->snapshot($result, $actor, $reason, $closedAt))->save();

            return TopicResultActionOutcome::Done;
        }, $results);
    }

    /** @return array<string, mixed> */
    private function snapshot(TopicResultView $result, User $actor, TopicResultClosureReason $reason, CarbonInterface $closedAt): array
    {
        return [
            'closed_at' => $closedAt,
            'closed_by_user_id' => $actor->id,
            'closure_reason' => $reason,
            'closed_outcome' => TopicResultOutcome::from($result->status->value),
            'missing_component' => $result->missingComponent,
            'homework_assessment_id' => $result->homework->assessmentId,
            'blitz_assessment_id' => $result->blitz->assessmentId,
            'homework_state' => $result->homework->state,
            'blitz_state' => $result->blitz->state,
            'homework_attempt_id' => $result->homework->attemptId,
            'homework_score' => $result->homework->score,
            'blitz_attempt_id' => $result->blitz->attemptId,
            'blitz_score' => $result->blitz->score,
            'score_difference' => $result->difference,
            'acceptable_difference_used' => $result->threshold,
            'calculation_method' => $result->method,
            'consistency' => $result->consistency,
            'final_score' => $result->finalScore,
            'category_score' => $result->categoryScore,
            'category_code' => $result->category,
            'category_min_score_used' => $result->categoryMinScore,
            'category_max_score_used' => $result->categoryMaxScore,
        ];
    }

    private function lockOfficialAttempts(Topic $locked, ?string $studentId): void
    {
        $pair = TopicResultPair::query()
            ->select(['id', 'institution_id', 'topic_id', 'homework_assessment_id', 'blitz_assessment_id'])
            ->where('institution_id', $locked->institution_id)
            ->where('topic_id', $locked->id)
            ->first();

        if ($pair === null) {
            return;
        }

        AssessmentAttempt::query()
            ->where('institution_id', $locked->institution_id)
            ->whereIn('assessment_id', array_values(array_filter([$pair->homework_assessment_id, $pair->blitz_assessment_id])))
            ->when($studentId !== null, fn ($query) => $query->where('student_id', $studentId))
            ->orderBy('id')
            ->sharedLock()
            ->pluck('id');
    }
}
