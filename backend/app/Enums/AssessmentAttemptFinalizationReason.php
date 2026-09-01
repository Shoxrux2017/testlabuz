<?php

namespace App\Enums;

enum AssessmentAttemptFinalizationReason: string
{
    case StudentSubmit = 'student_submit';
    case TimeoutAutoSubmit = 'timeout_auto_submit';
    case TaskClosedAutoFinalize = 'task_closed_auto_finalize';
    case HomeworkDeadlineAutoSubmit = 'homework_deadline_auto_submit';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
