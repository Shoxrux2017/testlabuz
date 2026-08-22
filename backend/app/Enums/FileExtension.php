<?php

namespace App\Enums;

enum FileExtension: string
{
    case Pdf = 'pdf';
    case Docx = 'docx';
    case Ppt = 'ppt';
    case Pptx = 'pptx';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
