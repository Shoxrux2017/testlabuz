<?php

namespace App\Enums;

enum BlitzAttemptExceptionReasonType: string
{
    case Technical = 'technical';
    case OtherValid = 'other_valid';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
