<?php

namespace App\Actions\Student;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use App\Models\InstitutionSetting;
use App\Models\User;
use App\Support\Student\StudentBlitzTiming;
use App\Support\Student\StudentHomeworkAttemptAnswerStates;
use App\Support\Student\StudentQuestionAnswerUi;
use Carbon\CarbonInterface;
use LogicException;

final class ShowStudentBlitzAttempt
{
    public function __construct(
        private readonly StudentQuestionAnswerUi $answerUi,
        private readonly StudentBlitzTiming $timing,
        private readonly StudentHomeworkAttemptAnswerStates $answerStates,
    ) {}

    public function __invoke(User $student, Assessment $assessment, BlitzTask $blitz, AssessmentAttempt $attempt, CarbonInterface $serverNow): AssessmentAttempt
    {
        $assessment->load(['questions' => fn ($query) => $query
            ->select(['id', 'assessment_id', 'type', 'prompt', 'instructions', 'points', 'position'])
            ->where('institution_id', $student->institution_id)->orderBy('position')->orderBy('id')
            ->with([
                'choiceOptions:id,question_id,option_text,is_correct,position',
                'matchingItems:id,question_id,side,item_text',
                'orderingItems:id,question_id,item_text',
                'fillBlanks:id,question_id,blank_key,position',
            ])]);
        $setting = InstitutionSetting::query()->select(['institution_id', 'student_submission_max_mb'])
            ->where('institution_id', $student->institution_id)->first();

        if ($setting === null || $setting->student_submission_max_mb < 1 || $setting->student_submission_max_mb > 15) {
            throw new LogicException('Student Blitz requires valid Institution submission settings.');
        }

        $maxFileSizeBytes = min(15, $setting->student_submission_max_mb) * 1_048_576;

        foreach ($assessment->getRelation('questions') as $question) {
            $question->setAttribute('student_answer_ui', $this->answerUi->project($question, $maxFileSizeBytes));
        }

        $assessment->setRelation('blitzTask', $blitz);
        $attempt->setRelation('assessment', $assessment);
        $attempt->setAttribute('student_blitz_timing', $this->timing->project($blitz, $attempt, $serverNow));
        $attempt->setAttribute('student_answer_states', ($this->answerStates)(
            $student->institution_id, $attempt, $assessment->getRelation('questions'),
        ));

        return $attempt;
    }
}
