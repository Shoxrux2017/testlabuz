<?php

namespace App\Domain\Assessment\Checking;

use App\Domain\Text\UnicodeWhitespace;
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

    private const WHITESPACE_RUN = '/'.UnicodeWhitespace::CHARACTER_CLASS.'+/u';

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
