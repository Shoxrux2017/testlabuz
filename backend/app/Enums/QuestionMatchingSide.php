<?php

namespace App\Enums;

enum QuestionMatchingSide: string
{
    case Left = 'left';
    case Right = 'right';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
