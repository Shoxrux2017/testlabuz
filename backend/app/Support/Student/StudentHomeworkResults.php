<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\StudentResultReleaseMode;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\OfficialTaskScore;
use App\Models\User;
use App\Support\Checking\OfficialScoreEvaluator;
use App\Support\Checking\OfficialScoreReader;
use App\Support\Checking\OfficialTaskDesignation;
use Illuminate\Database\Eloquent\Collection;
use LogicException;

/**
 * Stage 9 Student result visibility for Homework (docs/09 §17.1–§17.4). With automatic release a
 * checked eligible Attempt shows its score and its answers' feedback, and the official Homework
 * shows its official score while the stored row is confirmed by a live evaluation. The number of
 * queries does not grow with the number of Homework.
 */
final class StudentHomeworkResults
{
    public function __construct(
        private readonly OfficialTaskDesignation $designation,
        private readonly OfficialScoreEvaluator $evaluator,
        private readonly OfficialScoreReader $reader,
        private readonly StudentResultVisibility $visibility,
    ) {}

    /**
     * Sets `student_official_score` on each Homework and `student_result` on each of its Attempts.
     *
     * @param  iterable<Assessment>  $homework  Rows of StudentHomeworkAccess::readQuery for this Student
     */
    public function apply(User $student, iterable $homework, ?StudentResultReleaseMode $mode): void
    {
        $homework = Collection::make($homework);
        $released = $this->visibility->released($mode);

        foreach ($homework as $assessment) {
            $assessment->setAttribute('student_official_score', null);

            foreach ($this->attempts($assessment) as $attempt) {
                $attempt->setAttribute('student_result', $this->result($attempt, $released));
            }
        }

        if (! $released) {
            return;
        }

        $officialIds = $this->designation->officialIds($student->institution_id, $homework);
        $scores = $officialIds === [] ? Collection::make() : OfficialTaskScore::query()
            ->select(['id', 'institution_id', 'assessment_id', 'student_id', 'official_attempt_id', 'normalized_score'])
            ->where('institution_id', $student->institution_id)
            ->where('student_id', $student->id)
            ->whereIn('assessment_id', $officialIds)
            ->get()
            ->keyBy('assessment_id');
        $scored = $homework->filter(fn (Assessment $assessment): bool => $scores->has($assessment->id));
        $this->loadWaitingAnswers($student, $scored);

        foreach ($scored as $assessment) {
            $score = $scores->get($assessment->id);
            $evaluation = $this->evaluator->evaluate($assessment, $this->recipient($student, $assessment), $this->attempts($assessment));

            if ($this->reader->confirms($score, $evaluation)) {
                $assessment->setAttribute('student_official_score', [
                    'normalized_score' => (float) $score->normalized_score,
                    'attempt_number' => $evaluation->official->attempt_number,
                ]);
            }
        }
    }

    /** @return array{visible: bool, normalized_score: float|null} */
    private function result(AssessmentAttempt $attempt, bool $released): array
    {
        $visible = $this->visibility->visible($attempt, $released);

        return ['visible' => $visible, 'normalized_score' => $visible ? (float) $attempt->normalized_score : null];
    }

    /**
     * Loads, in one pass for all these Homework, the answers (with Question points) that the
     * evaluator needs for the upper bound of each waiting Attempt.
     *
     * @param  Collection<int, Assessment>  $homework
     */
    private function loadWaitingAnswers(User $student, Collection $homework): void
    {
        $waiting = Collection::make($homework->flatMap(fn (Assessment $assessment) => $this->attempts($assessment)
            ->filter(fn (AssessmentAttempt $attempt): bool => $attempt->status === AssessmentAttemptStatus::WaitingForTeacherReview)));

        $waiting->load([
            'answers' => fn ($query) => $query
                ->select(['id', 'institution_id', 'attempt_id', 'question_id', 'checking_status', 'awarded_points'])
                ->where('institution_id', $student->institution_id),
            'answers.question' => fn ($query) => $query
                ->select(['id', 'institution_id', 'points'])
                ->where('institution_id', $student->institution_id),
        ]);
    }

    /** @return Collection<int, AssessmentAttempt> */
    private function attempts(Assessment $assessment): Collection
    {
        if (! $assessment->relationLoaded('attempts')) {
            throw new LogicException('Student Homework results require the loaded Attempt history.');
        }

        return $assessment->getRelation('attempts');
    }

    private function recipient(User $student, Assessment $assessment): AssessmentStudent
    {
        return (new AssessmentStudent)->forceFill([
            'id' => $assessment->getAttribute('student_recipient_id'),
            'institution_id' => $student->institution_id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
        ]);
    }
}
