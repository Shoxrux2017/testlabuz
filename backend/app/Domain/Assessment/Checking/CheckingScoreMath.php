<?php

namespace App\Domain\Assessment\Checking;

use Brick\Math\BigDecimal;
use Brick\Math\Exception\RoundingNecessaryException;
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

        try {
            return (string) $total->toScale(self::SCALE);
        } catch (RoundingNecessaryException) {
            throw new LogicException('Awarded points may have at most eight decimal places.');
        }
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

    public function isZero(string $points): bool
    {
        return self::decimal($points)->isZero();
    }

    private static function decimal(string $value): BigDecimal
    {
        if (preg_match('/\A\d+(?:\.\d+)?\z/D', $value) !== 1) {
            throw new LogicException('A score value must be a plain non-negative decimal string.');
        }

        return BigDecimal::of($value);
    }
}
