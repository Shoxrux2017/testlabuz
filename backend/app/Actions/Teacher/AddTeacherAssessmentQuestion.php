<?php

namespace App\Actions\Teacher;

use App\Domain\Assessment\AssessmentPointMath;
use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Models\Assessment;
use App\Models\User;
use App\Support\Assessment\QuestionConfigurationWriter;
use App\Support\Assessment\QuestionPositionWriter;
use App\Support\Teacher\TeacherHomeworkAccess;
use App\Support\Teacher\TeacherQuestionMutationAccess;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class AddTeacherAssessmentQuestion
{
    public function __construct(
        private readonly TeacherHomeworkAccess $homeworkAccess,
        private readonly TeacherQuestionMutationAccess $mutationAccess,
        private readonly QuestionPositionWriter $positionWriter,
        private readonly QuestionConfigurationWriter $configurationWriter,
        private readonly AssessmentPointMath $pointMath,
        private readonly ShowTeacherHomework $showTeacherHomework,
    ) {}

    /** @param array<string, mixed> $attributes */
    public function __invoke(User $teacher, string $assessmentId, array $attributes): Assessment
    {
        $preliminaryAssessment = $this->homeworkAccess->resolveHomework($teacher, $assessmentId);

        return DB::transaction(function () use ($teacher, $preliminaryAssessment, $attributes): Assessment {
            $context = $this->mutationAccess->lock($teacher, $preliminaryAssessment);
            $assessment = $context['assessment'];
            $homework = $context['homework'];
            $questions = $context['questions'];
            $questionCount = $questions->count();
            $position = $attributes['position'];

            if ($questionCount >= QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT) {
                throw ValidationException::withMessages([
                    'questions' => ['The maximum Question count has been reached.'],
                ]);
            }

            if (! is_int($position) || $position < 1 || $position > $questionCount + 1) {
                throw ValidationException::withMessages([
                    'position' => ['The Question position must be between 1 and the append position.'],
                ]);
            }

            $appendPosition = $this->positionWriter->appendPosition($questions);
            $question = $this->configurationWriter->create($assessment, [
                ...$attributes,
                'position' => $appendPosition,
            ]);
            $orderedQuestionIds = $questions->pluck('id')->all();
            array_splice($orderedQuestionIds, $position - 1, 0, [$question->id]);
            $questions->push($question);
            $this->positionWriter->reorder($assessment, $questions, $orderedQuestionIds);

            $totalPossiblePoints = $this->pointMath->sum($questions->pluck('points')->all());
            $this->mutationAccess->ensureActiveResultIsScoreable(
                $homework,
                $questions->count(),
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
