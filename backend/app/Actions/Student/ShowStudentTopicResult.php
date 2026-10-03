<?php

namespace App\Actions\Student;

use App\Models\User;
use App\Support\Results\TopicResultReader;
use App\Support\Results\TopicResultReading;
use App\Support\Results\TopicResultReleaseModes;
use App\Support\Results\TopicResultVisibility;
use App\Support\Student\StudentBlitzReadSnapshot;
use App\Support\Student\StudentTopicResultAccess;

/** The Student's own Topic result, or null outside the cohort (docs/09 §29.5). One snapshot read. */
final class ShowStudentTopicResult
{
    public function __construct(
        private readonly StudentTopicResultAccess $access,
        private readonly TopicResultReader $reader,
        private readonly TopicResultVisibility $visibility,
        private readonly StudentBlitzReadSnapshot $snapshots,
    ) {}

    public function __invoke(User $student, string $topicId): ?TopicResultReading
    {
        return $this->snapshots->read(function () use ($student, $topicId): ?TopicResultReading {
            $topic = $this->access->resolve($student, $topicId);
            $result = $this->reader->forStudent($topic, $student->id);

            if ($result === null) {
                return null;
            }

            $modes = TopicResultReleaseModes::current($topic->institution_id);

            return new TopicResultReading($topic->id, $result, $this->visibility->of($result, $modes->student, $modes->parent)->studentVisible);
        });
    }
}
