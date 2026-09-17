<?php

namespace App\Support\Student;

use App\Enums\AssessmentType;
use App\Exceptions\Student\StudentBlitzAssessmentNotAssignedException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

final class StudentBlitzAttemptAccess
{
    /** @return array{topic: Topic, assessment: Assessment, blitz: BlitzTask} */
    public function lockBlitz(User $student, Assessment $authorized): array
    {
        $topic = Topic::query()->where('institution_id', $student->institution_id)
            ->whereKey($authorized->topic_id)->lockForUpdate()->first();

        if ($topic === null) {
            throw new LogicException('Authorized Blitz lost its Topic during locked re-resolution.');
        }

        $assessment = Assessment::query()->where('institution_id', $student->institution_id)
            ->where('topic_id', $topic->id)->where('type', AssessmentType::Blitz->value)
            ->whereKey($authorized->id)->lockForUpdate()->first();

        if ($assessment === null) {
            throw new LogicException('Authorized Blitz lost its Assessment during locked re-resolution.');
        }

        $blitz = BlitzTask::query()->where('institution_id', $student->institution_id)
            ->where('assessment_id', $assessment->id)->lockForUpdate()->first();

        if ($blitz === null) {
            throw new LogicException('Authorized Blitz lost its task during locked re-resolution.');
        }

        return compact('topic', 'assessment', 'blitz');
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
