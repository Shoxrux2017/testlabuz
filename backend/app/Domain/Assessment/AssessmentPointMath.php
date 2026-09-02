<?php

namespace App\Domain\Assessment;

use InvalidArgumentException;

final class AssessmentPointMath
{
    private const SCALE = 6;

    private const MAX_POINT_MICRO_UNITS = 999_999_999_999;

    /** @param list<int|float|string> $points */
    public function sum(array $points): string
    {
        $total = 0;

        foreach ($points as $point) {
            $microUnits = self::toMicroUnits($point);

            if ($total > PHP_INT_MAX - $microUnits) {
                throw new InvalidArgumentException('Assessment point total exceeds the supported range.');
            }

            $total += $microUnits;
        }

        return self::formatMicroUnits($total);
    }

    public static function normalize(int|float|string $points): string
    {
        return self::formatMicroUnits(self::toMicroUnits($points));
    }

    private static function toMicroUnits(int|float|string $points): int
    {
        if (is_float($points)) {
            if (! is_finite($points)) {
                throw new InvalidArgumentException('Question points must be finite.');
            }

            $encoded = json_encode($points, JSON_PRESERVE_ZERO_FRACTION);

            if (! is_string($encoded)) {
                throw new InvalidArgumentException('Question points are invalid.');
            }

            $value = $encoded;
        } else {
            $value = (string) $points;
        }

        if (preg_match('/\A(?<whole>0|[1-9]\d*)(?:\.(?<fraction>\d+))?(?:[eE](?<exponent>[+-]?\d+))?\z/D', $value, $matches) !== 1) {
            throw new InvalidArgumentException('Question points are invalid.');
        }

        $fraction = $matches['fraction'] ?? '';
        $exponent = isset($matches['exponent']) && $matches['exponent'] !== ''
            ? (int) $matches['exponent']
            : 0;
        $digits = ltrim($matches['whole'].$fraction, '0');
        $digits = $digits === '' ? '0' : $digits;
        $microExponent = self::SCALE - (strlen($fraction) - $exponent);

        if ($microExponent < 0) {
            $discardedDigits = -$microExponent;

            if (strlen($digits) <= $discardedDigits
                || trim(substr($digits, -$discardedDigits), '0') !== '') {
                throw new InvalidArgumentException('Question points may have at most six fractional digits.');
            }

            $digits = substr($digits, 0, -$discardedDigits);
        } elseif ($microExponent > 0) {
            if ($microExponent > 18) {
                throw new InvalidArgumentException('Question points exceed the supported range.');
            }

            $digits .= str_repeat('0', $microExponent);
        }

        $digits = ltrim($digits, '0');
        $digits = $digits === '' ? '0' : $digits;

        if (strlen($digits) > strlen((string) self::MAX_POINT_MICRO_UNITS)
            || (strlen($digits) === strlen((string) self::MAX_POINT_MICRO_UNITS)
                && strcmp($digits, (string) self::MAX_POINT_MICRO_UNITS) > 0)) {
            throw new InvalidArgumentException('Question points exceed the supported range.');
        }

        return (int) $digits;
    }

    private static function formatMicroUnits(int $microUnits): string
    {
        $whole = intdiv($microUnits, 1_000_000);
        $fraction = $microUnits % 1_000_000;

        return $whole.'.'.str_pad((string) $fraction, self::SCALE, '0', STR_PAD_LEFT);
    }
}
