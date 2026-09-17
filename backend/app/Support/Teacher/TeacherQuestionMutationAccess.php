<?php

namespace App\Support\Teacher;

use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Exceptions\Teacher\AssessmentHasNoScoreablePointsException;
use App\Exceptions\Teacher\BusinessConflictException;
use App\Exceptions\Teacher\ResultPairLockedException;
use App\Exceptions\Teacher\TaskArchivedException;
use App\Exceptions\Teacher\TaskClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\Question;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Str;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class TeacherQuestionMutationAccess
{
    public function __construct(
        private readonly TeacherHomeworkAccess $homeworkAccess,
        private readonly TeacherBlitzAccess $blitzAccess,
    ) {}

    public function resolveAssessment(User $teacher, string $assessmentId): Assessment
    {
        if (! Str::isUuid($assessmentId)) {
            throw new NotFoundHttpException;
        }

        $assessment = $this->visibleAssessmentQuery($teacher)->whereKey($assessmentId)->first();

        if (! $assessment instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        return $assessment;
    }

    public function resolveAssessmentForQuestion(User $teacher, string $questionId): Assessment
    {
        if (! Str::isUuid($questionId)) {
            throw new NotFoundHttpException;
        }

        $assessment = $this->visibleAssessmentQuery($teacher)
            ->whereHas('questions', fn (Builder $query) => $query
                ->where('questions.institution_id', $teacher->institution_id)
                ->whereKey($questionId))
            ->first();

        if (! $assessment instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        return $assessment;
    }

    /**
     * @return array{
     *     assessment: Assessment,
     *     task: HomeworkAssignment|BlitzTask,
     *     questions: Collection<int, Question>
     * }
     */
    public function lock(User $teacher, Assessment $preliminaryAssessment): array
    {
        $context = match ($preliminaryAssessment->type) {
            AssessmentType::Homework => $this->homeworkAccess->lockHomework($teacher, $preliminaryAssessment),
            AssessmentType::Blitz => $this->blitzAccess->lockBlitz($teacher, $preliminaryAssessment),
            default => throw new LogicException('Unsupported Assessment Question authoring type.'),
        };
        $assessment = $context['assessment'];
        $task = $context['homework'] ?? $context['blitz'];
        $topic = $context['topic'];
        $resultPair = TopicResultPair::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->where(
                $assessment->type === AssessmentType::Homework ? 'homework_assessment_id' : 'blitz_assessment_id',
                $assessment->id,
            )
            ->orderBy('id')
            ->lockForUpdate()
            ->first();
        $attempts = AssessmentAttempt::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('id')
            ->lockForUpdate()
            ->get(['id']);
        $questions = Question::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('assessment_id', $assessment->id)
            ->orderBy('position')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        if (in_array($topic->status, [TopicStatus::Closed, TopicStatus::Archived], true)) {
            throw new TopicNotEditableException;
        }

        if ($task->status === BlitzStatus::Active) {
            throw new BusinessConflictException;
        }

        if (in_array($task->status, [HomeworkStatus::Closed, BlitzStatus::Closed], true)) {
            throw new TaskClosedException;
        }

        if (in_array($task->status, [HomeworkStatus::Archived, BlitzStatus::Archived], true)) {
            throw new TaskArchivedException;
        }

        if ($task instanceof HomeworkAssignment
            && $resultPair instanceof TopicResultPair
            && $resultPair->locked_at !== null) {
            throw new ResultPairLockedException;
        }

        if ($attempts->isNotEmpty()) {
            throw new BusinessConflictException;
        }

        return compact('assessment', 'task', 'questions');
    }

    public function ensureActiveResultIsScoreable(
        HomeworkAssignment|BlitzTask $task,
        int $questionCount,
        string $totalPossiblePoints,
    ): void {
        if ($task instanceof HomeworkAssignment
            && $task->status === HomeworkStatus::Active
            && ($questionCount === 0 || $totalPossiblePoints === '0.000000')) {
            throw new AssessmentHasNoScoreablePointsException;
        }
    }

    private function visibleAssessmentQuery(User $teacher): Builder
    {
        return Assessment::query()
            ->select(['id', 'institution_id', 'topic_id', 'teacher_id', 'type'])
            ->where('institution_id', $teacher->institution_id)
            ->where('teacher_id', $teacher->id)
            ->whereHas('topic', fn (Builder $query) => $query->visibleToTeacher($teacher))
            ->where(fn (Builder $query) => $query
                ->where(fn (Builder $query) => $query
                    ->where('type', AssessmentType::Homework->value)
                    ->whereHas('homeworkAssignment', fn (Builder $query) => $query
                        ->where('institution_id', $teacher->institution_id)))
                ->orWhere(fn (Builder $query) => $query
                    ->where('type', AssessmentType::Blitz->value)
                    ->whereHas('blitzTask', fn (Builder $query) => $query
                        ->where('institution_id', $teacher->institution_id))))
            ->with('topic:id,institution_id,group_id,teacher_id,status');
    }
}
