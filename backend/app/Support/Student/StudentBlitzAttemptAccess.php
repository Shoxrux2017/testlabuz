<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Student\StudentBlitzAssessmentNotAssignedException;
use App\Exceptions\Student\StudentBlitzAttemptNotEditableException;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Exceptions\Student\StudentBlitzTimeExpiredException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Str;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class StudentBlitzAttemptAccess
{
    public function resolveAttempt(User $student, string $attemptId): AssessmentAttempt
    {
        if (! Str::isUuid($attemptId)) {
            throw new NotFoundHttpException;
        }

        $attempt = AssessmentAttempt::query()
            ->where('institution_id', $student->institution_id)->where('student_id', $student->id)
            ->whereHas('assessmentStudent', fn (Builder $query) => $query
                ->where('institution_id', $student->institution_id)->where('student_id', $student->id)
                ->whereColumn('assessment_students.assessment_id', 'assessment_attempts.assessment_id'))
            ->whereHas('assessment', fn (Builder $query) => $query
                ->where('institution_id', $student->institution_id)->where('type', AssessmentType::Blitz->value)
                ->whereHas('blitzTask', fn (Builder $blitz) => $blitz->where('institution_id', $student->institution_id)))
            ->whereKey($attemptId)->first();

        if ($attempt === null) {
            throw new NotFoundHttpException;
        }

        return $attempt;
    }

    /** @return array{topic: Topic, assessment: Assessment, blitz: BlitzTask} */
    public function lockBlitz(User $student, Assessment $authorized): array
    {
        return $this->lockBlitzRows($student, $authorized, exclusive: true);
    }

    /** @return array{topic: Topic, assessment: Assessment, blitz: BlitzTask} */
    public function shareBlitzForAnswer(User $student, Assessment $authorized): array
    {
        return $this->lockBlitzRows($student, $authorized, exclusive: false);
    }

    /** @return array{topic: Topic, assessment: Assessment, blitz: BlitzTask} */
    public function shareBlitzForSubmit(User $student, Assessment $authorized): array
    {
        return $this->lockBlitzRows($student, $authorized, exclusive: false);
    }

    /** @return array{topic: Topic, assessment: Assessment, blitz: BlitzTask} */
    private function lockBlitzRows(User $student, Assessment $authorized, bool $exclusive): array
    {
        $topic = Topic::query()->where('institution_id', $student->institution_id)
            ->whereKey($authorized->topic_id)->lock($exclusive)->first();

        if ($topic === null) {
            throw new LogicException('Authorized Blitz lost its Topic during locked re-resolution.');
        }

        $assessment = Assessment::query()->where('institution_id', $student->institution_id)
            ->where('topic_id', $topic->id)->where('type', AssessmentType::Blitz->value)
            ->whereKey($authorized->id)->lock($exclusive)->first();

        if ($assessment === null) {
            throw new LogicException('Authorized Blitz lost its Assessment during locked re-resolution.');
        }

        $blitz = BlitzTask::query()->where('institution_id', $student->institution_id)
            ->where('assessment_id', $assessment->id)->lock($exclusive)->first();

        if ($blitz === null) {
            throw new LogicException('Authorized Blitz lost its task during locked re-resolution.');
        }

        return compact('topic', 'assessment', 'blitz');
    }

    public function assertValidAnswerAttempt(User $student, Assessment $assessment, AssessmentAttempt $attempt): void
    {
        $recipient = AssessmentStudent::query()->where('institution_id', $student->institution_id)
            ->where('assessment_id', $assessment->id)->where('student_id', $student->id)
            ->whereKey($attempt->assessment_student_id)->first(['id']);

        if ($attempt->institution_id !== $student->institution_id || $attempt->student_id !== $student->id
            || $attempt->assessment_id !== $assessment->id || $recipient === null
            || $attempt->started_at === null || $attempt->deadline_at === null
            || ! $attempt->started_at->lt($attempt->deadline_at)
            || ($attempt->status === AssessmentAttemptStatus::InProgress
                && ($attempt->submitted_at !== null || $attempt->finalized_at !== null
                    || $attempt->locked_at !== null || $attempt->finalization_reason !== null))) {
            throw new LogicException('Locked Blitz Attempt has an invalid structural state.');
        }
    }

    public function assertAnswerEditable(User $student, Topic $topic, Assessment $assessment, BlitzTask $blitz, AssessmentAttempt $attempt): void
    {
        if ($topic->status !== TopicStatus::Active || $blitz->status !== BlitzStatus::Active) {
            throw new StudentBlitzNotActiveException;
        }

        $this->assertValidAnswerAttempt($student, $assessment, $attempt);

        if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
            throw new StudentBlitzAttemptNotEditableException;
        }

        // Observe the server clock only after the caller holds the lifecycle and answer locks.
        if (now()->gte($attempt->deadline_at)) {
            throw new StudentBlitzTimeExpiredException;
        }
    }

    public function lockPair(User $student, Topic $topic): ?TopicResultPair
    {
        return TopicResultPair::query()->where('institution_id', $student->institution_id)
            ->where('topic_id', $topic->id)->lockForUpdate()->first();
    }

    public function lockRecipient(User $student, Assessment $assessment, string $authorizedRecipientId): AssessmentStudent
    {
        $recipient = AssessmentStudent::query()->where('institution_id', $student->institution_id)
            ->where('assessment_id', $assessment->id)->where('student_id', $student->id)
            ->lockForUpdate()->first();

        if ($recipient === null) {
            throw new StudentBlitzAssessmentNotAssignedException;
        }

        if ($recipient->id !== $authorizedRecipientId) {
            throw new LogicException('Authorized Blitz recipient changed during locked re-resolution.');
        }

        return $recipient;
    }

    /** @return Collection<int, AssessmentAttempt> */
    public function lockAttempts(User $student, Assessment $assessment, ?TopicResultPair $officialPair): Collection
    {
        $query = AssessmentAttempt::query()->where('institution_id', $student->institution_id);

        if ($officialPair !== null) {
            return $query->whereIn('assessment_id', array_filter([
                $officialPair->homework_assessment_id, $officialPair->blitz_assessment_id,
            ]))->orderBy('assessment_id')->orderBy('id')->lockForUpdate()->get();
        }

        return $query->where('assessment_id', $assessment->id)->where('student_id', $student->id)
            ->orderBy('attempt_number')->orderBy('id')->lockForUpdate()->get();
    }
}
