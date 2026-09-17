<?php

namespace App\Actions\Teacher;

use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Topic;
use App\Models\User;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use App\Support\Teacher\TeacherTopicOpenAssessmentGuard;
use Illuminate\Support\Facades\DB;

class CloseTeacherTopic
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TeacherTopicOpenAssessmentGuard $openAssessmentGuard,
    ) {}

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

            $this->openAssessmentGuard->lockAndEnsureResolved($teacher, $topic);

            $transitionedAt = now();
            $topic->status = TopicStatus::Closed;
            $topic->closed_at = $transitionedAt;
            $topic->updated_at = $transitionedAt;
            $topic->save();

            return $topic;
        });
    }
}
