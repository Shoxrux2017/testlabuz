<?php

namespace App\Actions\Teacher;

use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Teacher\TeacherTopicResultPairAccess;

final class ShowTeacherTopicResultPair
{
    public function __construct(private readonly TeacherTopicResultPairAccess $access) {}

    public function __invoke(User $teacher, string $topicId): ?TopicResultPair
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);

        return TopicResultPair::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->first();
    }
}
