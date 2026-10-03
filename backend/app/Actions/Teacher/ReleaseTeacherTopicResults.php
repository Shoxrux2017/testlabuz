<?php

namespace App\Actions\Teacher;

use App\Enums\TopicResultReleaseAudience;
use App\Models\User;
use App\Support\Results\TopicResultBulkOutcome;
use App\Support\Results\TopicResultReader;
use App\Support\Results\TopicResultReleases;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Support\Facades\DB;

/** Releases every ready Topic result of the cohort in one transaction and counts the skipped ones (docs/09 §27.5). */
final class ReleaseTeacherTopicResults
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TopicResultReader $reader,
        private readonly TopicResultReleases $releases,
    ) {}

    public function __invoke(User $teacher, string $topicId, TopicResultReleaseAudience $audience): TopicResultBulkOutcome
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);

        return DB::transaction(function () use ($teacher, $topic, $audience): TopicResultBulkOutcome {
            ['topic' => $locked] = $this->access->lockTopic($teacher, $topic);

            return TopicResultBulkOutcome::of($this->releases->release($teacher, $locked, $this->reader->forTopic($locked), $audience));
        });
    }
}
