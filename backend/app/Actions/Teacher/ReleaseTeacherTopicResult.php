<?php

namespace App\Actions\Teacher;

use App\Enums\TopicResultReleaseAudience;
use App\Exceptions\ResultNotReadyException;
use App\Exceptions\StudentResultNotReleasedException;
use App\Models\User;
use App\Support\Results\TeacherTopicResultEntry;
use App\Support\Results\TopicResultActionOutcome;
use App\Support\Results\TopicResultReader;
use App\Support\Results\TopicResultReleases;
use App\Support\Teacher\TeacherTopicLifecycleAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/** Releases one cohort Student's Topic result to the Student or to Parents (docs/09 §27.3-27.4); idempotent. */
final class ReleaseTeacherTopicResult
{
    public function __construct(
        private readonly TeacherTopicLifecycleAccess $access,
        private readonly TopicResultReader $reader,
        private readonly TopicResultReleases $releases,
        private readonly ShowTeacherTopicResult $show,
    ) {}

    public function __invoke(User $teacher, string $topicId, string $studentId, TopicResultReleaseAudience $audience): TeacherTopicResultEntry
    {
        $topic = $this->access->resolveTopic($teacher, $topicId);

        if (! Str::isUuid($studentId)) {
            throw new NotFoundHttpException;
        }

        $studentId = strtolower($studentId);

        DB::transaction(function () use ($teacher, $topic, $studentId, $audience): void {
            ['topic' => $locked] = $this->access->lockTopic($teacher, $topic);
            $result = $this->reader->forStudent($locked, $studentId) ?? throw new NotFoundHttpException;
            [$outcome] = $this->releases->release($teacher, $locked, [$result], $audience);

            if ($outcome === TopicResultActionOutcome::NotReady) {
                throw $audience === TopicResultReleaseAudience::Student
                    ? new ResultNotReadyException
                    : new StudentResultNotReleasedException;
            }
        });

        return ($this->show)($teacher, $topicId, $studentId);
    }
}
