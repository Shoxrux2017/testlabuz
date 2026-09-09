<?php

namespace App\Support\Student;

use App\Enums\AssessmentType;
use App\Enums\HomeworkStatus;
use App\Exceptions\Student\StudentAssessmentNotAssignedException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class StudentHomeworkAttemptAccess
{
    public function resolveAttempt(User $student, string $attemptId): AssessmentAttempt
    {
        if (! Str::isUuid($attemptId)) {
            throw new NotFoundHttpException;
        }

        $attempt = $this->ownAttemptQuery($student)
            ->whereKey($attemptId)
            ->whereHas('assessment', fn (Builder $query) => $query
                ->where('institution_id', $student->institution_id)
                ->where('type', AssessmentType::Homework->value)
                ->whereHas('homeworkAssignment', fn (Builder $homework) => $homework
                    ->where('institution_id', $student->institution_id)
                    ->whereIn('status', [HomeworkStatus::Active->value, HomeworkStatus::Closed->value, HomeworkStatus::Archived->value])))
            ->first();

        if ($attempt === null) {
            throw new NotFoundHttpException;
        }

        return $attempt;
    }

    public function replayAttempt(User $student, Assessment $assessment, string $attemptId): ?AssessmentAttempt
    {
        return $this->ownAttemptQuery($student)
            ->where('assessment_id', $assessment->id)
            ->whereKey($attemptId)
            ->with(['assessmentStudent' => fn ($query) => $query->where('institution_id', $student->institution_id)])
            ->first();
    }

    /** @return array{topic: Topic, assessment: Assessment, homework: HomeworkAssignment} */
    public function lockHomework(User $student, Assessment $preliminaryAssessment): array
    {
        return $this->lockHomeworkRows($student, $preliminaryAssessment, exclusive: true);
    }

    /** @return array{topic: Topic, assessment: Assessment, homework: HomeworkAssignment} */
    public function shareHomeworkForAnswer(User $student, Assessment $preliminaryAssessment): array
    {
        return $this->lockHomeworkRows($student, $preliminaryAssessment, exclusive: false);
    }

    /** @return array{topic: Topic, assessment: Assessment, homework: HomeworkAssignment} */
    private function lockHomeworkRows(User $student, Assessment $preliminaryAssessment, bool $exclusive): array
    {
        $topic = Topic::query()
            ->where('institution_id', $student->institution_id)
            ->whereKey($preliminaryAssessment->topic_id)
            ->lock($exclusive)
            ->first();

        if ($topic === null) {
            throw new NotFoundHttpException;
        }

        $assessment = Assessment::query()
            ->where('institution_id', $student->institution_id)
            ->where('topic_id', $topic->id)
            ->where('type', AssessmentType::Homework->value)
            ->whereKey($preliminaryAssessment->id)
            ->lock($exclusive)
            ->first();

        if ($assessment === null) {
            throw new NotFoundHttpException;
        }

        $homework = HomeworkAssignment::query()
            ->where('institution_id', $student->institution_id)
            ->where('assessment_id', $assessment->id)
            ->lock($exclusive)
            ->first();

        if ($homework === null) {
            throw new NotFoundHttpException;
        }

        return compact('topic', 'assessment', 'homework');
    }

    public function lockRecipient(User $student, Assessment $assessment): AssessmentStudent
    {
        $recipient = AssessmentStudent::query()
            ->where('institution_id', $student->institution_id)
            ->where('assessment_id', $assessment->id)
            ->where('student_id', $student->id)
            ->lockForUpdate()
            ->first();

        if ($recipient === null) {
            throw new StudentAssessmentNotAssignedException;
        }

        return $recipient;
    }

    public function lockPair(User $student, Topic $topic): ?TopicResultPair
    {
        return TopicResultPair::query()
            ->where('institution_id', $student->institution_id)
            ->where('topic_id', $topic->id)
            ->lockForUpdate()
            ->first();
    }

    /** @return Collection<int, AssessmentAttempt> */
    public function lockStudentAttempts(User $student, Assessment $assessment): Collection
    {
        return $this->assessmentAttemptsQuery($student, $assessment)
            ->where('student_id', $student->id)
            ->orderBy('attempt_number')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }

    /** @return Collection<int, AssessmentAttempt> */
    public function lockAllAttempts(User $student, Assessment $assessment): Collection
    {
        return $this->assessmentAttemptsQuery($student, $assessment)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }

    /** @return Builder<AssessmentAttempt> */
    private function assessmentAttemptsQuery(User $student, Assessment $assessment): Builder
    {
        return AssessmentAttempt::query()
            ->where('institution_id', $student->institution_id)
            ->where('assessment_id', $assessment->id)
            ->with(['assessmentStudent' => fn ($query) => $query
                ->select(['id', 'institution_id', 'assessment_id', 'student_id'])
                ->where('institution_id', $student->institution_id)]);
    }

    /** @return Builder<AssessmentAttempt> */
    private function ownAttemptQuery(User $student): Builder
    {
        return AssessmentAttempt::query()
            ->where('institution_id', $student->institution_id)
            ->where('student_id', $student->id)
            ->whereHas('assessmentStudent', fn (Builder $query) => $query
                ->where('institution_id', $student->institution_id)
                ->where('student_id', $student->id)
                ->whereColumn('assessment_students.assessment_id', 'assessment_attempts.assessment_id'));
    }
}
