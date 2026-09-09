<?php

namespace App\Support\Student;

final class StudentAnswerText
{
    public static function isEmpty(string $text): bool
    {
        // This is the BE-005 semantic whitespace set, not storage normalization.
        return preg_match('/\A[\x{0009}-\x{000D}\x{0020}\x{0085}\x{00A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]*\z/u', $text) === 1;
    }
}
