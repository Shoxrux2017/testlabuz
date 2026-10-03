<?php

namespace App\Domain\Results;

use App\Enums\TopicResultCalculationMethod;
use App\Enums\TopicResultConsistency;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultSideState as State;
use App\Enums\TopicResultStatus;
use App\Enums\UnderstandingCategoryCode;
use LogicException;

/**
 * The open Topic result from its two sides and the Institution's current threshold and category set
 * (docs/09 §25.3 Result Status and Calculation).
 */
final class TopicResultCalculator
{
    private const WAITING_FOR_HOMEWORK = [State::NotActivated, State::Open, State::Checking];

    private const WAITING_FOR_BLITZ = [State::NotDesignated, State::NotActivated, State::Open, State::Checking];

    public function __construct(private readonly TopicResultMath $math) {}

    /**
     * @param  ?string  $threshold  The acceptable difference T, or null while unconfigured
     * @param  ?list<CategoryBand>  $bands  The four numeric bands of a valid category set, or null
     */
    public function calculate(TopicResultSide $homework, TopicResultSide $blitz, ?string $threshold, ?array $bands): TopicResultComputation
    {
        $missing = $this->missingComponent($homework, $blitz);

        if ($missing !== null) {
            return new TopicResultComputation(
                status: TopicResultStatus::NotCompleted,
                missingComponent: $missing,
                category: UnderstandingCategoryCode::NotCompleted,
            );
        }

        if ($homework->state === State::Ready && $blitz->state === State::Ready) {
            return $threshold === null || $bands === null
                ? new TopicResultComputation(TopicResultStatus::WaitingForSettings)
                : $this->calculated($homework->score, $blitz->score, $threshold, $bands);
        }

        return new TopicResultComputation(match (true) {
            in_array($homework->state, self::WAITING_FOR_HOMEWORK, true) => TopicResultStatus::WaitingForHomework,
            in_array($blitz->state, self::WAITING_FOR_BLITZ, true) => TopicResultStatus::WaitingForBlitz,
            default => TopicResultStatus::WaitingForTeacherReview,
        });
    }

    private function missingComponent(TopicResultSide $homework, TopicResultSide $blitz): ?TopicResultMissingComponent
    {
        return match (true) {
            $homework->state === State::Missing && $blitz->state === State::Missing => TopicResultMissingComponent::Both,
            $homework->state === State::Missing => TopicResultMissingComponent::Homework,
            $blitz->state === State::Missing => TopicResultMissingComponent::Blitz,
            default => null,
        };
    }

    /** @param list<CategoryBand> $bands */
    private function calculated(string $homeworkScore, string $blitzScore, string $threshold, array $bands): TopicResultComputation
    {
        $difference = $this->math->difference($homeworkScore, $blitzScore);
        $consistent = ! $this->math->exceeds($difference, $threshold);
        $exactFinal = $consistent ? $this->math->exactAverage($homeworkScore, $blitzScore) : $blitzScore;
        $categoryScore = $this->math->categoryScore($exactFinal);
        $band = $this->band($bands, $categoryScore);

        return new TopicResultComputation(
            status: TopicResultStatus::Calculated,
            difference: $difference,
            threshold: $this->math->storedScore($threshold),
            method: $consistent ? TopicResultCalculationMethod::Average : TopicResultCalculationMethod::Blitz,
            consistency: $consistent ? TopicResultConsistency::Consistent : TopicResultConsistency::Inconsistent,
            finalScore: $this->math->storedScore($exactFinal),
            categoryScore: $categoryScore,
            category: $band->code,
            categoryMinScore: $band->minScore,
            categoryMaxScore: $band->maxScore,
        );
    }

    /** @param list<CategoryBand> $bands */
    private function band(array $bands, int $categoryScore): CategoryBand
    {
        foreach ($bands as $band) {
            if ($band->contains($categoryScore)) {
                return $band;
            }
        }

        throw new LogicException('A valid category set covers every integer from 0 to 100.');
    }
}
