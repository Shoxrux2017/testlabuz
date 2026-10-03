<?php

namespace App\Actions\Teacher;

use App\Enums\TopicResultClosureReason;
use App\Models\User;
use App\Support\Results\TopicResultBulkOutcome;
use App\Support\Results\TopicResultClosures;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Support\Facades\DB;

/** Closes every closable Topic result of the cohort in one transaction and counts the skipped ones (docs/09 §25.9). */
final class CloseTeacherTopicResults
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TopicResultClosures $closures,
    ) {}

    public function __invoke(User $teacher, string $topicId): TopicResultBulkOutcome
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $topic): TopicResultBulkOutcome {
            ['topic' => $locked] = $this->access->lockTopic($teacher, $topic);

            return TopicResultBulkOutcome::of($this->closures->closeAll($teacher, $locked, TopicResultClosureReason::Teacher));
        });
    }
}
