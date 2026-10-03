<?php

namespace App\Support\Results;

use App\Models\Topic;

/** Builds the Teacher's entries from the live results and the Institution's current release modes. */
final class TeacherTopicResults
{
    public function __construct(
        private readonly TopicResultReader $reader,
        private readonly TopicResultVisibility $visibility,
    ) {}

    /** @return list<TeacherTopicResultEntry> */
    public function forTopic(Topic $topic): array
    {
        return $this->entries($topic, $this->reader->forTopic($topic));
    }

    public function forStudent(Topic $topic, string $studentId): ?TeacherTopicResultEntry
    {
        $result = $this->reader->forStudent($topic, $studentId);

        return $result === null ? null : $this->entries($topic, [$result])[0];
    }

    /**
     * @param  list<TopicResultView>  $results
     * @return list<TeacherTopicResultEntry>
     */
    private function entries(Topic $topic, array $results): array
    {
        if ($results === []) {
            return [];
        }

        $modes = TopicResultReleaseModes::current($topic->institution_id);

        return array_map(fn (TopicResultView $result): TeacherTopicResultEntry => new TeacherTopicResultEntry(
            $result,
            $this->visibility->of($result, $modes->student, $modes->parent),
            $modes->student,
            $modes->parent,
        ), $results);
    }
}
