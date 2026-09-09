<?php

namespace App\Actions\Student;

use App\Actions\Homework\FinalizeHomeworkAttemptsAtDeadline;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Models\Assessment;
use App\Models\HomeworkAssignment;
use App\Models\User;
use App\Support\Student\StudentHomeworkAccess;
use Carbon\CarbonInterface;
use Illuminate\Database\Query\Builder;
use LogicException;

final class ReconcileStudentHomeworkDeadlines
{
    public function __construct(
        private readonly StudentHomeworkAccess $access,
        private readonly FinalizeHomeworkAttemptsAtDeadline $finalizeAtDeadline,
    ) {}

    public function all(User $student, CarbonInterface $readAt): void
    {
        $candidates = $this->access->query($student)
            ->withoutEagerLoads()
            ->select('assessments.id')
            ->where('homework_assignments.status', HomeworkStatus::Active->value)
            ->whereNotNull('homework_assignments.deadline_at')
            ->where('homework_assignments.deadline_at', '<=', $readAt)
            ->whereExists(fn (Builder $query) => $query
                ->selectRaw('1')
                ->from('assessment_attempts')
                ->whereColumn('assessment_attempts.institution_id', 'assessments.institution_id')
                ->whereColumn('assessment_attempts.assessment_id', 'assessments.id')
                ->whereColumn('assessment_attempts.assessment_student_id', 'assessment_students.id')
                ->where('assessment_attempts.student_id', $student->id)
                ->where('assessment_attempts.status', AssessmentAttemptStatus::InProgress->value))
            ->lazyById(100, 'assessments.id', 'id');

        foreach ($candidates as $homework) {
            ($this->finalizeAtDeadline)($student->institution_id, $homework->id);
        }
    }

    public function one(User $student, Assessment $authorizedHomework, CarbonInterface $readAt): void
    {
        if (! $authorizedHomework->relationLoaded('homeworkAssignment')) {
            throw new LogicException('Authorized Homework deadline state must be loaded.');
        }

        $homework = $authorizedHomework->getRelation('homeworkAssignment');

        if (! $homework instanceof HomeworkAssignment
            || $homework->institution_id !== $student->institution_id
            || $homework->assessment_id !== $authorizedHomework->id) {
            throw new LogicException('Authorized Homework deadline state must belong to the Student institution.');
        }

        if ($homework->status === HomeworkStatus::Active
            && $homework->deadline_at !== null
            && $homework->deadline_at->lte($readAt)) {
            ($this->finalizeAtDeadline)($student->institution_id, $authorizedHomework->id);
        }
    }
}
