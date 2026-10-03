<?php

namespace App\Enums;

/** The terminal outcome a closed Topic result keeps. */
enum TopicResultOutcome: string
{
    case Calculated = 'calculated';
    case NotCompleted = 'not_completed';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
