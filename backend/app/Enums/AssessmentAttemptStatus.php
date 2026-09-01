<?php

namespace App\Enums;

enum AssessmentAttemptStatus: string
{
    case InProgress = 'in_progress';
    case Submitted = 'submitted';
    case TimedOutFinalized = 'timed_out_finalized';
    case WaitingForTeacherReview = 'waiting_for_teacher_review';
    case Checked = 'checked';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
