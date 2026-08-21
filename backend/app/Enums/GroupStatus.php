<?php

namespace App\Enums;

enum GroupStatus: string
{
    case Active = 'active';
    case Archived = 'archived';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
