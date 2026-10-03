<?php

namespace App\Domain\Results;

use App\Enums\TopicResultCalculationMethod;
use App\Enums\TopicResultConsistency;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultStatus;
use App\Enums\UnderstandingCategoryCode;

/**
 * The computed open Topic result. The comparison values, the final score and the category score
 * exist only for `calculated`; the category is the numeric band for `calculated` and Not completed
 * for `not_completed`.
 */
final class TopicResultComputation
{
    public function __construct(
        public readonly TopicResultStatus $status,
        public readonly ?TopicResultMissingComponent $missingComponent = null,
        public readonly ?string $difference = null,
        public readonly ?string $threshold = null,
        public readonly ?TopicResultCalculationMethod $method = null,
        public readonly ?TopicResultConsistency $consistency = null,
        public readonly ?string $finalScore = null,
        public readonly ?int $categoryScore = null,
        public readonly ?UnderstandingCategoryCode $category = null,
        public readonly ?int $categoryMinScore = null,
        public readonly ?int $categoryMaxScore = null,
    ) {}

    public function terminal(): bool
    {
        return $this->status === TopicResultStatus::Calculated || $this->status === TopicResultStatus::NotCompleted;
    }
}
