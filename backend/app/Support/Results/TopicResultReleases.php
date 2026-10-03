<?php

namespace App\Support\Results;

use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Enums\TopicResultReleaseAudience;
use App\Exceptions\ManualReleaseNotAllowedException;
use App\Models\Topic;
use App\Models\TopicResult;
use App\Models\User;

/**
 * Teacher releases of Topic results (docs/09 §27.3-27.5), run inside the caller's Topic lock. The
 * audience's current mode must be manual Teacher release; a release already made stays; otherwise a
 * result is released only when the visibility rule would then show it (an outcome with finished work
 * for the Student, values the Student already sees for Parents).
 */
final class TopicResultReleases
{
    public function __construct(private readonly TopicResultVisibility $visibility) {}

    /**
     * @param  list<TopicResultView>  $results  Live results read under the same Topic lock
     * @return list<TopicResultActionOutcome> In the order of $results
     *
     * @throws ManualReleaseNotAllowedException
     */
    public function release(User $teacher, Topic $locked, array $results, TopicResultReleaseAudience $audience): array
    {
        $modes = TopicResultReleaseModes::current($locked->institution_id);
        $toStudent = $audience === TopicResultReleaseAudience::Student;

        if ($toStudent ? $modes->student !== StudentResultReleaseMode::ManualTeacher : $modes->parent !== ParentResultReleaseMode::ManualTeacher) {
            throw new ManualReleaseNotAllowedException;
        }

        $rows = TopicResult::query()
            ->where('institution_id', $locked->institution_id)
            ->where('topic_id', $locked->id)
            ->whereIn('student_id', array_map(fn (TopicResultView $result): string => $result->student->id, $results))
            ->orderBy('id')
            ->lockForUpdate()
            ->get()
            ->keyBy('student_id');
        [$releasedAt, $releasedBy] = $toStudent
            ? ['student_released_at', 'student_released_by_user_id']
            : ['parent_released_at', 'parent_released_by_user_id'];

        return array_map(function (TopicResultView $result) use ($teacher, $locked, $rows, $modes, $toStudent, $releasedAt, $releasedBy): TopicResultActionOutcome {
            $row = $rows->get($result->student->id);

            if ($row?->{$releasedAt} !== null) {
                return TopicResultActionOutcome::AlreadyDone;
            }

            $visibility = $this->visibility->of($result, $modes->student, $modes->parent);

            if (! ($toStudent ? $visibility->canReleaseToStudent : $visibility->canReleaseToParent)) {
                return TopicResultActionOutcome::NotReady;
            }

            ($row ?? new TopicResult([
                'institution_id' => $locked->institution_id,
                'topic_id' => $locked->id,
                'student_id' => $result->student->id,
            ]))->fill([$releasedAt => now(), $releasedBy => $teacher->id])->save();

            return TopicResultActionOutcome::Done;
        }, $results);
    }
}
