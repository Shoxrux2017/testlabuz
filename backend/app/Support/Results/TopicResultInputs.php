<?php

namespace App\Support\Results;

use App\Domain\Results\CategoryBand;
use App\Models\Assessment;
use Carbon\CarbonImmutable;

/** What every cohort Student's Topic result of one read shares: the official tasks, the current settings and the read time. */
final readonly class TopicResultInputs
{
    /** @param ?list<CategoryBand> $bands The four numeric bands of a valid category set, or null */
    public function __construct(
        public Assessment $homework,
        public ?Assessment $blitz,
        public ?string $threshold,
        public ?array $bands,
        public CarbonImmutable $now,
    ) {}
}
