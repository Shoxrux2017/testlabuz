<?php

namespace App\Enums;

enum QuestionCheckingMode: string
{
    case Automatic = 'automatic';
    case Manual = 'manual';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
