<?php

namespace App\Enums;

enum AssessmentAssignmentSource: string
{
    case Group = 'group';
    case Direct = 'direct';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
