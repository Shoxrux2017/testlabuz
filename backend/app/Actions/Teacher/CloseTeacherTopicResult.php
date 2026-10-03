<?php

namespace App\Actions\Teacher;

use App\Exceptions\ResultNotReadyForClosureException;
use App\Models\User;
use App\Support\Results\TeacherTopicResultEntry;
use App\Support\Results\TopicResultActionOutcome;
use App\Support\Results\TopicResultClosures;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/** Closes one cohort Student's Topic result into its snapshot (docs/09 §25.8); idempotent. */
final class CloseTeacherTopicResult
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TopicResultClosures $closures,
        private readonly ShowTeacherTopicResult $show,
    ) {}

    public function __invoke(User $teacher, string $topicId, string $studentId): TeacherTopicResultEntry
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);

        if (! Str::isUuid($studentId)) {
            throw new NotFoundHttpException;
        }

        $studentId = strtolower($studentId);

        DB::transaction(function () use ($teacher, $topic, $studentId): void {
            ['topic' => $locked] = $this->access->lockTopic($teacher, $topic);
            $outcome = $this->closures->closeOne($teacher, $locked, $studentId) ?? throw new NotFoundHttpException;

            if ($outcome === TopicResultActionOutcome::NotReady) {
                throw new ResultNotReadyForClosureException;
            }
        });

        return ($this->show)($teacher, $topicId, $studentId);
    }
}
