<?php

namespace App\Enums;

/** Why a Topic result was closed. */
enum TopicResultClosureReason: string
{
    case Teacher = 'teacher';
    case TopicArchived = 'topic_archived';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
