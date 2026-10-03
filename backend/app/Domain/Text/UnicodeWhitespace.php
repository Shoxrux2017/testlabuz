<?php

namespace App\Domain\Text;

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

    /** An empty string for a blank value, so a request rejects it exactly like an ASCII-blank one. */
    public static function blankAsEmpty(string $text): string
    {
        return self::isBlank($text) ? '' : $text;
    }
}
