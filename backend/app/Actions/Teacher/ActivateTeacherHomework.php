<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\HomeworkActivationValidator;
use App\Enums\AssessmentAssignmentMode;
use App\Enums\GroupStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\DeadlinePassedException;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Teacher\HomeworkRecipientSnapshotter;
use App\Support\Teacher\TeacherHomeworkLifecycleAccess;
use Illuminate\Support\Facades\DB;

final class ActivateTeacherHomework
{
    public function __construct(
        private readonly TeacherHomeworkLifecycleAccess $access,
        private readonly HomeworkActivationValidator $activationValidator,
        private readonly HomeworkRecipientSnapshotter $recipientSnapshotter,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    public function __invoke(User $teacher, string $homeworkId): Assessment
    {
        $preliminaryAssessment = $this->access->resolveHomework($teacher, $homeworkId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment): Assessment {
            [
                'group' => $group,
                'topic' => $topic,
                'assessment' => $assessment,
                'homework' => $homework,
            ] = $this->access->lockHomework($teacher, $preliminaryAssessment);

            if ($homework->status === HomeworkStatus::Active) {
                return ($this->showTeacherHomework)($teacher, $assessment->id);
            }

            if ($homework->status === HomeworkStatus::Closed) {
                throw new TaskClosedException;
            }

            if ($homework->status === HomeworkStatus::Archived) {
                throw new TaskArchivedException;
            }

            if ($topic->status !== TopicStatus::Active || $group->status !== GroupStatus::Active) {
                throw new TopicNotEditableException;
            }

            $assignmentMode = $this->activationValidator->validateMetadata($assessment);
            $pair = $this->access->lockResultPair($teacher, $topic, $assessment);

            if ($pair instanceof TopicResultPair && $pair->homework_assessment_id === $assessment->id) {
                if ($assignmentMode !== AssessmentAssignmentMode::Group) {
                    throw new BusinessConflictException;
                }

                if ($pair->locked_at !== null) {
                    throw new ResultPairLockedException;
                }

                if ($pair->cohort_snapshotted_at !== null || $pair->blitz_assessment_id !== null) {
                    throw new BusinessConflictException;
                }
            }

            $questions = $this->access->lockQuestions($teacher, $assessment);
            $totalPossiblePoints = $this->activationValidator->validateQuestions($questions);
            $lockedRecipientSnapshot = $this->recipientSnapshotter->lock(
                $teacher,
                $group,
                $assessment,
                $assignmentMode,
            );
            $transitionedAt = now();

            if ($homework->deadline_at !== null && $homework->deadline_at->lessThanOrEqualTo($transitionedAt)) {
                throw new DeadlinePassedException;
            }

            $this->recipientSnapshotter->snapshot(
                $teacher,
                $assessment,
                $assignmentMode,
                $transitionedAt,
                $lockedRecipientSnapshot,
            );

            $assessment->total_possible_points = $totalPossiblePoints;
            $assessment->updated_at = $transitionedAt;
            $assessment->save();

            $homework->status = HomeworkStatus::Active;
            $homework->activated_at = $transitionedAt;
            $homework->closed_at = null;
            $homework->archived_at = null;
            $homework->updated_at = $transitionedAt;
            $homework->save();

            if ($pair instanceof TopicResultPair && $pair->homework_assessment_id === $assessment->id) {
                $pair->cohort_snapshotted_at = $transitionedAt;
                $pair->updated_at = $transitionedAt;
                $pair->save();
            }

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }
}
