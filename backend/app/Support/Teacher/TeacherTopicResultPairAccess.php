<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentType;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class TeacherTopicResultPairAccess
{
    public function __construct(private readonly TeacherHomeworkAccess $homeworkAccess) {}

    public function resolveTopic(User $teacher, string $topicId): Topic
    {
        return $this->homeworkAccess->resolveTopic($teacher, $topicId);
    }

    /** @return array{group: Group, topic: Topic} */
    public function lockTopic(User $teacher, Topic $preliminaryTopic): array
    {
        return $this->homeworkAccess->lockTopic($teacher, $preliminaryTopic);
    }

    /** @return array{assessment: Assessment, homework: HomeworkAssignment} */
    public function lockCandidate(User $teacher, Topic $topic, string $assessmentId): array
    {
        $assessment = Assessment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('topic_id', $topic->id)
            ->where('type', AssessmentType::Homework->value)
            ->whereKey($assessmentId)
            ->lockForUpdate()
            ->first();

        if (! $assessment instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        $homework = HomeworkAssignment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->lockForUpdate()
            ->first();

        if (! $homework instanceof HomeworkAssignment) {
            throw new NotFoundHttpException;
        }

        return compact('assessment', 'homework');
    }

    public function lockPair(User $teacher, Topic $topic): ?TopicResultPair
    {
        return TopicResultPair::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->lockForUpdate()
            ->first();
    }

    /** @return array{assessment: Assessment, homework: HomeworkAssignment} */
    public function lockCurrentOfficial(User $teacher, Topic $topic, string $assessmentId): array
    {
        $assessment = Assessment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('topic_id', $topic->id)
            ->where('type', AssessmentType::Homework->value)
            ->whereKey($assessmentId)
            ->lockForUpdate()
            ->first();

        if (! $assessment instanceof Assessment) {
            throw new BusinessConflictException;
        }

        $homework = HomeworkAssignment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->lockForUpdate()
            ->first();

        if (! $homework instanceof HomeworkAssignment) {
            throw new BusinessConflictException;
        }

        return compact('assessment', 'homework');
    }

    /**
     * @param  list<string>  $assessmentIds
     * @return Collection<int, AssessmentAttempt>
     */
    public function lockAttempts(User $teacher, array $assessmentIds): Collection
    {
        return AssessmentAttempt::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereIn('assessment_id', $assessmentIds)
            ->orderBy('assessment_id')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }

    /** @return Collection<int, AssessmentStudent> */
    public function lockRecipients(User $teacher, Assessment $assessment): Collection
    {
        return AssessmentStudent::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('student_id')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }
}
