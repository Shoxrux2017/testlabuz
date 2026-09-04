<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\User;
use App\Support\Teacher\TeacherHomeworkLifecycleAccess;
use Illuminate\Support\Facades\DB;

final class ArchiveTeacherHomework
{
    public function __construct(
        private readonly TeacherHomeworkLifecycleAccess $access,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    public function __invoke(User $teacher, string $homeworkId): Assessment
    {
        $preliminaryAssessment = $this->access->resolveHomework($teacher, $homeworkId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment): Assessment {
            [
                'topic' => $topic,
                'assessment' => $assessment,
                'homework' => $homework,
            ] = $this->access->lockHomework($teacher, $preliminaryAssessment);

            if ($homework->status === HomeworkStatus::Archived) {
                return ($this->showTeacherHomework)($teacher, $assessment->id);
            }

            if ($homework->status === HomeworkStatus::Active) {
                throw new BusinessConflictException;
            }

            $pair = $this->access->lockResultPair($teacher, $topic, $assessment);

            if ($homework->status === HomeworkStatus::Draft
                && $pair?->homework_assessment_id === $assessment->id) {
                throw new BusinessConflictException;
            }

            $attempts = $this->access->lockAttempts($teacher, $assessment);

            if (($homework->status === HomeworkStatus::Draft && $attempts->isNotEmpty())
                || ($homework->status === HomeworkStatus::Closed
                    && $attempts->contains(
                        fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::InProgress,
                    ))) {
                throw new BusinessConflictException;
            }

            $wasDraft = $homework->status === HomeworkStatus::Draft;
            $transitionedAt = now();
            $homework->status = HomeworkStatus::Archived;
            $homework->archived_at = $transitionedAt;
            $homework->updated_at = $transitionedAt;

            if ($wasDraft) {
                $homework->activated_at = null;
                $homework->closed_at = null;
            }

            $homework->save();

            $assessment->updated_at = $transitionedAt;
            $assessment->save();

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }
}
