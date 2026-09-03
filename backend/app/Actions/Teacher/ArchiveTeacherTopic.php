<?php

namespace App\Actions\Teacher;

use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Topic;
use App\Models\User;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use App\Support\Teacher\TeacherTopicOpenHomeworkGuard;
use Illuminate\Support\Facades\DB;

class ArchiveTeacherTopic
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TeacherTopicOpenHomeworkGuard $openHomeworkGuard,
    ) {}

    public function __invoke(User $teacher, string $topicId): Topic
    {
        $preliminaryTopic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $preliminaryTopic): Topic {
            $topic = $this->access->lockTopic($teacher, $preliminaryTopic)['topic'];

            if ($topic->status === TopicStatus::Archived) {
                return $topic;
            }

            if (! in_array($topic->status, [TopicStatus::Draft, TopicStatus::Closed], true)) {
                throw new TopicNotEditableException;
            }

            $this->openHomeworkGuard->lockAndEnsureResolved($teacher, $topic);

            $transitionedAt = now();
            $topic->status = TopicStatus::Archived;
            $topic->archived_at = $transitionedAt;
            $topic->updated_at = $transitionedAt;
            $topic->save();

            return $topic;
        });
    }
}
