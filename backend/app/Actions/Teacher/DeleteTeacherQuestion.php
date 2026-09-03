<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Models\Assessment;
use App\Models\Question;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use App\Support\Assessment\QuestionPositionWriter;
use App\Support\Teacher\TeacherHomeworkAccess;
use App\Support\Teacher\TeacherQuestionMutationAccess;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

final class DeleteTeacherQuestion
{
    public function __construct(
        private readonly TeacherHomeworkAccess $homeworkAccess,
        private readonly TeacherQuestionMutationAccess $mutationAccess,
        private readonly QuestionPositionWriter $positionWriter,
        private readonly QuestionConfigurationWriter $configurationWriter,
        private readonly AssessmentPointMath $pointMath,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    public function __invoke(User $teacher, string $questionId): Assessment
    {
        $preliminaryAssessment = $this->homeworkAccess->resolveHomeworkForQuestion($teacher, $questionId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $questionId): Assessment {
            $context = $this->mutationAccess->lock($teacher, $preliminaryAssessment);
            $assessment = $context['assessment'];
            $homework = $context['homework'];
            $questions = $context['questions'];
            $this->positionWriter->assertContiguous($questions);
            $question = $questions->firstWhere('id', strtolower($questionId));

            if (! $question instanceof Question) {
                throw new NotFoundHttpException;
            }

            $this->configurationWriter->lockAndLoadConfiguration($question);
            $this->configurationWriter->deleteConfiguration($question);
            $question->delete();
            $remainingQuestions = $questions
                ->reject(fn (Question $candidate): bool => $candidate->is($question))
                ->values();
            $this->positionWriter->compact($assessment, $remainingQuestions);
            $totalPossiblePoints = $this->pointMath->sum($remainingQuestions->pluck('points')->all());
            $this->mutationAccess->ensureActiveResultIsScoreable(
                $homework,
                $remainingQuestions->count(),
                $totalPossiblePoints,
            );
            $this->persistTotalAndTouch($assessment, $totalPossiblePoints);

            return ($this->showTeacherHomework)($teacher, $assessment->id);
        });
    }

    private function persistTotalAndTouch(Assessment $assessment, string $totalPossiblePoints): void
    {
        $assessment->total_possible_points = $totalPossiblePoints;

        if ($assessment->isDirty()) {
            $assessment->save();

            return;
        }

        $assessment->touch();
    }
}
