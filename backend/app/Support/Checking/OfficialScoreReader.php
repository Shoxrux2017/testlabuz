<?php

namespace App\Support\Checking;

use App\Domain\Assessment\Checking\CheckingScoreMath;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\OfficialScoreStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\OfficialTaskScore;
use Illuminate\Database\Eloquent\Collection;

/**
 * Reads one Student's official task score (docs/09 §24.1 Status). The persisted row counts only
 * while a live evaluation of the Attempts yields the same Attempt and score, because between a
 * freeze and its checking run the row can still show the previous result.
 *
 * The read takes no locks and reads in several statements; a Blitz read needs the caller's
 * snapshot transaction, because its Attempts and exception must come from one state.
 */
final class OfficialScoreReader
{
    private const AWAITING_AUTOMATIC_CHECKING = [AssessmentAttemptStatus::Submitted, AssessmentAttemptStatus::TimedOutFinalized];

    public function __construct(
        private readonly OfficialTaskDesignation $designation,
        private readonly OfficialScoreEvaluator $evaluator,
        private readonly CheckingScoreMath $math,
    ) {}

    public function read(Assessment $assessment, AssessmentStudent $recipient): OfficialScoreReading
    {
        if (! $this->designation->isOfficial($assessment)) {
            return OfficialScoreReading::notReady($assessment, $recipient, OfficialScoreStatus::NotApplicable);
        }

        $attempts = AssessmentAttempt::query()
            ->where('institution_id', $assessment->institution_id)
            ->where('assessment_student_id', $recipient->id)
            ->get();
        $score = OfficialTaskScore::query()
            ->where('institution_id', $assessment->institution_id)
            ->where('assessment_id', $assessment->id)
            ->where('student_id', $recipient->student_id)
            ->first();
        [$exception, $blitzStatus] = $assessment->type === AssessmentType::Blitz ? [
            BlitzAttemptException::query()
                ->where('institution_id', $assessment->institution_id)
                ->where('assessment_id', $assessment->id)
                ->where('assessment_student_id', $recipient->id)
                ->first(),
            BlitzTask::query()
                ->select(['assessment_id', 'institution_id', 'status'])
                ->where('institution_id', $assessment->institution_id)
                ->whereKey($assessment->id)
                ->first()?->status,
        ] : [null, null];

        return $this->readLoaded($assessment, $recipient, $attempts, $score, $exception, $blitzStatus);
    }

    /**
     * The same read from preloaded data, for readers of many recipients of an official task: the
     * recipient's Attempts (with the answers of waiting Attempts loaded), official row, Blitz
     * exception and Blitz status.
     *
     * @param  Collection<int, AssessmentAttempt>  $attempts
     */
    public function readLoaded(
        Assessment $assessment,
        AssessmentStudent $recipient,
        Collection $attempts,
        ?OfficialTaskScore $score,
        ?BlitzAttemptException $exception,
        ?BlitzStatus $blitzStatus,
    ): OfficialScoreReading {
        $evaluation = $this->evaluator->evaluateLoaded($assessment, $recipient, $attempts, $exception);
        $official = $evaluation->official;

        if ($official !== null && $this->confirms($score, $evaluation)) {
            return OfficialScoreReading::ready($assessment, $recipient, $score, $official);
        }

        $blocking = collect($evaluation->blocking);
        $status = match (true) {
            $assessment->type === AssessmentType::Blitz && $this->waitsForReplacement($attempts, $exception, $blitzStatus) => OfficialScoreStatus::WaitingForReplacement,
            $blocking->contains(fn (AssessmentAttempt $attempt): bool => in_array($attempt->status, self::AWAITING_AUTOMATIC_CHECKING, true)) => OfficialScoreStatus::AutomaticCheckingPending,
            $blocking->contains(fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::WaitingForTeacherReview) => OfficialScoreStatus::WaitingForTeacherReview,
            // Ready by the live rule, but the row is missing or stale until the sweep repairs it.
            $official !== null => OfficialScoreStatus::AutomaticCheckingPending,
            default => OfficialScoreStatus::NoCompletedAttempt,
        };

        return OfficialScoreReading::notReady($assessment, $recipient, $status);
    }

    /**
     * The stored row is the official score only while the live evaluation is ready with the same
     * Attempt and score (the sweep's definition of a differing row).
     */
    public function confirms(?OfficialTaskScore $score, OfficialScoreEvaluation $evaluation): bool
    {
        $official = $evaluation->official;

        return $official !== null && $score !== null && $score->official_attempt_id === $official->id
            && $this->math->compare((string) $score->normalized_score, (string) $official->normalized_score) === 0;
    }

    /**
     * An approved exception invalidated Attempt #1 and the Blitz is still active, so the Student
     * can still take (or is taking) replacement #2.
     *
     * @param  Collection<int, AssessmentAttempt>  $attempts
     */
    private function waitsForReplacement(Collection $attempts, ?BlitzAttemptException $exception, ?BlitzStatus $blitzStatus): bool
    {
        $replacement = $attempts->firstWhere('attempt_number', 2);

        if ($replacement instanceof AssessmentAttempt && $replacement->status !== AssessmentAttemptStatus::InProgress) {
            return false;
        }

        return $exception !== null && $blitzStatus === BlitzStatus::Active;
    }
}
