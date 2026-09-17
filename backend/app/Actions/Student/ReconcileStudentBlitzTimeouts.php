<?php

namespace App\Actions\Student;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\User;
use App\Support\Student\StudentBlitzAccess;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

final class ReconcileStudentBlitzTimeouts
{
    public function __construct(
        private readonly StudentBlitzAccess $access,
        private readonly FinalizeTimedOutBlitzAttempts $finalizeTimeouts,
    ) {}

    public function all(User $student, CarbonInterface $readAt): void
    {
        foreach ($this->candidates($student, $readAt)->lazyById(100, 'assessments.id', 'id') as $assessment) {
            ($this->finalizeTimeouts)($student->institution_id, $assessment->id);
        }
    }

    public function one(User $student, Assessment $authorized, CarbonInterface $readAt): void
    {
        if ($this->candidates($student, $readAt)->whereKey($authorized->id)->exists()) {
            ($this->finalizeTimeouts)($student->institution_id, $authorized->id);
        }
    }

    /** @return Builder<Assessment> */
    private function candidates(User $student, CarbonInterface $readAt): Builder
    {
        return $this->access->query($student)->select('assessments.id')
            ->where('blitz_tasks.status', BlitzStatus::Active->value)
            ->whereExists(fn (QueryBuilder $query) => $query->selectRaw('1')->from('assessment_attempts')
                ->whereColumn('assessment_attempts.institution_id', 'assessments.institution_id')
                ->whereColumn('assessment_attempts.assessment_id', 'assessments.id')
                ->whereColumn('assessment_attempts.assessment_student_id', 'assessment_students.id')
                ->where('assessment_attempts.student_id', $student->id)
                ->where('assessment_attempts.status', AssessmentAttemptStatus::InProgress->value)
                ->where('assessment_attempts.deadline_at', '<=', $readAt));
    }
}
