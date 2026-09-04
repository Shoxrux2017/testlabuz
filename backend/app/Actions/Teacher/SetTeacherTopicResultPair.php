<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\OfficialTaskRequiresGroupAssignmentException;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Teacher\TeacherTopicResultPairAccess;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

final class SetTeacherTopicResultPair
{
    public function __construct(private readonly TeacherTopicResultPairAccess $access) {}

    public function __invoke(User $teacher, string $topicId, string $candidateId): TopicResultPair
    {
        $preliminaryTopic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $preliminaryTopic, $candidateId): TopicResultPair {
            ['topic' => $topic] = $this->access->lockTopic($teacher, $preliminaryTopic);

            if (! in_array($topic->status, [TopicStatus::Draft, TopicStatus::Active], true)) {
                throw new TopicNotEditableException;
            }

            [
                'assessment' => $candidate,
                'homework' => $candidateHomework,
            ] = $this->access->lockCandidate($teacher, $topic, $candidateId);
            $pair = $this->access->lockPair($teacher, $topic);

            if ($pair instanceof TopicResultPair
                && strtolower($pair->homework_assessment_id) === strtolower($candidate->id)) {
                return $pair;
            }

            if ($pair instanceof TopicResultPair
                && ($pair->locked_at !== null || $pair->blitz_assessment_id !== null)) {
                throw new ResultPairLockedException;
            }

            $currentOfficial = null;

            if ($pair instanceof TopicResultPair) {
                ['assessment' => $currentOfficial] = $this->access->lockCurrentOfficial(
                    $teacher,
                    $topic,
                    $pair->homework_assessment_id,
                );
            }

            $attemptAssessmentIds = [$candidate->id];

            if ($currentOfficial instanceof Assessment) {
                $attemptAssessmentIds[] = $currentOfficial->id;
            }

            $attempts = $this->access->lockAttempts($teacher, array_values(array_unique($attemptAssessmentIds)));

            if ($currentOfficial instanceof Assessment
                && $attempts->contains('assessment_id', $currentOfficial->id)) {
                throw new ResultPairLockedException;
            }

            if ($candidate->assignment_mode !== AssessmentAssignmentMode::Group) {
                throw new OfficialTaskRequiresGroupAssignmentException;
            }

            if (! in_array($candidateHomework->status, [HomeworkStatus::Draft, HomeworkStatus::Active], true)) {
                throw new BusinessConflictException;
            }

            if ($attempts->contains('assessment_id', $candidate->id)) {
                throw new ResultPairLockedException;
            }

            $recipients = $this->access->lockRecipients($teacher, $candidate);
            $designatedAt = now();
            $cohortSnapshottedAt = $candidateHomework->status === HomeworkStatus::Active
                ? $this->validatedActiveCohort($teacher, $candidate, $recipients, $designatedAt)
                : $this->validatedDraftCohort($recipients);

            if (! $pair instanceof TopicResultPair) {
                $pair = new TopicResultPair;
                $pair->institution_id = $teacher->institution_id;
                $pair->topic_id = $topic->id;
                $pair->created_at = $designatedAt;
            }

            $pair->homework_assessment_id = $candidate->id;
            $pair->blitz_assessment_id = null;
            $pair->designated_by_user_id = $teacher->id;
            $pair->designated_at = $designatedAt;
            $pair->cohort_snapshotted_at = $cohortSnapshottedAt;
            $pair->locked_at = null;
            $pair->updated_at = $designatedAt;
            $pair->save();

            return $pair;
        });
    }

    /**
     * @param  Collection<int, AssessmentStudent>  $recipients
     */
    private function validatedActiveCohort(
        User $teacher,
        Assessment $candidate,
        Collection $recipients,
        CarbonInterface $designatedAt,
    ): CarbonInterface {
        $studentIds = [];

        foreach ($recipients as $recipient) {
            $studentId = strtolower($recipient->student_id);

            if ($recipient->institution_id !== $teacher->institution_id
                || $recipient->assessment_id !== $candidate->id
                || $recipient->assignment_source !== AssessmentAssignmentSource::Group
                || $recipient->assigned_at === null
                || isset($studentIds[$studentId])) {
                throw new BusinessConflictException;
            }

            $studentIds[$studentId] = true;
        }

        if ($studentIds === []) {
            throw new BusinessConflictException;
        }

        return $designatedAt;
    }

    /** @param Collection<int, AssessmentStudent> $recipients */
    private function validatedDraftCohort(Collection $recipients): ?CarbonInterface
    {
        if ($recipients->isNotEmpty()) {
            throw new BusinessConflictException;
        }

        return null;
    }
}
