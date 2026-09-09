<?php

namespace App\Actions\Teacher;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskNotActiveException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\User;
use App\Support\Assessment\HomeworkAttemptFinalizer;
use App\Support\Teacher\TeacherHomeworkLifecycleAccess;
use Illuminate\Support\Facades\DB;

final class CloseTeacherHomework
{
    public function __construct(
        private readonly TeacherHomeworkLifecycleAccess $access,
        private readonly ShowTeacherHomework $showTeacherHomework,
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeAtDeadline,
        private readonly HomeworkAttemptFinalizer $finalizer,
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

            $transitionedAt = now();

            if ($this->finalizeAtDeadline->finalizeLocked($homework, $attempts, $transitionedAt) === null) {
                foreach ($attempts as $attempt) {
                    $this->finalizer->finalizeAtClose($attempt, $transitionedAt);
                }
            }

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
