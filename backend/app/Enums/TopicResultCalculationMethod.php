<?php

namespace App\Enums;

/** How a calculated Topic result formed its final score. */
enum TopicResultCalculationMethod: string
{
    case Average = 'average';
    case Blitz = 'blitz';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
