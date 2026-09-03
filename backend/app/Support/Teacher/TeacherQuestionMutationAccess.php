<?php

namespace App\Support\Teacher;

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
use App\Models\HomeworkAssignment;
use App\Models\Question;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;

final class TeacherQuestionMutationAccess
{
    public function __construct(
        private readonly TeacherHomeworkAccess $homeworkAccess,
    ) {}

    /**
     * @return array{
     *     assessment: Assessment,
     *     homework: HomeworkAssignment,
     *     questions: Collection<int, Question>
     * }
     */
    public function lock(User $teacher, Assessment $preliminaryAssessment): array
    {
        $context = $this->homeworkAccess->lockHomework($teacher, $preliminaryAssessment);
        $assessment = $context['assessment'];
        $homework = $context['homework'];
        $topic = $context['topic'];
        $resultPair = TopicResultPair::query()
            ->where('institution_id', $teacher->institution_id)
            ->where('topic_id', $topic->id)
            ->where('homework_assessment_id', $assessment->id)
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

        if ($homework->status === HomeworkStatus::Closed) {
            throw new TaskClosedException;
        }

        if ($homework->status === HomeworkStatus::Archived) {
            throw new TaskArchivedException;
        }

        if ($resultPair instanceof TopicResultPair && $resultPair->locked_at !== null) {
            throw new ResultPairLockedException;
        }

        if ($attempts->isNotEmpty()) {
            throw new BusinessConflictException;
        }

        return compact('assessment', 'homework', 'questions');
    }

    public function ensureActiveResultIsScoreable(
        HomeworkAssignment $homework,
        int $questionCount,
        string $totalPossiblePoints,
    ): void {
        if ($homework->status === HomeworkStatus::Active
            && ($questionCount === 0 || $totalPossiblePoints === '0.000000')) {
            throw new AssessmentHasNoScoreablePointsException;
        }
    }
}
