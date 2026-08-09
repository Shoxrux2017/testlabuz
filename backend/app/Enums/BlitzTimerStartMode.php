<?php

namespace App\Enums;

enum BlitzTimerStartMode: string
{
    case Synchronized = 'synchronized';
    case Individual = 'individual';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
