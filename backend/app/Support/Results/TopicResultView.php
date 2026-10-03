<?php

namespace App\Support\Results;

use App\Enums\TopicResultCalculationMethod;
use App\Enums\TopicResultConsistency;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultOutcome;
use App\Enums\TopicResultStatus;
use App\Enums\UnderstandingCategoryCode;
use App\Models\TopicResult;
use App\Models\User;

/**
 * One cohort Student's Topic result as read now: computed live while open, from the snapshot once
 * closed (docs/09 §25.3), with the Student's stored row (comment, releases, closure) when one exists.
 */
final readonly class TopicResultView
{
    public function __construct(
        public User $student,
        public TopicResultStatus $status,
        public ?TopicResultOutcome $closedOutcome,
        public ?TopicResultMissingComponent $missingComponent,
        public TopicResultSideView $homework,
        public TopicResultSideView $blitz,
        public ?string $difference,
        public ?string $threshold,
        public ?TopicResultCalculationMethod $method,
        public ?TopicResultConsistency $consistency,
        public ?string $finalScore,
        public ?int $categoryScore,
        public ?UnderstandingCategoryCode $category,
        public ?int $categoryMinScore,
        public ?int $categoryMaxScore,
        public bool $terminal,
        public bool $workFinished,
        public bool $closable,
        public ?TopicResult $row,
    ) {}
}
