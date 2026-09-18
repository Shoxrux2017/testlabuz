<?php

namespace App\Enums;

enum IdempotencyOperation: string
{
    case StudentBlitzAttemptStart = 'student.blitz.attempt.start';
    case StudentBlitzAttemptSubmit = 'student.blitz.attempt.submit';
    case StudentHomeworkAttemptStart = 'student.homework.attempt.start';
    case StudentHomeworkAttemptSubmit = 'student.homework.attempt.submit';
    case TeacherBlitzActivate = 'teacher.blitz.activate';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
