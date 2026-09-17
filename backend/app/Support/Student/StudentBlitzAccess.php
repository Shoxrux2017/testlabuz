<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use App\Models\Assessment;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class StudentBlitzAccess
{
    /** @return Builder<Assessment> */
    public function query(User $student): Builder
    {
        return Assessment::query()
            ->select([
                'assessments.id', 'assessments.institution_id', 'assessments.topic_id',
                'assessments.title', 'assessments.description', 'assessments.student_instructions',
                'assessments.assignment_mode', 'assessments.total_possible_points',
                'assessment_students.id as student_recipient_id',
            ])
            ->join('blitz_tasks', 'blitz_tasks.assessment_id', '=', 'assessments.id')
            ->join('assessment_students', 'assessment_students.assessment_id', '=', 'assessments.id')
            ->where('assessments.institution_id', $student->institution_id)
            ->where('assessments.type', AssessmentType::Blitz->value)
            ->where('blitz_tasks.institution_id', $student->institution_id)
            ->where('assessment_students.institution_id', $student->institution_id)
            ->where('assessment_students.student_id', $student->id);
    }

    public function resolveAssigned(User $student, string $blitzId): Assessment
    {
        if (! Str::isUuid($blitzId)) {
            throw new NotFoundHttpException;
        }

        $assessment = $this->query($student)->whereKey($blitzId)->first();

        if ($assessment === null) {
            throw new NotFoundHttpException;
        }

        return $assessment;
    }

    /** @return Builder<Assessment> */
    public function readQuery(User $student): Builder
    {
        return $this->query($student)->with([
            'topic' => fn ($query) => $query->select(['id', 'title'])->where('institution_id', $student->institution_id),
            'blitzTask' => fn ($query) => $query
                ->select(['assessment_id', 'institution_id', 'status', 'duration_seconds', 'activated_at', 'timer_start_mode_snapshot', 'synchronized_ends_at'])
                ->where('institution_id', $student->institution_id),
            'attempts' => fn ($query) => $query
                ->select(['id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id', 'attempt_number',
                    'status', 'started_at', 'deadline_at', 'possible_points', 'submitted_at', 'finalized_at', 'finalization_reason', 'locked_at'])
                ->where('institution_id', $student->institution_id)
                ->where('student_id', $student->id)
                ->orderBy('attempt_number')->orderBy('id'),
        ]);
    }

    /** @return Builder<Assessment> */
    public function activeQuery(User $student, CarbonInterface $readAt): Builder
    {
        $ownAttempts = fn (Builder $query) => $query
            ->where('institution_id', $student->institution_id)->where('student_id', $student->id);

        return $this->readQuery($student)
            ->where('blitz_tasks.status', BlitzStatus::Active->value)
            ->where(fn (Builder $query) => $query
                ->where('blitz_tasks.timer_start_mode_snapshot', BlitzTimerStartMode::Individual->value)
                ->orWhere('blitz_tasks.synchronized_ends_at', '>', $readAt)
                ->orWhereNull('blitz_tasks.timer_start_mode_snapshot')
                ->orWhere(fn (Builder $query) => $query
                    ->where('blitz_tasks.timer_start_mode_snapshot', BlitzTimerStartMode::Synchronized->value)
                    ->whereNull('blitz_tasks.synchronized_ends_at')))
            ->where(fn (Builder $query) => $query
                ->whereDoesntHave('attempts', $ownAttempts)
                ->orWhereHas('attempts', fn (Builder $attempts) => $ownAttempts($attempts)
                    ->where(fn (Builder $history) => $history
                        ->where(fn (Builder $current) => $current
                            ->where('status', AssessmentAttemptStatus::InProgress->value)
                            ->where('deadline_at', '>', $readAt))
                        ->orWhere('attempt_number', '<>', 1)
                        ->orWhereNull('deadline_at')))
                // Corrupt multi-row history must reach validation instead of silently losing capacity.
                ->orWhereHas('attempts', $ownAttempts, '>', 1))
            ->orderByDesc('blitz_tasks.activated_at')
            ->orderByDesc('assessments.id');
    }
}
