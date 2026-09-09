<?php

namespace App\Actions\Student;

use App\Models\Assessment;
use App\Models\InstitutionSetting;
use App\Models\User;
use App\Support\Student\StudentHomeworkAccess;
use App\Support\Student\StudentHomeworkAttemptSummary;
use App\Support\Student\StudentQuestionAnswerUi;
use LogicException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class ShowStudentHomework
{
    public function __construct(
        private readonly StudentHomeworkAccess $access,
        private readonly ReconcileStudentHomeworkDeadlines $reconcileDeadlines,
        private readonly StudentHomeworkAttemptSummary $attemptSummary,
        private readonly StudentQuestionAnswerUi $answerUi,
    ) {}

    public function __invoke(User $student, string $homeworkId): Assessment
    {
        $authorizedHomework = $this->access->resolve($student, $homeworkId);
        $readAt = now();
        $this->reconcileDeadlines->one($student, $authorizedHomework, $readAt);

        $homework = $this->access->readQuery($student)
            ->whereKey($authorizedHomework->id)
            ->with(['questions' => fn ($query) => $query
                ->select(['id', 'assessment_id', 'type', 'prompt', 'instructions', 'points', 'position'])
                ->where('institution_id', $student->institution_id)
                ->orderBy('position')
                ->orderBy('id')
                ->with([
                    'choiceOptions:id,question_id,option_text,is_correct,position',
                    'matchingItems:id,question_id,side,item_text',
                    'orderingItems:id,question_id,item_text',
                    'fillBlanks:id,question_id,blank_key,position',
                ])])
            ->first();

        if (! $homework instanceof Assessment) {
            throw new NotFoundHttpException;
        }

        $setting = InstitutionSetting::query()
            ->select(['institution_id', 'student_submission_max_mb'])
            ->where('institution_id', $student->institution_id)
            ->first();

        if ($setting === null || $setting->student_submission_max_mb < 1 || $setting->student_submission_max_mb > 15) {
            throw new LogicException('Student Homework requires valid Institution submission settings.');
        }

        $maxFileSizeBytes = min(15, $setting->student_submission_max_mb) * 1_048_576;
        $homework->setAttribute('student_attempt_summary', ($this->attemptSummary)($student, $homework, $readAt));

        foreach ($homework->getRelation('questions') as $question) {
            $question->setAttribute('student_answer_ui', $this->answerUi->project($question, $maxFileSizeBytes));
        }

        return $homework;
    }
}
