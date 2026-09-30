<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Domain\Assessment\Checking\CheckingScoreMath;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Exceptions\Teacher\AutomaticCheckingPendingException;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Question;
use App\Models\User;
use App\Support\Checking\OfficialTaskScoreResolver;
use App\Support\Checking\RecipientScoringLock;
use App\Support\Teacher\TeacherSubmissionAccess;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;
use LogicException;

/**
 * Saves a Teacher's points and feedback for some or all manual answers of one submission, or
 * corrects them (docs/09 §23.1–§23.2). Recalculates the Attempt and re-resolves the official
 * score in the transaction that holds the Student's scoring locks.
 */
final class ReviewTeacherSubmission
{
    private const AWAITING_AUTOMATIC_CHECKING = [AssessmentAttemptStatus::Submitted, AssessmentAttemptStatus::TimedOutFinalized];

    private const MANUAL_REVIEW = [AttemptAnswerCheckingStatus::WaitingForTeacherReview, AttemptAnswerCheckingStatus::TeacherChecked];

    public function __construct(
        private readonly TeacherSubmissionAccess $access,
        private readonly RecipientScoringLock $scoringLock,
        private readonly OfficialTaskScoreResolver $officialScores,
        private readonly CheckingScoreMath $math,
        private readonly ShowTeacherSubmission $showTeacherSubmission,
    ) {}

    /**
     * Returns the submission detail as committed.
     *
     * @param  list<array{answer_id: string, awarded_points: int|float, feedback: ?string}>  $items
     */
    public function __invoke(User $teacher, string $submissionId, array $items): AssessmentAttempt
    {
        $submission = $this->access->resolve($teacher, $submissionId);
        $this->assertCheckedAutomatically($submission);
        $this->reviewedPoints($items, $this->answers($submission, lock: false), $this->questionPoints($submission));

        DB::transaction(function () use ($teacher, $submissionId, $submission, $items): void {
            $locked = $this->scoringLock->lock($submission->institution_id, $submission->assessment_id, $submission->assessment_student_id);
            $answers = $this->answers($submission, lock: true);
            // Access, state and items again, as they stand under the locks (docs/09 §34.7).
            $this->access->resolve($teacher, $submissionId);
            $attempt = $locked->attempts->firstWhere('id', $submission->id);

            if (! $attempt instanceof AssessmentAttempt) {
                throw new LogicException('A reviewed submission does not belong to its recipient.');
            }

            $this->assertCheckedAutomatically($attempt);
            $reviewedPoints = $this->reviewedPoints($items, $answers, $this->questionPoints($attempt));
            $reviewedAt = now();
            $this->writeReviews($teacher, $attempt, $items, $reviewedPoints, $reviewedAt);
            $this->scoreAttempt($attempt, $answers, $reviewedPoints, $reviewedAt);
            $this->officialScores->resolve($locked->assessment, $locked->recipient, $locked->attempts, $reviewedAt);
        });

        return ($this->showTeacherSubmission)($teacher, $submissionId);
    }

    private function assertCheckedAutomatically(AssessmentAttempt $attempt): void
    {
        if (in_array($attempt->status, self::AWAITING_AUTOMATIC_CHECKING, true)) {
            throw new AutomaticCheckingPendingException;
        }
    }

    /** @return Collection<string, AttemptAnswer> Keyed by id */
    private function answers(AssessmentAttempt $submission, bool $lock): Collection
    {
        return AttemptAnswer::query()
            ->select(['id', 'institution_id', 'attempt_id', 'question_id', 'checking_status', 'awarded_points'])
            ->where('institution_id', $submission->institution_id)
            ->where('attempt_id', $submission->id)
            ->orderBy('id')
            ->when($lock, fn ($query) => $query->lockForUpdate())
            ->get()
            ->keyBy('id');
    }

    /** @return array<string, string> Question points by Question id */
    private function questionPoints(AssessmentAttempt $submission): array
    {
        return Question::query()
            ->select(['id', 'points'])
            ->where('institution_id', $submission->institution_id)
            ->where('assessment_id', $submission->assessment_id)
            ->get()
            ->mapWithKeys(fn (Question $question): array => [$question->id => (string) $question->points])
            ->all();
    }

    /**
     * Step 4 of docs/09 §23.1: every item names a manual-review answer of this submission and
     * awards 0 to its Question points under the Question points number rule. All item errors
     * are reported together.
     *
     * @param  list<array{answer_id: string, awarded_points: int|float, feedback: ?string}>  $items
     * @param  Collection<string, AttemptAnswer>  $answers
     * @param  array<string, string>  $questionPoints
     * @return array<string, string> The normalized awarded points by answer id
     */
    private function reviewedPoints(array $items, Collection $answers, array $questionPoints): array
    {
        $errors = [];
        $reviewedPoints = [];

        foreach ($items as $index => $item) {
            $answer = $answers->get($item['answer_id']);

            if (! $answer instanceof AttemptAnswer || ! in_array($answer->checking_status, self::MANUAL_REVIEW, true)) {
                $errors["answers.{$index}.answer_id"] = 'The answer is not a manual-review answer of this submission.';
                $answer = null;
            }

            try {
                $points = AssessmentPointMath::normalize($item['awarded_points']);
            } catch (InvalidArgumentException) {
                $errors["answers.{$index}.awarded_points"] = 'The awarded points must be a non-negative number with at most six fractional digits.';

                continue;
            }

            if ($answer === null) {
                continue;
            }

            $maximum = $questionPoints[$answer->question_id]
                ?? throw new LogicException('A submitted answer belongs to no Question of its Assessment.');

            if ($this->math->compare($points, $maximum) > 0) {
                $errors["answers.{$index}.awarded_points"] = 'The awarded points must not exceed the Question points.';

                continue;
            }

            $reviewedPoints[$answer->id] = $points;
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $reviewedPoints;
    }

    /**
     * The query builder keeps attempt_answers.updated_at: Student reads show it as the
     * answer's last save.
     *
     * @param  list<array{answer_id: string, awarded_points: int|float, feedback: ?string}>  $items
     * @param  array<string, string>  $reviewedPoints
     */
    private function writeReviews(User $teacher, AssessmentAttempt $attempt, array $items, array $reviewedPoints, CarbonInterface $reviewedAt): void
    {
        foreach ($items as $item) {
            DB::table('attempt_answers')
                ->where('institution_id', $attempt->institution_id)
                ->where('attempt_id', $attempt->id)
                ->where('id', $item['answer_id'])
                ->update([
                    'checking_status' => AttemptAnswerCheckingStatus::TeacherChecked->value,
                    'awarded_points' => $reviewedPoints[$item['answer_id']],
                    'feedback' => $item['feedback'],
                    'checked_by_user_id' => $teacher->id,
                    'checked_at' => $reviewedAt,
                ]);
        }
    }

    /**
     * @param  Collection<string, AttemptAnswer>  $answers  As locked before this save
     * @param  array<string, string>  $reviewedPoints
     */
    private function scoreAttempt(AssessmentAttempt $attempt, Collection $answers, array $reviewedPoints, CarbonInterface $reviewedAt): void
    {
        $awardedPoints = [];
        $waiting = false;

        foreach ($answers as $answer) {
            if (array_key_exists($answer->id, $reviewedPoints)) {
                $awardedPoints[] = $reviewedPoints[$answer->id];
            } elseif ($answer->checking_status === AttemptAnswerCheckingStatus::WaitingForTeacherReview) {
                $waiting = true;
            } elseif ($answer->checking_status === AttemptAnswerCheckingStatus::Pending) {
                throw new LogicException('An automatically checked submission has an unchecked answer.');
            } else {
                $awardedPoints[] = (string) $answer->awarded_points;
            }
        }

        if ($waiting) {
            $attempt->status = AssessmentAttemptStatus::WaitingForTeacherReview;
            $attempt->earned_points = null;
            $attempt->normalized_score = null;
            $attempt->scoring_completed_at = null;
        } else {
            $earnedPoints = $this->math->sum($awardedPoints);
            $attempt->status = AssessmentAttemptStatus::Checked;
            $attempt->earned_points = $earnedPoints;
            $attempt->normalized_score = $this->math->normalizedScore($earnedPoints, (string) $attempt->possible_points);
            $attempt->scoring_completed_at = $reviewedAt;
        }

        $attempt->updated_at = $reviewedAt;
        $attempt->save();
    }
}
