<?php

namespace App\Actions\Teacher;

use App\Exceptions\ResultClosedException;
use App\Models\TopicResult;
use App\Models\User;
use App\Support\Results\TeacherTopicResultEntry;
use App\Support\Results\TopicResultReader;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * Saves the Teacher's Topic-result comment (S10-D1, docs/09 §25.7). The Topic lock serializes it with
 * closure; a closed result keeps its comment. An unchanged value writes nothing.
 */
final class UpdateTeacherTopicResultComment
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TopicResultReader $reader,
        private readonly ShowTeacherTopicResult $show,
    ) {}

    public function __invoke(User $teacher, string $topicId, string $studentId, ?string $comment): TeacherTopicResultEntry
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);

        if (! Str::isUuid($studentId)) {
            throw new NotFoundHttpException;
        }

        $studentId = strtolower($studentId);

        DB::transaction(function () use ($teacher, $topic, $studentId, $comment): void {
            ['topic' => $locked] = $this->access->lockTopic($teacher, $topic);

            if ($this->reader->forStudent($locked, $studentId) === null) {
                throw new NotFoundHttpException;
            }

            $row = TopicResult::query()
                ->where('institution_id', $locked->institution_id)
                ->where('topic_id', $locked->id)
                ->where('student_id', $studentId)
                ->lockForUpdate()
                ->first();

            if ($row?->closed_at !== null) {
                throw new ResultClosedException;
            }

            if ($row?->teacher_comment === $comment) {
                return;
            }

            ($row ?? new TopicResult([
                'institution_id' => $locked->institution_id,
                'topic_id' => $locked->id,
                'student_id' => $studentId,
            ]))->fill([
                'teacher_comment' => $comment,
                'teacher_comment_updated_by_user_id' => $teacher->id,
                'teacher_comment_updated_at' => now(),
            ])->save();
        });

        return ($this->show)($teacher, $topicId, $studentId);
    }
}
