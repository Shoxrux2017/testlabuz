<?php

namespace App\Support\Student;

use App\Enums\AssessmentType;
use App\Models\AssessmentAttempt;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class StudentAttemptAnswerTarget
{
    public function resolve(User $student, string $attemptId): AssessmentType
    {
        if (! Str::isUuid($attemptId)) {
            throw new NotFoundHttpException;
        }

        $attempt = AssessmentAttempt::query()
            ->select(['id', 'assessment_id'])
            ->where('institution_id', $student->institution_id)
            ->where('student_id', $student->id)
            ->whereHas('assessmentStudent', fn (Builder $query) => $query
                ->where('institution_id', $student->institution_id)
                ->where('student_id', $student->id)
                ->whereColumn('assessment_students.assessment_id', 'assessment_attempts.assessment_id'))
            ->whereHas('assessment', fn (Builder $query) => $query
                ->where('institution_id', $student->institution_id)
                ->whereIn('type', [AssessmentType::Homework->value, AssessmentType::Blitz->value]))
            ->with(['assessment' => fn ($query) => $query
                ->select(['id', 'type'])->where('institution_id', $student->institution_id)
                ->whereIn('type', [AssessmentType::Homework->value, AssessmentType::Blitz->value])])
            ->whereKey($attemptId)->first();

        if ($attempt === null || $attempt->assessment === null) {
            throw new NotFoundHttpException;
        }

        return $attempt->assessment->type;
    }
}
