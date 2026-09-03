<?php

namespace App\Support\Assessment;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Domain\Assessment\QuestionPositionSetValidator;
use App\Models\Assessment;
use App\Models\Question;
use Illuminate\Database\Eloquent\Collection;
use InvalidArgumentException;
use LogicException;

final class QuestionPositionWriter
{
    private const POSTGRES_INTEGER_MAX = 2_147_483_647;

    public function __construct(
        private readonly QuestionPositionSetValidator $positionSetValidator,
    ) {}

    /** @param Collection<int, Question> $questions */
    public function appendPosition(Collection $questions): int
    {
        $this->assertContiguous($questions);

        if ($questions->count() >= QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT) {
            throw new LogicException('The Question set is already at its supported maximum.');
        }

        return $questions->count() + 1;
    }

    /** @param Collection<int, Question> $questions */
    public function assertContiguous(Collection $questions): void
    {
        try {
            $this->positionSetValidator->validate(
                $questions->pluck('position')->all(),
                QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT,
                allowEmpty: true,
            );
        } catch (InvalidArgumentException $exception) {
            throw new LogicException('Persisted Question positions are invalid.', previous: $exception);
        }
    }

    /**
     * @param  Collection<int, Question>  $questions
     * @param  list<string>  $orderedQuestionIds
     */
    public function reorder(Assessment $assessment, Collection $questions, array $orderedQuestionIds): bool
    {
        $currentIds = $questions->pluck('id')->all();
        $desiredIds = $orderedQuestionIds;
        $sortedCurrentIds = $currentIds;
        $sortedDesiredIds = $desiredIds;
        sort($sortedCurrentIds, SORT_STRING);
        sort($sortedDesiredIds, SORT_STRING);

        if ($sortedCurrentIds !== $sortedDesiredIds
            || count($desiredIds) > QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT) {
            throw new LogicException('The complete Question position set is required.');
        }

        $desiredPositions = [];

        foreach ($desiredIds as $index => $questionId) {
            $desiredPositions[$questionId] = $index + 1;
        }

        if ($this->positionsMatch($questions, $desiredPositions)) {
            return false;
        }

        $maximumCurrentPosition = (int) ($questions->max('position') ?? 0);
        $temporaryStart = max($maximumCurrentPosition, count($desiredPositions)) + 1;

        if ($temporaryStart + count($desiredPositions) - 1 > self::POSTGRES_INTEGER_MAX) {
            throw new LogicException('No safe temporary Question position range is available.');
        }

        foreach ($questions->sortBy(
            fn (Question $question): string => str_pad((string) $question->position, 10, '0', STR_PAD_LEFT).':'.$question->id,
        )->values() as $index => $question) {
            $this->writePosition($assessment, $question, $temporaryStart + $index);
        }

        foreach ($desiredIds as $questionId) {
            $question = $questions->firstWhere('id', $questionId);

            if (! $question instanceof Question) {
                throw new LogicException('The locked Question set changed unexpectedly.');
            }

            $this->writePosition($assessment, $question, $desiredPositions[$questionId]);
        }

        return true;
    }

    /** @param Collection<int, Question> $questions */
    public function compact(Assessment $assessment, Collection $questions): void
    {
        $orderedIds = $questions
            ->sortBy(
                fn (Question $question): string => str_pad((string) $question->position, 10, '0', STR_PAD_LEFT).':'.$question->id,
            )
            ->pluck('id')
            ->values()
            ->all();

        $this->reorder($assessment, $questions, $orderedIds);
    }

    /**
     * @param  Collection<int, Question>  $questions
     * @param  array<string, int>  $desiredPositions
     */
    private function positionsMatch(Collection $questions, array $desiredPositions): bool
    {
        foreach ($questions as $question) {
            if (($desiredPositions[$question->id] ?? null) !== $question->position) {
                return false;
            }
        }

        return true;
    }

    private function writePosition(Assessment $assessment, Question $question, int $position): void
    {
        $updated = Question::query()
            ->where('institution_id', $assessment->institution_id)
            ->where('assessment_id', $assessment->id)
            ->whereKey($question->id)
            ->update(['position' => $position]);

        if ($updated !== 1) {
            throw new LogicException('A locked Question could not be repositioned.');
        }

        $question->position = $position;
    }
}
