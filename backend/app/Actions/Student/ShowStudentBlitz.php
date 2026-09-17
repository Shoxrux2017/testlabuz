<?php

namespace App\Actions\Student;

use App\Enums\BlitzStatus;
use App\Exceptions\Student\StudentBlitzNotActiveException;
use App\Models\Assessment;
use App\Models\BlitzTask;
use App\Models\Topic;
use App\Models\User;
use App\Support\Student\StudentBlitzAccess;
use App\Support\Student\StudentBlitzAttemptSummary;
use App\Support\Student\StudentBlitzTiming;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class ShowStudentBlitz
{
    public function __construct(
        private readonly StudentBlitzAccess $access,
        private readonly StudentBlitzAttemptSummary $attemptSummary,
        private readonly StudentBlitzTiming $timing,
        private readonly ReconcileStudentBlitzTimeouts $reconcileTimeouts,
    ) {}

    public function __invoke(User $student, string $blitzId): Assessment
    {
        $authorized = $this->access->resolveAssigned($student, $blitzId);
        $readAt = $this->timing->now();
        $this->reconcileTimeouts->one($student, $authorized, $readAt);
        $assessment = $this->access->readQuery($student)->whereKey($authorized->id)->first();

        if ($assessment === null) {
            throw new NotFoundHttpException;
        }

        $blitz = $assessment->getRelation('blitzTask');

        if (! $blitz instanceof BlitzTask || ! $assessment->getRelation('topic') instanceof Topic) {
            throw new LogicException('Student Blitz requires its scoped task and Topic projection.');
        }

        if ($blitz->status !== BlitzStatus::Active) {
            throw new StudentBlitzNotActiveException;
        }

        $this->timing->assertValidTask($blitz);
        $attempt = $this->attemptSummary->validateHistory(
            $student, $assessment, $blitz, $assessment->getAttribute('student_recipient_id'), $assessment->getRelation('attempts'),
        );
        $this->timing->assertExecutable($blitz, $attempt, $readAt);
        $assessment->setAttribute('student_blitz_timing', $this->timing->project($blitz, $attempt, $readAt));
        $assessment->setAttribute('student_blitz_attempt_summary', $this->attemptSummary->project($attempt));

        return $assessment;
    }
}
