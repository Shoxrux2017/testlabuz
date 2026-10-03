<?php

namespace App\Enums;

/** Whether the official Homework and Blitz scores differ by no more than the acceptable difference. */
enum TopicResultConsistency: string
{
    case Consistent = 'consistent';
    case Inconsistent = 'inconsistent';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
