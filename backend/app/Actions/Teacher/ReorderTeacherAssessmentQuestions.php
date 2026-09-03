<?php

namespace App\Actions\Teacher;

use App\Models\Assessment;
use App\Models\User;
use App\Support\Assessment\QuestionPositionWriter;
use App\Support\Teacher\TeacherHomeworkAccess;
use App\Support\Teacher\TeacherQuestionMutationAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class ReorderTeacherAssessmentQuestions
{
    public function __construct(
        private readonly TeacherHomeworkAccess $homeworkAccess,
        private readonly TeacherQuestionMutationAccess $mutationAccess,
        private readonly QuestionPositionWriter $positionWriter,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    /** @param list<string> $questionIds */
    public function __invoke(User $teacher, string $assessmentId, array $questionIds): Assessment
    {
        $preliminaryAssessment = $this->homeworkAccess->resolveHomework($teacher, $assessmentId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $questionIds): Assessment {
            $context = $this->mutationAccess->lock($teacher, $preliminaryAssessment);
            $assessment = $context['assessment'];
            $questions = $context['questions'];
            $this->positionWriter->assertContiguous($questions);
            $currentIds = $questions->pluck('id')->map(strtolower(...))->all();
            $sortedCurrentIds = $currentIds;
            $sortedQuestionIds = $questionIds;
            sort($sortedCurrentIds, SORT_STRING);
            sort($sortedQuestionIds, SORT_STRING);

            if ($sortedCurrentIds !== $sortedQuestionIds) {
                throw ValidationException::withMessages([
                    'question_ids' => ['The complete current Question set is required.'],
                ]);
            }

            if ($this->positionWriter->reorder($assessment, $questions, $questionIds)) {
                $assessment->touch();
            }

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }
}
