<?php

namespace App\Domain\Assessment\Checking;

use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use LogicException;

/**
 * Exact decimal arithmetic for checking and scoring. No binary floating point is
 * used; every result is a decimal string with exactly eight fractional digits.
 */
final class CheckingScoreMath
{
    private const SCALE = 8;

    /** points × correct / total in one step, rounded half-up to eight decimal places. */
    public function partialPoints(string $points, int $correct, int $total): string
    {
        if ($total < 1 || $correct < 0 || $correct > $total) {
            throw new LogicException('Partial credit needs a positive total and 0 <= correct <= total.');
        }

        return (string) self::decimal($points)
            ->multipliedBy($correct)
            ->dividedBy($total, self::SCALE, RoundingMode::HalfUp);
    }

    /** @param list<string> $awardedPoints */
    public function sum(array $awardedPoints): string
    {
        $total = BigDecimal::zero();

        foreach ($awardedPoints as $points) {
            $total = $total->plus(self::decimal($points));
        }

        return (string) $total->toScale(self::SCALE);
    }

    /** earned × 100 / possible, rounded half-up to eight decimal places. */
    public function normalizedScore(string $earnedPoints, string $possiblePoints): string
    {
        $earned = self::decimal($earnedPoints);
        $possible = self::decimal($possiblePoints);

        if ($possible->isZero() || $earned->isGreaterThan($possible)) {
            throw new LogicException('A normalized score needs positive possible points and earned <= possible.');
        }

        return (string) $earned
            ->multipliedBy(100)
            ->dividedBy($possible, self::SCALE, RoundingMode::HalfUp);
    }

    /** -1, 0 or 1 as the left value is less than, equal to or greater than the right value. */
    public function compare(string $left, string $right): int
    {
        return self::decimal($left)->compareTo(self::decimal($right));
    }

    public function isZero(string $points): bool
    {
        return self::decimal($points)->isZero();
    }

    private static function decimal(string $value): BigDecimal
    {
        if (preg_match('/\A\d+(?:\.\d{1,8})?\z/D', $value) !== 1) {
            throw new LogicException('A score value must be a non-negative decimal with at most eight fractional digits.');
        }

        return BigDecimal::of($value);
    }
}
