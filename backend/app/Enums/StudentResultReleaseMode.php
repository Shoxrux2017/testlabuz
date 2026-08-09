<?php

namespace App\Enums;

enum StudentResultReleaseMode: string
{
    case Automatic = 'automatic';
    case ManualTeacher = 'manual_teacher';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
