<?php

namespace App\Enums;

enum FileCategory: string
{
    case LearningMaterial = 'learning_material';
    case StudentSubmission = 'student_submission';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
