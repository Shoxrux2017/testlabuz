<?php

namespace App\Enums;

/** The state of one side (Homework or Blitz) of a Topic result (docs/09 §25.3 Side States). */
enum TopicResultSideState: string
{
    case Ready = 'ready';
    case WaitingForTeacherReview = 'waiting_for_teacher_review';
    case Checking = 'checking';
    case NotActivated = 'not_activated';
    case Open = 'open';
    case Missing = 'missing';
    case NotDesignated = 'not_designated';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
