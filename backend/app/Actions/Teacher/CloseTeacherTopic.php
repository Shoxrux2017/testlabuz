<?php

namespace App\Actions\Teacher;

use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Topic;
use App\Models\User;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Support\Facades\DB;

class CloseTeacherTopic
{
    public function __construct(private readonly TeacherTopicLifecycleAccess $access) {}

    public function __invoke(User $teacher, string $topicId): Topic
    {
        $preliminaryTopic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $preliminaryTopic): Topic {
            $topic = $this->access->lockTopic($teacher, $preliminaryTopic)['topic'];

            if ($topic->status === TopicStatus::Closed) {
                return $topic;
            }

            if ($topic->status !== TopicStatus::Active) {
                throw new TopicNotEditableException;
            }

            $transitionedAt = now();
            $topic->status = TopicStatus::Closed;
            $topic->closed_at = $transitionedAt;
            $topic->updated_at = $transitionedAt;
            $topic->save();

            return $topic;
        });
    }
}
