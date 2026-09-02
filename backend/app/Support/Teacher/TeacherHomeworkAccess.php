<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentType;
use App\Models\Assessment;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class TeacherHomeworkAccess
{
    public function resolveTopic(User $teacher, string $topicId): Topic
    {
        if (! Str::isUuid($topicId)) {
            throw new NotFoundHttpException;
        }

        $topic = Topic::query()
            ->select(['id', 'institution_id', 'group_id', 'teacher_id', 'status'])
            ->visibleToTeacher($teacher)
            ->whereKey($topicId)
            ->first();

        if (! $topic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        return $topic;
    }

    /** @return array{group: Group, topic: Topic} */
    public function lockTopic(User $teacher, Topic $preliminaryTopic): array
    {
        $group = $this->lockGroup($teacher, $preliminaryTopic->group_id);
        $this->lockMembership($teacher, $group);

        $topic = Topic::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('group_id', $group->id)
            ->whereKey($preliminaryTopic->id)
            ->lockForUpdate()
            ->first();

        if (! $topic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        return ['group' => $group, 'topic' => $topic];
    }

    public function resolveHomework(User $teacher, string $homeworkId): Assessment
    {
        if (! Str::isUuid($homeworkId)) {
            throw new NotFoundHttpException;
        }

        $assessment = Assessment::query()
            ->select([
                'id',
                'institution_id',
                'topic_id',
                'teacher_id',
                'type',
                'title',
                'description',
                'student_instructions',
                'assignment_mode',
                'total_possible_points',
                'created_at',
                'updated_at',
            ])
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('type', AssessmentType::Homework->value)
            ->whereKey($homeworkId)
            ->whereHas('topic', fn ($query) => $query->visibleToTeacher($teacher))
            ->with('topic:id,institution_id,group_id,teacher_id,status')
            ->first();

        if (! $assessment instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        return $assessment;
    }

    /** @return array{group: Group, topic: Topic, assessment: Assessment, homework: HomeworkAssignment} */
    public function lockHomework(User $teacher, Assessment $preliminaryAssessment): array
    {
        $preliminaryTopic = $preliminaryAssessment->topic;

        if (! $preliminaryTopic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        ['group' => $group, 'topic' => $topic] = $this->lockTopic($teacher, $preliminaryTopic);

        $assessment = Assessment::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->where('topic_id', $topic->id)
            ->where('type', AssessmentType::Homework->value)
            ->whereKey($preliminaryAssessment->id)
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

        return compact('group', 'topic', 'assessment', 'homework');
    }

    private function lockGroup(User $teacher, string $groupId): Group
    {
        $group = Group::query()
            ->where('institution_id', $teacher->institution_id)
            ->whereKey($groupId)
            ->lockForUpdate()
            ->first();

        if (! $group instanceof Group) {
            throw new NotFoundHttpException;
        }

        return $group;
    }

    private function lockMembership(User $teacher, Group $group): GroupTeacherMembership
    {
        $membership = GroupTeacherMembership::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('group_id', $group->id)
            ->where('teacher_id', $teacher->id)
            ->whereNull('ended_at')
            ->lockForUpdate()
            ->first();

        if (! $membership instanceof GroupTeacherMembership) {
            throw new NotFoundHttpException;
        }

        return $membership;
    }
}
