<?php

namespace App\Domain\Assessment\Checking;

use LogicException;
use Normalizer;

/**
 * BR-Q-013A: the normalization applied to both a Student answer and every accepted
 * answer before an exact comparison. Punctuation and other symbols stay significant.
 */
final class AnswerTextNormalizer
{
    private const APOSTROPHE_VARIANTS = [
        "\u{0060}" => "'",
        "\u{00B4}" => "'",
        "\u{02BB}" => "'",
        "\u{02BC}" => "'",
        "\u{2018}" => "'",
        "\u{2019}" => "'",
    ];

    // The Student-answer whitespace set, also used by StudentAnswerText.
    private const WHITESPACE_RUN = '/[\x{0009}-\x{000D}\x{0020}\x{0085}\x{00A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]+/u';

    public function normalize(string $text): string
    {
        $folded = mb_convert_case(self::nfc($text), MB_CASE_FOLD, 'UTF-8');
        $apostrophes = strtr(self::nfc($folded), self::APOSTROPHE_VARIANTS);
        $collapsed = preg_replace(self::WHITESPACE_RUN, ' ', $apostrophes);

        if (! is_string($collapsed)) {
            throw new LogicException('Answer text could not be normalized.');
        }

        return trim($collapsed, ' ');
    }

    private static function nfc(string $text): string
    {
        $normalized = Normalizer::normalize($text, Normalizer::FORM_C);

        if (! is_string($normalized)) {
            throw new LogicException('Answer text is not valid UTF-8.');
        }

        return $normalized;
    }
}
