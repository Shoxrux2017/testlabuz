<?php

namespace App\Domain\Results;

use App\Enums\UnderstandingCategoryCode;
use LogicException;

/** One numeric understanding category and its inclusive integer range. */
final class CategoryBand
{
    public function __construct(
        public readonly UnderstandingCategoryCode $code,
        public readonly int $minScore,
        public readonly int $maxScore,
    ) {
        if (! $code->isNumeric() || $minScore < 0 || $maxScore > 100 || $minScore > $maxScore) {
            throw new LogicException('A category band is a numeric category with an inclusive range inside 0–100.');
        }
    }

    public function contains(int $categoryScore): bool
    {
        return $categoryScore >= $this->minScore && $categoryScore <= $this->maxScore;
    }
}
