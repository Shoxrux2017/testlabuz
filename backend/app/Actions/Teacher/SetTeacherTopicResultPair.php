<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\BlitzStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\OfficialTaskRequiresGroupAssignmentException;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Teacher\TeacherTopicResultPairAccess;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

final class SetTeacherTopicResultPair
{
    public function __construct(private readonly TeacherTopicResultPairAccess $access) {}

    public function __invoke(User $teacher, string $topicId, string $candidateId, ?string $blitzId = null): TopicResultPair
    {
        $preliminaryTopic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $preliminaryTopic, $candidateId, $blitzId): TopicResultPair {
            ['topic' => $topic] = $this->access->lockTopic($teacher, $preliminaryTopic);

            if (! in_array($topic->status, [TopicStatus::Draft, TopicStatus::Active], true)) {
                throw new TopicNotEditableException;
            }

            ['assessment' => $candidate, 'homework' => $candidateHomework] = $this->access->lockCandidate($teacher, $topic, $candidateId);
            $candidateBlitz = $blitzId === null ? null : $this->access->lockBlitzCandidate($teacher, $topic, $blitzId);
            $pair = $this->access->currentPair($teacher, $topic);
            $homeworkChanges = ! $pair instanceof TopicResultPair || $pair->homework_assessment_id !== $candidate->id;
            $blitzChanges = $candidateBlitz !== null
                && (! $pair instanceof TopicResultPair || $pair->blitz_assessment_id !== $candidateBlitz['assessment']->id);

            if ($pair instanceof TopicResultPair && ! $homeworkChanges && ! $blitzChanges) {
                return $this->access->lockPair($teacher, $topic);
            }

            if ($pair instanceof TopicResultPair
                && (($homeworkChanges && ($pair->locked_at !== null || $pair->blitz_assessment_id !== null))
                    || ($blitzChanges && $pair->blitz_assessment_id !== null && $pair->locked_at !== null))) {
                throw new ResultPairLockedException;
            }

            $currentHomework = $pair instanceof TopicResultPair && $homeworkChanges
                ? $this->access->lockCurrentOfficial($teacher, $topic, $pair->homework_assessment_id)
                : null;
            $currentBlitz = $pair instanceof TopicResultPair && $blitzChanges && $pair->blitz_assessment_id !== null
                ? $this->access->lockCurrentOfficialBlitz($teacher, $topic, $pair->blitz_assessment_id)
                : null;

            // Parent-first locking keeps competing designation and activation in the same Topic serialized.
            $pair = $this->access->lockPair($teacher, $topic);
            $assessmentIds = array_values(array_unique(array_filter([
                $candidate->id,
                $candidateBlitz['assessment']->id ?? null,
                $currentHomework['assessment']->id ?? null,
                $currentBlitz['assessment']->id ?? null,
            ])));
            $attempts = $this->access->lockAttempts($teacher, $assessmentIds);
            $recipients = $this->access->lockRecipients($teacher, $assessmentIds);
            $changedAt = now();

            if ($homeworkChanges) {
                if ($currentHomework !== null && $attempts->contains('assessment_id', $currentHomework['assessment']->id)) {
                    throw new ResultPairLockedException;
                }

                $this->requireGroupAssignment($candidate);

                if (! in_array($candidateHomework->status, [HomeworkStatus::Draft, HomeworkStatus::Active], true)) {
                    throw new BusinessConflictException;
                }

                if ($attempts->contains('assessment_id', $candidate->id)) {
                    throw new ResultPairLockedException;
                }

                $homeworkRecipients = $recipients->where('assessment_id', $candidate->id);
                $cohortSnapshottedAt = $candidateHomework->status === HomeworkStatus::Active
                    ? $this->validatedActiveCohort($teacher, $candidate, $homeworkRecipients, $changedAt)
                    : $this->validatedDraftCohort($homeworkRecipients);
            }

            if ($blitzChanges) {
                if ($currentBlitz !== null) {
                    $this->validateCurrentBlitz($currentBlitz['assessment'], $currentBlitz['blitz'], $attempts);
                }

                $this->validateBlitzCandidate(
                    $candidateBlitz['assessment'],
                    $candidateBlitz['blitz'],
                    $attempts,
                    $recipients->where('assessment_id', $candidateBlitz['assessment']->id),
                );
            }

            if (! $pair instanceof TopicResultPair) {
                $pair = new TopicResultPair;
                $pair->institution_id = $teacher->institution_id;
                $pair->topic_id = $topic->id;
                $pair->created_at = $changedAt;
                $pair->locked_at = null;
                $pair->blitz_assessment_id = null;
            }

            if ($homeworkChanges) {
                $pair->homework_assessment_id = $candidate->id;
                $pair->designated_by_user_id = $teacher->id;
                $pair->designated_at = $changedAt;
                $pair->cohort_snapshotted_at = $cohortSnapshottedAt;
            }

            if ($blitzChanges) {
                $pair->blitz_assessment_id = $candidateBlitz['assessment']->id;
            }

            $pair->updated_at = $changedAt;
            $pair->save();

            return $pair;
        });
    }

    private function requireGroupAssignment(Assessment $assessment): void
    {
        if ($assessment->assignment_mode !== AssessmentAssignmentMode::Group) {
            throw new OfficialTaskRequiresGroupAssignmentException;
        }
    }

    /** @param Collection<int, AssessmentAttempt> $attempts */
    private function validateCurrentBlitz(Assessment $assessment, BlitzTask $blitz, Collection $attempts): void
    {
        if (! in_array($blitz->status, [BlitzStatus::Draft, BlitzStatus::Scheduled], true)
            || $attempts->contains('assessment_id', $assessment->id)) {
            throw new ResultPairLockedException;
        }

        $this->requireGroupAssignment($assessment);
    }

    /**
     * @param  Collection<int, AssessmentAttempt>  $attempts
     * @param  Collection<int, AssessmentStudent>  $recipients
     */
    private function validateBlitzCandidate(Assessment $assessment, BlitzTask $blitz, Collection $attempts, Collection $recipients): void
    {
        $this->requireGroupAssignment($assessment);

        if ($attempts->contains('assessment_id', $assessment->id)) {
            throw new ResultPairLockedException;
        }

        if (! in_array($blitz->status, [BlitzStatus::Draft, BlitzStatus::Scheduled], true)
            || $recipients->isNotEmpty()) {
            throw new BusinessConflictException;
        }
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
