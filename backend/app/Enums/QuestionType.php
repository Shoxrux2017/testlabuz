<?php

namespace App\Enums;

enum QuestionType: string
{
    case SingleChoice = 'single_choice';
    case MultipleChoice = 'multiple_choice';
    case TrueFalse = 'true_false';
    case ShortWritten = 'short_written';
    case OpenWritten = 'open_written';
    case FileBased = 'file_based';
    case Matching = 'matching';
    case Ordering = 'ordering';
    case FillInBlank = 'fill_in_blank';

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
