<?php

namespace App\Enums;

enum AssessmentAssignmentMode: string
{
    case Group = 'group';
    case SelectedStudents = 'selected_students';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
