<?php

namespace App\Domain\Institution;

use App\Enums\UnderstandingCategoryCode;
use InvalidArgumentException;

class UnderstandingCategorySetValidator
{
    /**
     * @param  array<array-key, mixed>  $entries
     * @return list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>
     */
    public function validate(array $entries): array
    {
        if (count($entries) !== count(UnderstandingCategoryCode::cases())) {
            throw $this->invalidSet();
        }

        $entriesByCode = [];
        $seenOrders = [];

        foreach ($entries as $entry) {
            if (! is_array($entry) || array_keys($entry) !== ['code', 'min_score', 'max_score', 'sort_order']) {
                throw $this->invalidSet();
            }

            $codeValue = $entry['code'];
            $sortOrder = $entry['sort_order'];

            if (! is_string($codeValue) || ! is_int($sortOrder)) {
                throw $this->invalidSet();
            }

            $code = UnderstandingCategoryCode::tryFrom($codeValue);

            if ($code === null
                || isset($entriesByCode[$code->value])
                || isset($seenOrders[$sortOrder])
                || $sortOrder !== $code->sortOrder()) {
                throw $this->invalidSet();
            }

            $minScore = $entry['min_score'];
            $maxScore = $entry['max_score'];

            if ($code->isNumeric()) {
                if (! is_int($minScore)
                    || ! is_int($maxScore)
                    || $minScore < 0
                    || $maxScore > 100
                    || $minScore > $maxScore) {
                    throw $this->invalidSet();
                }
            } elseif ($minScore !== null || $maxScore !== null) {
                throw $this->invalidSet();
            }

            $entriesByCode[$code->value] = [
                'code' => $code->value,
                'min_score' => $minScore,
                'max_score' => $maxScore,
                'sort_order' => $sortOrder,
            ];
            $seenOrders[$sortOrder] = true;
        }

        $canonical = [];

        foreach (UnderstandingCategoryCode::cases() as $code) {
            if (! isset($entriesByCode[$code->value])) {
                throw $this->invalidSet();
            }

            $canonical[] = $entriesByCode[$code->value];
        }

        if ($canonical[0]['max_score'] !== 100 || $canonical[3]['min_score'] !== 0) {
            throw $this->invalidSet();
        }

        for ($index = 0; $index < 3; $index++) {
            $higherMinimum = $canonical[$index]['min_score'];
            $lowerMaximum = $canonical[$index + 1]['max_score'];

            if (! is_int($higherMinimum)
                || ! is_int($lowerMaximum)
                || $higherMinimum !== $lowerMaximum + 1) {
                throw $this->invalidSet();
            }
        }

        return $canonical;
    }

    private function invalidSet(): InvalidArgumentException
    {
        return new InvalidArgumentException('Invalid understanding category configuration.');
    }
}
