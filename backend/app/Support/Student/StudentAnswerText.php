<?php

namespace App\Support\Student;

use App\Domain\Text\UnicodeWhitespace;

final class StudentAnswerText
{
    public static function isEmpty(string $text): bool
    {
        // This is the BE-005 semantic whitespace set, not storage normalization.
        return UnicodeWhitespace::isBlank($text);
    }
}
