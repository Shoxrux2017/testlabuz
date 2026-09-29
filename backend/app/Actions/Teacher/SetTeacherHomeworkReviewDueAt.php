<?php

namespace App\Actions\Teacher;

use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\User;
use App\Support\Teacher\InstitutionEducationalDateTime;
use App\Support\Teacher\TeacherHomeworkLifecycleAccess;
use Illuminate\Support\Facades\DB;

/**
 * Sets or clears the Homework review deadline, a reminder that never changes
 * scores, statuses or the official selection. Review usually happens after
 * closing, so a closed Homework accepts it too.
 */
final class SetTeacherHomeworkReviewDueAt
{
    public function __construct(
        private readonly TeacherHomeworkLifecycleAccess $access,
        private readonly InstitutionEducationalDateTime $dateTime,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    public function __invoke(User $teacher, string $homeworkId, ?string $reviewDueAt): Assessment
    {
        $preliminaryAssessment = $this->access->resolveHomework($teacher, $homeworkId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $reviewDueAt): Assessment {
            [
                'topic' => $topic,
                'assessment' => $assessment,
                'homework' => $homework,
            ] = $this->access->lockHomework($teacher, $preliminaryAssessment);

            if ($homework->status === HomeworkStatus::Archived) {
                throw new TaskArchivedException;
            }

            if (in_array($topic->status, [TopicStatus::Closed, TopicStatus::Archived], true)) {
                throw new TopicNotEditableException;
            }

            $resulting = $reviewDueAt === null
                ? null
                : $this->dateTime->parse($teacher, $reviewDueAt, 'review_due_at');
            $current = $homework->review_due_at;

            if ($current?->format('U.u') !== $resulting?->format('U.u')) {
                $homework->review_due_at = $resulting;
                $homework->save();
            }

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }
}
