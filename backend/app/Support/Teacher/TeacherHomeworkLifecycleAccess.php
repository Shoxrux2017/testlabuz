<?php

namespace App\Support\Teacher;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\Group;
use App\Models\HomeworkAssignment;
use App\Models\Question;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;

final class TeacherHomeworkLifecycleAccess
{
    public function __construct(private readonly TeacherHomeworkAccess $homeworkAccess) {}

    public function resolveHomework(User $teacher, string $homeworkId): Assessment
    {
        return $this->homeworkAccess->resolveHomework($teacher, $homeworkId);
    }

    /** @return array{group: Group, topic: Topic, assessment: Assessment, homework: HomeworkAssignment} */
    public function lockHomework(User $teacher, Assessment $preliminaryAssessment): array
    {
        return $this->homeworkAccess->lockHomework($teacher, $preliminaryAssessment);
    }

    public function lockResultPair(User $teacher, Topic $topic, Assessment $assessment): ?TopicResultPair
    {
        return TopicResultPair::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->where(function ($query) use ($assessment): void {
                $query
                    ->where('homework_assessment_id', $assessment->id)
                    ->orWhere('blitz_assessment_id', $assessment->id);
            })
            ->lockForUpdate()
            ->first();
    }

    /** @return Collection<int, Question> */
    public function lockQuestions(User $teacher, Assessment $assessment): Collection
    {
        return Question::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('position')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }

    /** @return Collection<int, AssessmentAttempt> */
    public function lockAttempts(User $teacher, Assessment $assessment): Collection
    {
        return AssessmentAttempt::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }
}
