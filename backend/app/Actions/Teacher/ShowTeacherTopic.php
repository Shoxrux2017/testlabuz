<?php

namespace App\Actions\Teacher;

use App\Models\Topic;
use App\Models\User;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ShowTeacherTopic
{
    public function __invoke(User $teacher, string $topic): Topic
    {
        if (! Str::isUuid($topic)) {
            throw new NotFoundHttpException;
        }

        $resolvedTopic = Topic::query()
            ->select([
                'id',
                'group_id',
                'title',
                'description',
                'subject',
                'student_instructions',
                'lesson_at',
                'status',
                'activated_at',
                'closed_at',
                'archived_at',
                'created_at',
                'updated_at',
            ])
            ->visibleToTeacher($teacher)
            ->whereKey($topic)
            ->with(['group:id,name,level,subject_direction,status'])
            ->first();

        if (! $resolvedTopic instanceof Topic) {
            throw new NotFoundHttpException;
        }

        return $resolvedTopic;
    }
}
