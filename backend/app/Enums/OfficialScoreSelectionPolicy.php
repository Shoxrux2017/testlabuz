<?php

namespace App\Enums;

enum OfficialScoreSelectionPolicy: string
{
    case HighestValidCompleted = 'highest_valid_completed';
    case ValidNormalBlitz = 'valid_normal_blitz';
    case ApprovedBlitzExceptionReplacement = 'approved_blitz_exception_replacement';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
