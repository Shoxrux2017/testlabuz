<?php

namespace App\Domain\Results;

use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use LogicException;

/**
 * Exact decimal arithmetic for the Topic result (S10-T5). Inputs are stored official scores and
 * thresholds on the 0–100 scale with at most eight decimals; no binary floating point is used.
 */
final class TopicResultMath
{
    private const SCALE = 8;

    /** |H − B|, exact. */
    public function difference(string $homeworkScore, string $blitzScore): string
    {
        return (string) self::score($homeworkScore)->minus(self::score($blitzScore))->abs()->toScale(self::SCALE);
    }

    /** Whether the difference is strictly greater than the acceptable difference. */
    public function exceeds(string $difference, string $threshold): bool
    {
        return self::score($difference)->isGreaterThan(self::score($threshold));
    }

    /** (H + B) / 2 without rounding; it needs at most nine decimals. */
    public function exactAverage(string $homeworkScore, string $blitzScore): string
    {
        return (string) self::score($homeworkScore)->plus(self::score($blitzScore))->dividedByExact(2)->strippedOfTrailingZeros();
    }

    /** The stored and serialized form of a score: half-up to eight decimals. */
    public function storedScore(string $exactScore): string
    {
        return (string) self::exact($exactScore)->toScale(self::SCALE, RoundingMode::HalfUp);
    }

    /** The integer category score: a fractional part up to .5 rounds down, above .5 rounds up. */
    public function categoryScore(string $exactFinalScore): int
    {
        return self::exact($exactFinalScore)->toScale(0, RoundingMode::HalfDown)->toInt();
    }

    private static function score(string $value): BigDecimal
    {
        if (preg_match('/\A\d+(?:\.\d{1,8})?\z/D', $value) !== 1) {
            throw new LogicException('A Topic result score must be a non-negative decimal with at most eight fractional digits.');
        }

        return self::onScale(BigDecimal::of($value));
    }

    private static function exact(string $value): BigDecimal
    {
        if (preg_match('/\A\d+(?:\.\d{1,9})?\z/D', $value) !== 1) {
            throw new LogicException('An exact Topic result score must be a non-negative decimal with at most nine fractional digits.');
        }

        return self::onScale(BigDecimal::of($value));
    }

    private static function onScale(BigDecimal $value): BigDecimal
    {
        if ($value->isGreaterThan(100)) {
            throw new LogicException('A Topic result score lies on the 0–100 scale.');
        }

        return $value;
    }
}
