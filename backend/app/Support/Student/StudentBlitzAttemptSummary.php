<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

final class StudentBlitzAttemptSummary
{
    public function __construct(private readonly StudentBlitzTiming $timing) {}

    /** @param Collection<int, AssessmentAttempt> $attempts */
    public function validateHistory(User $student, Assessment $assessment, BlitzTask $blitz, string $recipientId, Collection $attempts): ?AssessmentAttempt
    {
        if ($attempts->count() > 1) {
            throw new LogicException('Blitz history supports only one normal Attempt.');
        }

        $attempt = $attempts->first();

        if ($attempt === null) {
            return null;
        }

        if ($attempt->institution_id !== $student->institution_id
            || $attempt->assessment_id !== $assessment->id
            || $attempt->student_id !== $student->id
            || $attempt->assessment_student_id !== $recipientId
            || $attempt->attempt_number !== 1
            || $attempt->possible_points !== $assessment->total_possible_points
            || ! $attempt->status instanceof AssessmentAttemptStatus) {
            throw new LogicException('Blitz Attempt must match its authoritative normal recipient history.');
        }

        if ($attempt->status === AssessmentAttemptStatus::InProgress
            && ($attempt->submitted_at !== null || $attempt->finalized_at !== null
                || $attempt->locked_at !== null || $attempt->finalization_reason !== null)) {
            throw new LogicException('An in-progress Blitz Attempt must remain structurally editable.');
        }

        $this->timing->assertValidAttempt($blitz, $attempt);

        return $attempt;
    }

    /** @return array<string, mixed> */
    public function project(?AssessmentAttempt $attempt): array
    {
        return [
            'normal_attempts' => 1,
            'normal_used' => $attempt === null ? 0 : 1,
            'in_progress_attempt_id' => $attempt?->status === AssessmentAttemptStatus::InProgress ? $attempt->id : null,
            'additional_exception_granted' => false,
            'replacement_attempt_available' => false,
        ];
    }
}
