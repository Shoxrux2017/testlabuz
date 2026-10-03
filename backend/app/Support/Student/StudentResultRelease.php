<?php

namespace App\Support\Student;

use App\Enums\StudentResultReleaseMode;
use App\Models\Assessment;
use App\Models\TopicResult;
use App\Models\User;
use App\Support\Checking\OfficialTaskDesignation;
use Illuminate\Support\Collection;

/**
 * Whether the Attempt results of each task are released to the Student (S10-D4, docs/09 §17.4): a
 * practice task's results always are; an official task's results are released automatically or once
 * the Teacher released the Student's Topic result. At most two queries for any number of tasks.
 */
final class StudentResultRelease
{
    public function __construct(private readonly OfficialTaskDesignation $designation) {}

    /**
     * @param  Collection<int, Assessment>  $tasks  Tasks of the Student's Institution with their Topic ids
     * @return array<string, bool> By task id
     */
    public function forTasks(User $student, Collection $tasks, ?StudentResultReleaseMode $mode): array
    {
        if ($mode === StudentResultReleaseMode::Automatic) {
            return $tasks->mapWithKeys(fn (Assessment $task): array => [$task->id => true])->all();
        }

        $officialIds = array_flip($this->designation->officialIds($student->institution_id, $tasks));
        $officialTopicIds = $tasks->filter(fn (Assessment $task): bool => isset($officialIds[$task->id]))
            ->map(fn (Assessment $task): string => $task->topic_id)
            ->unique()
            ->values();
        $releasedTopicIds = $officialTopicIds->isEmpty() ? [] : TopicResult::query()
            ->where('institution_id', $student->institution_id)
            ->where('student_id', $student->id)
            ->whereIn('topic_id', $officialTopicIds)
            ->whereNotNull('student_released_at')
            ->pluck('topic_id')
            ->flip()
            ->all();

        return $tasks->mapWithKeys(fn (Assessment $task): array => [
            $task->id => ! isset($officialIds[$task->id]) || isset($releasedTopicIds[$task->topic_id]),
        ])->all();
    }
}
