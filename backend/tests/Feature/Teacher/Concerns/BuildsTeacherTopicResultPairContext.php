<?php

namespace Tests\Feature\Teacher\Concerns;

use App\Enums\AssessmentAssignmentSource;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonInterface;

trait BuildsTeacherTopicResultPairContext
{
    use BuildsTeacherQuestionMutationContext;

    protected function groupRecipient(
        Institution $institution,
        User $teacher,
        Assessment $assessment,
        User $student,
        ?CarbonInterface $assignedAt = null,
    ): AssessmentStudent {
        return AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Group,
            'assigned_at' => $assignedAt ?? now(),
            'assigned_by_user_id' => $teacher->id,
        ]);
    }

    protected function attemptFor(AssessmentStudent $recipient): AssessmentAttempt
    {
        return AssessmentAttempt::factory()->create([
            'institution_id' => $recipient->institution_id,
            'assessment_id' => $recipient->assessment_id,
            'assessment_student_id' => $recipient->id,
            'student_id' => $recipient->student_id,
            'possible_points' => '1.000000',
        ]);
    }

    /** @param array<string, mixed> $attributes */
    protected function resultPair(
        Institution $institution,
        User $teacher,
        Topic $topic,
        Assessment $homework,
        array $attributes = [],
    ): TopicResultPair {
        return TopicResultPair::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'homework_assessment_id' => $homework->id,
            'designated_by_user_id' => $teacher->id,
        ], $attributes));
    }
}
