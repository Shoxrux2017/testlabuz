<?php

namespace App\Domain\Assessment;

use InvalidArgumentException;

final class QuestionPositionSetValidator
{
    /** @param array<array-key, mixed> $positions */
    public function validate(array $positions, int $maximumCount, bool $allowEmpty = false): void
    {
        if ($maximumCount < 0
            || count($positions) > $maximumCount
            || (! $allowEmpty && $positions === [])) {
            throw $this->invalidPositions();
        }

        foreach ($positions as $position) {
            if (! is_int($position) || $position < 1) {
                throw $this->invalidPositions();
            }
        }

        if ($positions === []) {
            return;
        }

        $sortedPositions = $positions;
        sort($sortedPositions);

        if ($sortedPositions !== range(1, count($sortedPositions))) {
            throw $this->invalidPositions();
        }
    }

    private function invalidPositions(): InvalidArgumentException
    {
        return new InvalidArgumentException('Invalid question position set.');
    }
}
