<?php

namespace App\Support\Checking;

use App\Domain\Assessment\Checking\CheckingScoreMath;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\OfficialScoreSelectionPolicy;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzAttemptException;
use App\Models\Question;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

/**
 * Evaluates the S09-DOC-001 §8 official-score rules for one Student of one task from the
 * recipient's Attempts: the Homework "could overtake" wait and the Blitz normal/replacement rule.
 */
final class OfficialScoreEvaluator
{
    /** Terminal statuses that are not checked yet: the Attempt may still change the official score. */
    public const PENDING = [
        AssessmentAttemptStatus::Submitted,
        AssessmentAttemptStatus::TimedOutFinalized,
        AssessmentAttemptStatus::WaitingForTeacherReview,
    ];

    private const FULL_BOUND = '100.00000000';

    public function __construct(private readonly CheckingScoreMath $math) {}

    /** @param Collection<int, AssessmentAttempt> $attempts All of the recipient's Attempts */
    public function evaluate(Assessment $assessment, AssessmentStudent $recipient, Collection $attempts): OfficialScoreEvaluation
    {
        if ($recipient->assessment_id !== $assessment->id) {
            throw new LogicException('An official score is evaluated for a recipient of its own task.');
        }

        foreach ($attempts as $attempt) {
            if ($attempt->institution_id !== $assessment->institution_id || $attempt->assessment_id !== $assessment->id
                || $attempt->assessment_student_id !== $recipient->id || $attempt->student_id !== $recipient->student_id) {
                throw new LogicException('An official score is evaluated from the recipient\'s own Attempts only.');
            }
        }

        $attempts = $attempts->sortBy([['attempt_number', 'asc'], ['id', 'asc']])->values();

        return match ($assessment->type) {
            AssessmentType::Homework => $this->homework($attempts),
            AssessmentType::Blitz => $this->blitz($assessment, $recipient, $attempts),
        };
    }

    /** @param Collection<int, AssessmentAttempt> $attempts */
    private function homework(Collection $attempts): OfficialScoreEvaluation
    {
        if ($attempts->contains(fn (AssessmentAttempt $attempt): bool => ! $attempt->official_score_eligible)) {
            throw new LogicException('Every Homework Attempt counts towards the official score.');
        }

        $checked = $attempts->filter(fn (AssessmentAttempt $attempt): bool => $this->scored($attempt));
        $pending = $attempts->filter(fn (AssessmentAttempt $attempt): bool => in_array($attempt->status, self::PENDING, true));

        if ($checked->isEmpty()) {
            return OfficialScoreEvaluation::notReady($pending->values()->all());
        }

        // Highest score first; equal scores keep attempt-number order (the sort is stable).
        $best = $checked->sort(fn (AssessmentAttempt $left, AssessmentAttempt $right): int => $this->math
            ->compare((string) $right->normalized_score, (string) $left->normalized_score))->first();
        $bounds = $this->upperBounds($pending);
        $overtaking = $pending->filter(function (AssessmentAttempt $attempt) use ($best, $bounds): bool {
            $comparison = $this->math->compare($bounds[$attempt->id], (string) $best->normalized_score);

            return $comparison > 0 || ($comparison === 0 && $attempt->attempt_number < $best->attempt_number);
        });

        return $overtaking->isEmpty()
            ? OfficialScoreEvaluation::ready($best, OfficialScoreSelectionPolicy::HighestValidCompleted)
            : OfficialScoreEvaluation::notReady($overtaking->values()->all());
    }

    /**
     * The best score each pending Attempt could still reach: full marks until it is checked
     * automatically, then its awarded points plus the full points of every waiting answer.
     *
     * @param  Collection<int, AssessmentAttempt>  $pending
     * @return array<string, string>
     */
    private function upperBounds(Collection $pending): array
    {
        $waiting = $pending->filter(fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::WaitingForTeacherReview);
        $points = [];

        if ($waiting->isNotEmpty()) {
            $institutionId = $waiting->first()->institution_id;
            $answers = AttemptAnswer::query()
                ->select(['id', 'institution_id', 'attempt_id', 'question_id', 'checking_status', 'awarded_points'])
                ->where('institution_id', $institutionId)
                ->whereIn('attempt_id', $waiting->pluck('id'))
                ->with(['question' => fn ($query) => $query->select(['id', 'institution_id', 'points'])->where('institution_id', $institutionId)])
                ->get();

            foreach ($answers as $answer) {
                $points[$answer->attempt_id][] = $this->bestPoints($answer);
            }
        }

        return $pending->mapWithKeys(fn (AssessmentAttempt $attempt): array => [
            $attempt->id => $attempt->status === AssessmentAttemptStatus::WaitingForTeacherReview
                ? $this->math->normalizedScore($this->math->sum($points[$attempt->id] ?? []), (string) $attempt->possible_points)
                : self::FULL_BOUND,
        ])->all();
    }

    private function bestPoints(AttemptAnswer $answer): string
    {
        $question = $answer->getRelation('question');

        return match ($answer->checking_status) {
            AttemptAnswerCheckingStatus::AutoChecked, AttemptAnswerCheckingStatus::TeacherChecked => $answer->awarded_points
                ?? throw new LogicException('A checked answer has no awarded points.'),
            AttemptAnswerCheckingStatus::WaitingForTeacherReview => $question instanceof Question
                ? (string) $question->points : throw new LogicException('A waiting answer lost its Question.'),
            AttemptAnswerCheckingStatus::Pending => throw new LogicException('A waiting Attempt still has an unchecked answer.'),
        };
    }

    /** @param Collection<int, AssessmentAttempt> $attempts */
    private function blitz(Assessment $assessment, AssessmentStudent $recipient, Collection $attempts): OfficialScoreEvaluation
    {
        if ($attempts->pluck('attempt_number')->all() !== array_slice([1, 2], 0, $attempts->count())) {
            throw new LogicException('A Blitz history holds normal Attempt #1 and at most replacement #2.');
        }

        [$normal, $replacement] = [$attempts->get(0), $attempts->get(1)];
        $exception = BlitzAttemptException::query()
            ->select(['id', 'institution_id', 'assessment_id', 'assessment_student_id', 'invalidated_attempt_id', 'replacement_attempt_id'])
            ->where('institution_id', $assessment->institution_id)
            ->where('assessment_id', $assessment->id)
            ->where('assessment_student_id', $recipient->id)
            ->first();

        if ($exception === null) {
            if ($replacement !== null || ($normal !== null && ! $normal->official_score_eligible)) {
                throw new LogicException('A replacement or an invalidated normal Attempt requires a Blitz exception.');
            }

            return $this->blitzCandidate($normal, OfficialScoreSelectionPolicy::ValidNormalBlitz);
        }

        if ($normal === null || $normal->official_score_eligible || $exception->invalidated_attempt_id !== $normal->id
            || $exception->replacement_attempt_id !== $replacement?->id
            || ($replacement !== null && ! $replacement->official_score_eligible)) {
            throw new LogicException('A Blitz exception must link the invalidated normal and the optional replacement Attempt.');
        }

        return $this->blitzCandidate($replacement, OfficialScoreSelectionPolicy::ApprovedBlitzExceptionReplacement);
    }

    private function blitzCandidate(?AssessmentAttempt $candidate, OfficialScoreSelectionPolicy $policy): OfficialScoreEvaluation
    {
        if ($candidate === null || $candidate->status === AssessmentAttemptStatus::InProgress) {
            return OfficialScoreEvaluation::notReady([]);
        }

        return $this->scored($candidate)
            ? OfficialScoreEvaluation::ready($candidate, $policy)
            : OfficialScoreEvaluation::notReady([$candidate]);
    }

    private function scored(AssessmentAttempt $attempt): bool
    {
        if ($attempt->status !== AssessmentAttemptStatus::Checked) {
            return false;
        }

        if ($attempt->normalized_score === null) {
            throw new LogicException('A checked Attempt has no normalized score.');
        }

        return true;
    }
}
