<?php

namespace App\Support\Student;

use App\Enums\AssessmentType;
use App\Enums\HomeworkStatus;
use App\Models\Assessment;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class StudentHomeworkAccess
{
    /** @return Builder<Assessment> */
    public function query(User $student): Builder
    {
        return Assessment::query()
            ->select([
                'assessments.id',
                'assessments.institution_id',
                'assessments.topic_id',
                'assessments.title',
                'assessments.description',
                'assessments.student_instructions',
                'assessments.total_possible_points',
                'assessment_students.id as student_recipient_id',
            ])
            ->join('homework_assignments', 'homework_assignments.assessment_id', '=', 'assessments.id')
            ->join('assessment_students', 'assessment_students.assessment_id', '=', 'assessments.id')
            ->where('assessments.institution_id', $student->institution_id)
            ->where('assessments.type', AssessmentType::Homework->value)
            ->where('assessment_students.institution_id', $student->institution_id)
            ->where('assessment_students.student_id', $student->id)
            ->where('homework_assignments.institution_id', $student->institution_id)
            ->whereIn('homework_assignments.status', [
                HomeworkStatus::Active->value,
                HomeworkStatus::Closed->value,
                HomeworkStatus::Archived->value,
            ])
            ->with(['homeworkAssignment' => fn ($query) => $query
                ->select(['assessment_id', 'institution_id', 'status', 'deadline_at'])
                ->where('institution_id', $student->institution_id)]);
    }

    public function resolve(User $student, string $homeworkId): Assessment
    {
        if (! Str::isUuid($homeworkId)) {
            throw new NotFoundHttpException;
        }

        $homework = $this->query($student)->whereKey($homeworkId)->first();

        if (! $homework instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        return $homework;
    }

    /** @return Builder<Assessment> */
    public function readQuery(User $student): Builder
    {
        return $this->query($student)->with([
            'topic' => fn ($query) => $query
                ->select(['id', 'title'])
                ->where('institution_id', $student->institution_id),
            'attempts' => fn ($query) => $query
                ->select([
                    'id', 'institution_id', 'assessment_id', 'assessment_student_id', 'student_id',
                    'attempt_number', 'status', 'started_at', 'submitted_at', 'finalized_at',
                    'finalization_reason', 'locked_at', 'deadline_at',
                ])
                // Validate the complete recipient graph after loading this Student's rows.
                ->where('student_id', $student->id)
                ->orderBy('attempt_number'),
        ]);
    }
}
