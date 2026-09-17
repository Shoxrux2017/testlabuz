<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\HomeworkStatus;
use App\Exceptions\Teacher\TopicHasOpenAssessmentsException;
use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use App\Models\User;

final class TeacherTopicOpenAssessmentGuard
{
    public function lockAndEnsureResolved(User $teacher, Topic $topic): void
    {
        $assessmentIds = Assessment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->whereIn('type', [AssessmentType::Homework->value, AssessmentType::Blitz->value])
            ->orderBy('id')
            ->lockForUpdate()
            ->pluck('id');

        if ($assessmentIds->isEmpty()) {
            return;
        }

        $homework = HomeworkAssignment::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereIn('assessment_id', $assessmentIds)
            ->orderBy('assessment_id')
            ->lockForUpdate()
            ->get(['assessment_id', 'status']);

        $blitz = BlitzTask::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereIn('assessment_id', $assessmentIds)
            ->orderBy('assessment_id')
            ->lockForUpdate()
            ->get(['assessment_id', 'status']);

        if ($homework->contains(fn (HomeworkAssignment $assignment): bool => in_array(
            $assignment->status,
            [HomeworkStatus::Draft, HomeworkStatus::Active],
            true,
        )) || $blitz->contains(fn (BlitzTask $task): bool => in_array(
            $task->status,
            [BlitzStatus::Draft, BlitzStatus::Scheduled, BlitzStatus::Active],
            true,
        ))) {
            throw new TopicHasOpenAssessmentsException;
        }
    }
}
