<?php

namespace App\Actions\Teacher;

use App\Enums\GroupStatus;
use App\Enums\TopicStatus;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\User;
use App\Support\Teacher\InstitutionLessonAt;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class CreateTeacherTopic
{
    public function __construct(private readonly InstitutionLessonAt $institutionLessonAt) {}

    /**
     * @param array{
     *     group_id: string,
     *     title: string,
     *     description: ?string,
     *     subject: string,
     *     student_instructions: string,
     *     lesson_at: ?string
     * } $attributes
     */
    public function __invoke(User $teacher, array $attributes): Topic
    {
        return DB::transaction(function () use ($teacher, $attributes): Topic {
            $group = Group::query()
                ->where('institution_id', $teacher->institution_id)
                ->whereKey($attributes['group_id'])
                ->lockForUpdate()
                ->first();

            if (! $group instanceof Group || $group->status !== GroupStatus::Active) {
                throw new NotFoundHttpException;
            }

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

            $lessonAt = $attributes['lesson_at'] === null
                ? null
                : $this->institutionLessonAt->parse($teacher, $attributes['lesson_at']);

            $topic = Topic::query()->create([
                'institution_id' => $teacher->institution_id,
                'group_id' => $group->id,
                'teacher_id' => $teacher->id,
                'title' => $attributes['title'],
                'description' => $attributes['description'],
                'subject' => $attributes['subject'],
                'student_instructions' => $attributes['student_instructions'],
                'lesson_at' => $lessonAt,
                'status' => TopicStatus::Draft,
                'activated_at' => null,
                'closed_at' => null,
                'archived_at' => null,
            ]);

            $topic->setRelation('group', $group);

            return $topic;
        });
    }
}
