<?php

namespace App\Enums;

enum IdempotencyOperation: string
{
    case StudentHomeworkAttemptStart = 'student.homework.attempt.start';
    case StudentHomeworkAttemptSubmit = 'student.homework.attempt.submit';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
