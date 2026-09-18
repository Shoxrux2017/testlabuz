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
                    'status', 'started_at', 'deadline_at', 'possible_points', 'official_score_eligible', 'submitted_at', 'finalized_at', 'finalization_reason', 'locked_at'])
                ->where('institution_id', $student->institution_id)
                ->where('student_id', $student->id)
                ->orderBy('attempt_number')->orderBy('id'),
            'blitzAttemptExceptions' => fn ($query) => $query
                ->select(['id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id',
                    'invalidated_attempt_id', 'replacement_attempt_id'])
                ->where('institution_id', $student->institution_id)->where('student_id', $student->id),
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
                ->where(fn (Builder $unused) => $unused->whereDoesntHave('attempts', $ownAttempts)
                    ->where(fn (Builder $timer) => $timer
                        ->where('blitz_tasks.timer_start_mode_snapshot', BlitzTimerStartMode::Individual->value)
                        ->orWhere('blitz_tasks.synchronized_ends_at', '>', $readAt)
                        ->orWhereNull('blitz_tasks.timer_start_mode_snapshot')
                        ->orWhereNull('blitz_tasks.synchronized_ends_at')))
                ->orWhereHas('blitzAttemptExceptions', fn (Builder $exceptions) => $exceptions
                    ->where('institution_id', $student->institution_id)->where('student_id', $student->id))
                ->orWhereHas('attempts', fn (Builder $attempts) => $ownAttempts($attempts)
                    ->where(fn (Builder $history) => $history
                        ->where('status', AssessmentAttemptStatus::InProgress->value)
                        ->orWhere('attempt_number', '<>', 1)
                        ->orWhere('official_score_eligible', false)
                        ->orWhereNull('deadline_at')))
                ->orWhereHas('attempts', $ownAttempts, '>', 1))
            ->orderByDesc('blitz_tasks.activated_at')->orderByDesc('assessments.id');
    }
}
