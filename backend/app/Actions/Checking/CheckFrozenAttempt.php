<?php

namespace App\Actions\Checking;

use App\Domain\Assessment\Checking\AnswerCheckingRoute;
use App\Domain\Assessment\Checking\CheckingScoreMath;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\Question;
use App\Models\Topic;
use App\Support\Checking\CheckingAnswerKeys;
use App\Support\Student\StudentHomeworkAnswerIntegrity;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;
use LogicException;

/**
 * Checks one frozen Attempt: routes every answer, awards automatic points, sends
 * manual answers to Teacher review and scores the Attempt when nothing waits.
 */
final class CheckFrozenAttempt
{
    private const FROZEN = [AssessmentAttemptStatus::Submitted, AssessmentAttemptStatus::TimedOutFinalized];

    public function __construct(
        private readonly StudentHomeworkAnswerIntegrity $integrity,
        private readonly CheckingAnswerKeys $keys,
        private readonly CheckingScoreMath $math,
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
        $attempt = $this->lockAttempt($preliminary);

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

        return true;
    }

    /**
     * Takes the S09-DOC-001 §8 lock order: Topic, Assessment and task row shared (the Teacher
     * update, pair designation and exception grant lock these first, so checking serializes
     * with them instead of deadlocking), then the recipient and all its Attempts for update.
     */
    private function lockAttempt(AssessmentAttempt $preliminary): AssessmentAttempt
    {
        $institutionId = $preliminary->institution_id;
        $reference = Assessment::query()->select(['id', 'topic_id', 'type'])
            ->where('institution_id', $institutionId)->whereKey($preliminary->assessment_id)->first();

        if (! $reference instanceof Assessment) {
            throw new LogicException('A frozen Attempt lost its Assessment.');
        }

        $topic = Topic::query()->select(['id'])
            ->where('institution_id', $institutionId)->whereKey($reference->topic_id)->sharedLock()->first();
        $assessment = Assessment::query()->select(['id', 'topic_id', 'type'])
            ->where('institution_id', $institutionId)->whereKey($reference->id)->sharedLock()->first();
        $task = match ($reference->type) {
            AssessmentType::Homework => HomeworkAssignment::query(),
            AssessmentType::Blitz => BlitzTask::query(),
        };
        $taskRow = $task->select(['assessment_id'])
            ->where('institution_id', $institutionId)->whereKey($reference->id)->sharedLock()->first();
        $recipient = AssessmentStudent::query()->select(['id', 'assessment_id', 'student_id'])
            ->where('institution_id', $institutionId)->whereKey($preliminary->assessment_student_id)->lockForUpdate()->first();

        if (! $topic instanceof Topic || ! $assessment instanceof Assessment || $taskRow === null
            || $assessment->topic_id !== $reference->topic_id || $assessment->type !== $reference->type
            || ! $recipient instanceof AssessmentStudent || $recipient->assessment_id !== $assessment->id
            || $recipient->student_id !== $preliminary->student_id) {
            throw new LogicException('A frozen Attempt has an inconsistent parent graph.');
        }

        $attempt = AssessmentAttempt::query()
            ->where('institution_id', $institutionId)
            ->where('assessment_student_id', $recipient->id)
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->firstWhere('id', $preliminary->id);

        if (! $attempt instanceof AssessmentAttempt || $attempt->assessment_id !== $assessment->id
            || $attempt->student_id !== $recipient->student_id) {
            throw new LogicException('A frozen Attempt does not belong to its recipient.');
        }

        return $attempt;
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
