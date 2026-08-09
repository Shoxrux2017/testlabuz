<?php

namespace App\Enums;

enum InstitutionType: string
{
    case School = 'school';
    case College = 'college';
    case Lyceum = 'lyceum';
    case University = 'university';
    case Institute = 'institute';
    case LearningCenter = 'learning_center';
    case TrainingCenter = 'training_center';
    case PrivateEducation = 'private_education';
    case Other = 'other';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
