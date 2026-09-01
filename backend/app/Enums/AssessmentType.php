<?php

namespace App\Enums;

enum AssessmentType: string
{
    case Homework = 'homework';
    case Blitz = 'blitz';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
