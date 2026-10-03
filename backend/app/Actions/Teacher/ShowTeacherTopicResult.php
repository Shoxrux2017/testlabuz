<?php

namespace App\Actions\Teacher;

use App\Models\User;
use App\Support\Results\TeacherTopicResultEntry;
use App\Support\Results\TeacherTopicResults;
use App\Support\Student\StudentBlitzReadSnapshot;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/** One cohort Student's Topic result with its comment, release and closure actors (docs/09 §25.6). One snapshot read. */
final class ShowTeacherTopicResult
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TeacherTopicResults $results,
        private readonly StudentBlitzReadSnapshot $snapshots,
    ) {}

    public function __invoke(User $teacher, string $topicId, string $studentId): TeacherTopicResultEntry
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);

        if (! Str::isUuid($studentId)) {
            throw new NotFoundHttpException;
        }

        return $this->snapshots->read(function () use ($topic, $studentId): TeacherTopicResultEntry {
            $entry = $this->results->forStudent($topic, strtolower($studentId)) ?? throw new NotFoundHttpException;
            $row = $entry->result->row;
            $actorIds = array_values(array_unique(array_filter([
                $row?->teacher_comment_updated_by_user_id, $row?->student_released_by_user_id,
                $row?->parent_released_by_user_id, $row?->closed_by_user_id,
            ])));
            $actors = $actorIds === [] ? [] : User::query()
                ->select(['id', 'institution_id', 'full_name'])
                ->where('institution_id', $topic->institution_id)
                ->whereIn('id', $actorIds)
                ->get()
                ->keyBy('id')
                ->all();

            return new TeacherTopicResultEntry($entry->result, $entry->visibility, $entry->studentMode, $entry->parentMode, $actors);
        });
    }
}
