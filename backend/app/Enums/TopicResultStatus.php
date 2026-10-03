<?php

namespace App\Enums;

/** A Topic result status (docs/09 §25.3). Open results take one of the first six; a closed result is `closed`. */
enum TopicResultStatus: string
{
    case WaitingForHomework = 'waiting_for_homework';
    case WaitingForBlitz = 'waiting_for_blitz';
    case WaitingForTeacherReview = 'waiting_for_teacher_review';
    case WaitingForSettings = 'waiting_for_settings';
    case Calculated = 'calculated';
    case NotCompleted = 'not_completed';
    case Closed = 'closed';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
