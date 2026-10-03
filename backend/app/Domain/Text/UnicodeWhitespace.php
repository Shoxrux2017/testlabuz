<?php

namespace App\Domain\Text;

use LogicException;

/**
 * The one whitespace set of the project: the characters Dart's `String.trim()` removes, so the
 * backend calls a value blank exactly when the strict client parsers would.
 */
final class UnicodeWhitespace
{
    public const CHARACTER_CLASS = '[\x{0009}-\x{000D}\x{0020}\x{0085}\x{00A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]';

    public static function isBlank(string $text): bool
    {
        return preg_match('/\A'.self::CHARACTER_CLASS.'*\z/u', $text) === 1;
    }

    /**
     * The value without leading and trailing whitespace of the set, in linear time and without
     * backtracking: the leading run is measured possessively, then the last other character is the one
     * followed only by whitespace up to the end. Each whitespace run is scanned at most once, so neither
     * a long inner run (quadratic for an unanchored `\s+\z`) nor a long trailing run (the backtracking
     * limit for a greedy `.*\S`) is a problem.
     */
    public static function trim(string $text): string
    {
        if (preg_match('/\A'.self::CHARACTER_CLASS.'*+/u', $text, $leading) !== 1) {
            throw new LogicException('Text could not be trimmed.');
        }

        $start = strlen($leading[0]);
        $notWhitespace = '[^'.substr(self::CHARACTER_CLASS, 1);
        $found = preg_match('/'.$notWhitespace.'(?='.self::CHARACTER_CLASS.'*+\z)/u', $text, $last, PREG_OFFSET_CAPTURE, $start);

        if ($found === false) {
            throw new LogicException('Text could not be trimmed.');
        }

        return $found === 0 ? '' : substr($text, $start, $last[0][1] + strlen($last[0][0]) - $start);
    }

    /** An empty string for a blank value, so a request rejects it exactly like an ASCII-blank one. */
    public static function blankAsEmpty(string $text): string
    {
        return self::isBlank($text) ? '' : $text;
    }
}
