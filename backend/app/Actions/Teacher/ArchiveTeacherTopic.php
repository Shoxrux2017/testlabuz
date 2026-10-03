<?php

namespace App\Actions\Teacher;

use App\Enums\TopicResultClosureReason;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Topic;
use App\Models\User;
use App\Support\Results\TopicResultClosures;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use App\Support\Teacher\TeacherTopicOpenAssessmentGuard;
use Illuminate\Support\Facades\DB;

class ArchiveTeacherTopic
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TeacherTopicOpenAssessmentGuard $openAssessmentGuard,
        private readonly TopicResultClosures $resultClosures,
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

            $this->openAssessmentGuard->lockAndEnsureResolved($teacher, $topic);

            $transitionedAt = now();
            // Archiving closes every terminal Topic result of the cohort; waiting results stay open (docs/09 §25.10).
            $this->resultClosures->closeAll($teacher, $topic, TopicResultClosureReason::TopicArchived, $transitionedAt);
            $topic->status = TopicStatus::Archived;
            $topic->archived_at = $transitionedAt;
            $topic->updated_at = $transitionedAt;
            $topic->save();

            return $topic;
        });
    }
}
