<?php

namespace App\Enums;

enum ParentResultReleaseMode: string
{
    case WithStudent = 'with_student';
    case ManualTeacher = 'manual_teacher';
    case Hidden = 'hidden';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
