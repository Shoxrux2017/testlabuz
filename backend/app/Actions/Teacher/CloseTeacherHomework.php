<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\HomeworkHasInProgressAttemptException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskNotActiveException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\User;
use App\Support\Teacher\TeacherHomeworkLifecycleAccess;
use Illuminate\Support\Facades\DB;

final class CloseTeacherHomework
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

            if ($homework->status === HomeworkStatus::Closed) {
                return ($this->showTeacherHomework)($teacher, $assessment->id);
            }

            if ($homework->status === HomeworkStatus::Draft) {
                throw new TaskNotActiveException;
            }

            if ($homework->status === HomeworkStatus::Archived) {
                throw new TaskArchivedException;
            }

            if ($topic->status === TopicStatus::Archived) {
                throw new TopicNotEditableException;
            }

            $this->access->lockResultPair($teacher, $topic, $assessment);
            $attempts = $this->access->lockAttempts($teacher, $assessment);

            if ($attempts->contains(
                fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::InProgress,
            )) {
                throw new HomeworkHasInProgressAttemptException;
            }

            $transitionedAt = now();
            $homework->status = HomeworkStatus::Closed;
            $homework->closed_at = $transitionedAt;
            $homework->updated_at = $transitionedAt;
            $homework->save();

            $assessment->updated_at = $transitionedAt;
            $assessment->save();

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }
}
