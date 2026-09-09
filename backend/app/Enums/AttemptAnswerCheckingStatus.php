<?php

namespace App\Enums;

enum AttemptAnswerCheckingStatus: string
{
    case Pending = 'pending';
    case AutoChecked = 'auto_checked';
    case WaitingForTeacherReview = 'waiting_for_teacher_review';
    case TeacherChecked = 'teacher_checked';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
