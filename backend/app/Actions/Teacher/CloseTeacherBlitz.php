<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskNotActiveException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\User;
use App\Support\Assessment\BlitzAttemptFinalizer;
use App\Support\Teacher\TeacherBlitzLifecycleAccess;
use Illuminate\Support\Facades\DB;

final class CloseTeacherBlitz
{
    public function __construct(
        private readonly TeacherBlitzLifecycleAccess $access,
        private readonly ShowTeacherBlitz $showTeacherBlitz,
        private readonly BlitzAttemptFinalizer $finalizer,
    ) {}

    public function __invoke(User $teacher, string $blitzId): Assessment
    {
        $preliminaryAssessment = $this->access->resolveBlitz($teacher, $blitzId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment): Assessment {
            ['topic' => $topic, 'assessment' => $assessment, 'blitz' => $blitz] =
                $this->access->lockBlitz($teacher, $preliminaryAssessment);

            if ($blitz->status === BlitzStatus::Closed) {
                return ($this->showTeacherBlitz)($teacher, $assessment->id);
            }

            if (in_array($blitz->status, [BlitzStatus::Draft, BlitzStatus::Scheduled], true)) {
                throw new TaskNotActiveException;
            }

            if ($blitz->status === BlitzStatus::Archived) {
                throw new TaskArchivedException;
            }

            if ($topic->status === TopicStatus::Archived) {
                throw new TopicNotEditableException;
            }

            $this->access->lockResultPair($teacher, $topic, $assessment);
            $attempts = AssessmentAttempt::query()
                ->where('institution_id', $teacher->institution_id)
                ->where('assessment_id', $assessment->id)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            foreach ($attempts as $attempt) {
                if ($attempt->status === AssessmentAttemptStatus::InProgress) {
                    $this->finalizer->assertValidAttempt($attempt, $assessment->institution_id, $assessment->id);
                }
            }

            $closedAt = now();

            foreach ($attempts as $attempt) {
                if ($attempt->status !== AssessmentAttemptStatus::InProgress) {
                    continue;
                }

                if ($closedAt->greaterThanOrEqualTo($attempt->deadline_at)) {
                    $this->finalizer->finalizeAtTimeout($attempt);
                } else {
                    $this->finalizer->finalizeAtClose($attempt, $closedAt);
                }
            }

            $blitz->status = BlitzStatus::Closed;
            $blitz->closed_at = $closedAt;
            $blitz->updated_at = $closedAt;
            $blitz->save();
            $assessment->updated_at = $closedAt;
            $assessment->save();

            return ($this->showTeacherBlitz)($teacher, $assessment->id);
        });
    }
}
