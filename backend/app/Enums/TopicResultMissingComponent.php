<?php

namespace App\Enums;

/** Which required work a Not completed Topic result misses. */
enum TopicResultMissingComponent: string
{
    case Homework = 'homework';
    case Blitz = 'blitz';
    case Both = 'both';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
