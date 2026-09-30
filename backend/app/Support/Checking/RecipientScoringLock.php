<?php

namespace App\Support\Checking;

use App\Enums\AssessmentType;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use LogicException;

/**
 * Takes the S09-DOC-001 §8 scoring locks for one Student of one task: Topic, Assessment and
 * task row shared (the Teacher update, pair designation and exception grant lock these first,
 * so scoring serializes with them instead of deadlocking), then the recipient and all its
 * Attempts for update. Callers lock answers and the official row after this.
 */
final class RecipientScoringLock
{
    public function lock(string $institutionId, string $assessmentId, string $recipientId): LockedRecipientAttempts
    {
        $reference = Assessment::query()->select(['id', 'institution_id', 'topic_id', 'type'])
            ->where('institution_id', $institutionId)->whereKey($assessmentId)->first();

        if (! $reference instanceof Assessment) {
            throw new LogicException('A scored recipient lost its Assessment.');
        }

        $topic = Topic::query()->select(['id'])
            ->where('institution_id', $institutionId)->whereKey($reference->topic_id)->sharedLock()->first();
        $assessment = Assessment::query()->select(['id', 'institution_id', 'topic_id', 'type'])
            ->where('institution_id', $institutionId)->whereKey($reference->id)->sharedLock()->first();
        $task = match ($reference->type) {
            AssessmentType::Homework => HomeworkAssignment::query(),
            AssessmentType::Blitz => BlitzTask::query(),
        };
        $taskRow = $task->select(['assessment_id'])
            ->where('institution_id', $institutionId)->whereKey($reference->id)->sharedLock()->first();
        $recipient = AssessmentStudent::query()->select(['id', 'assessment_id', 'student_id'])
            ->where('institution_id', $institutionId)->whereKey($recipientId)->lockForUpdate()->first();

        if (! $topic instanceof Topic || ! $assessment instanceof Assessment || $taskRow === null
            || $assessment->topic_id !== $reference->topic_id || $assessment->type !== $reference->type
            || ! $recipient instanceof AssessmentStudent || $recipient->assessment_id !== $assessment->id) {
            throw new LogicException('A scored recipient has an inconsistent parent graph.');
        }

        $attempts = AssessmentAttempt::query()
            ->where('institution_id', $institutionId)
            ->where('assessment_student_id', $recipient->id)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        if ($attempts->contains(fn (AssessmentAttempt $attempt): bool => $attempt->assessment_id !== $assessment->id
            || $attempt->student_id !== $recipient->student_id)) {
            throw new LogicException('A recipient Attempt belongs to another task or Student.');
        }

        return new LockedRecipientAttempts($assessment, $recipient, $attempts);
    }
}
