<?php

namespace App\Actions\Checking;

use App\Domain\Assessment\Checking\AnswerCheckingRoute;
use App\Domain\Assessment\Checking\CheckingScoreMath;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Question;
use App\Support\Checking\CheckingAnswerKeys;
use App\Support\Checking\OfficialTaskScoreResolver;
use App\Support\Checking\RecipientScoringLock;
use App\Support\Student\StudentHomeworkAnswerIntegrity;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;
use LogicException;

/**
 * Checks one frozen Attempt: routes every answer, awards automatic points, sends
 * manual answers to Teacher review, scores the Attempt when nothing waits and
 * re-resolves the Student's official score.
 */
final class CheckFrozenAttempt
{
    private const FROZEN = [AssessmentAttemptStatus::Submitted, AssessmentAttemptStatus::TimedOutFinalized];

    public function __construct(
        private readonly StudentHomeworkAnswerIntegrity $integrity,
        private readonly CheckingAnswerKeys $keys,
        private readonly CheckingScoreMath $math,
        private readonly RecipientScoringLock $scoringLock,
        private readonly OfficialTaskScoreResolver $officialScores,
    ) {}

    /** Returns true when this run checked the Attempt; a missing or no longer frozen Attempt is a no-op. */
    public function __invoke(string $attemptId): bool
    {
        $preliminary = AssessmentAttempt::query()
            ->select(['id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id', 'status'])
            ->whereKey($attemptId)
            ->first();

        if (! $preliminary instanceof AssessmentAttempt || ! in_array($preliminary->status, self::FROZEN, true)) {
            return false;
        }

        return DB::transaction(fn (): bool => $this->checkLocked($preliminary));
    }

    private function checkLocked(AssessmentAttempt $preliminary): bool
    {
        $locked = $this->scoringLock->lock($preliminary->institution_id, $preliminary->assessment_id, $preliminary->assessment_student_id);
        $attempt = $locked->attempts->firstWhere('id', $preliminary->id);

        if (! $attempt instanceof AssessmentAttempt || $locked->recipient->student_id !== $preliminary->student_id) {
            throw new LogicException('A frozen Attempt does not belong to its recipient.');
        }

        if (! in_array($attempt->status, self::FROZEN, true)) {
            return false;
        }

        $institutionId = $attempt->institution_id;
        $answers = AttemptAnswer::query()
            ->where('institution_id', $institutionId)
            ->where('attempt_id', $attempt->id)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
        $questions = Question::query()
            ->select(['id', 'institution_id', 'assessment_id', 'type', 'checking_mode', 'points'])
            ->where('institution_id', $institutionId)
            ->where('assessment_id', $attempt->assessment_id)
            ->orderBy('position')
            ->orderBy('id')
            ->get();
        $this->keys->load($questions, $institutionId);
        $this->integrity->load($answers, $institutionId);
        $questionsById = $questions->keyBy('id');
        $checkedAt = now();
        $results = [];

        foreach ($answers as $answer) {
            $question = $questionsById->get($answer->question_id);

            if (! $question instanceof Question) {
                throw new LogicException('A frozen answer belongs to no Question of its Assessment.');
            }

            // Validates the frozen answer: it must still be pending and structurally sound.
            $canonical = $this->integrity->canonical($answer, $attempt, $question);
            $results[$answer->id] = match (AnswerCheckingRoute::resolve($question->type, $question->checking_mode, (string) $question->points)) {
                AnswerCheckingRoute::Automatic => [AttemptAnswerCheckingStatus::AutoChecked, $this->keys->awardedPoints($question, $canonical)],
                AnswerCheckingRoute::ZeroPointClosed => [AttemptAnswerCheckingStatus::AutoChecked, '0.00000000'],
                AnswerCheckingRoute::TeacherReview => [AttemptAnswerCheckingStatus::WaitingForTeacherReview, null],
            };
        }

        $this->writeAnswers($institutionId, $results, $checkedAt);
        $this->scoreAttempt($attempt, $results, $checkedAt);
        $this->officialScores->resolve($locked->assessment, $locked->recipient, $locked->attempts, $checkedAt);

        return true;
    }

    /**
     * The query builder keeps attempt_answers.updated_at: Student reads show it as the
     * answer's last save.
     *
     * @param  array<string, array{AttemptAnswerCheckingStatus, ?string}>  $results
     */
    private function writeAnswers(string $institutionId, array $results, CarbonInterface $checkedAt): void
    {
        foreach ($results as $answerId => [$status, $awardedPoints]) {
            DB::table('attempt_answers')
                ->where('institution_id', $institutionId)
                ->where('id', $answerId)
                ->update([
                    'checking_status' => $status->value,
                    'awarded_points' => $awardedPoints,
                    'checked_by_user_id' => null,
                    'checked_at' => $status === AttemptAnswerCheckingStatus::AutoChecked ? $checkedAt : null,
                ]);
        }
    }

    /** @param array<string, array{AttemptAnswerCheckingStatus, ?string}> $results */
    private function scoreAttempt(AssessmentAttempt $attempt, array $results, CarbonInterface $checkedAt): void
    {
        $statuses = array_column($results, 0);

        if (in_array(AttemptAnswerCheckingStatus::WaitingForTeacherReview, $statuses, true)) {
            $attempt->status = AssessmentAttemptStatus::WaitingForTeacherReview;
        } else {
            $earnedPoints = $this->math->sum(array_column($results, 1));
            $attempt->status = AssessmentAttemptStatus::Checked;
            $attempt->earned_points = $earnedPoints;
            $attempt->normalized_score = $this->math->normalizedScore($earnedPoints, (string) $attempt->possible_points);
            $attempt->scoring_completed_at = $checkedAt;
        }

        $attempt->updated_at = $checkedAt;
        $attempt->save();
    }
}
