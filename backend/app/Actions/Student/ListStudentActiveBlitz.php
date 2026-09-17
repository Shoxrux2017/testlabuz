<?php

namespace App\Actions\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\Topic;
use App\Models\User;
use App\Support\Student\StudentBlitzAccess;
use App\Support\Student\StudentBlitzAttemptSummary;
use App\Support\Student\StudentBlitzTiming;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

final class ListStudentActiveBlitz
{
    public function __construct(
        private readonly StudentBlitzAccess $access,
        private readonly StudentBlitzAttemptSummary $attemptSummary,
        private readonly StudentBlitzTiming $timing,
        private readonly ReconcileStudentBlitzTimeouts $reconcileTimeouts,
    ) {}

    /** @return Collection<int, Assessment> */
    public function __invoke(User $student): Collection
    {
        $readAt = $this->timing->now();
        $this->reconcileTimeouts->all($student, $readAt);
        $assessments = $this->access->activeQuery($student, $readAt)->get();
        $eligible = new Collection;

        foreach ($assessments as $assessment) {
            $blitz = $assessment->getRelation('blitzTask');

            if (! $blitz instanceof BlitzTask || ! $assessment->getRelation('topic') instanceof Topic) {
                throw new LogicException('Student Blitz requires its scoped task and Topic projection.');
            }

            if ($blitz->status !== BlitzStatus::Active) {
                continue;
            }

            $this->timing->assertValidTask($blitz);
            $attempt = $this->attemptSummary->validateHistory(
                $student, $assessment, $blitz, $assessment->getAttribute('student_recipient_id'), $assessment->getRelation('attempts'),
            );

            // Eager reads may observe lifecycle/activity committed after the eligible base query.
            if ($attempt !== null && $attempt->status !== AssessmentAttemptStatus::InProgress) {
                continue;
            }

            $timing = $this->timing->project($blitz, $attempt, $readAt);

            if ($timing['remaining_seconds'] === 0) {
                continue;
            }

            $assessment->setAttribute('student_blitz_timing', $timing);
            $assessment->setAttribute('student_blitz_attempt_summary', $this->attemptSummary->project($attempt));
            $eligible->push($assessment);
        }

        return $eligible;
    }
}
