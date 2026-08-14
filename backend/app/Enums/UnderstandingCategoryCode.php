<?php

namespace App\Enums;

enum UnderstandingCategoryCode: string
{
    case UnderstoodWell = 'understood_well';
    case PartiallyUnderstood = 'partially_understood';
    case NeedsRevision = 'needs_revision';
    case NeedsTeacherSupport = 'needs_teacher_support';
    case NotCompleted = 'not_completed';

    public function label(): string
    {
        return match ($this) {
            self::UnderstoodWell => 'Understood well',
            self::PartiallyUnderstood => 'Partially understood',
            self::NeedsRevision => 'Needs revision',
            self::NeedsTeacherSupport => 'Needs teacher support',
            self::NotCompleted => 'Not completed',
        };
    }

    public function sortOrder(): int
    {
        return match ($this) {
            self::UnderstoodWell => 1,
            self::PartiallyUnderstood => 2,
            self::NeedsRevision => 3,
            self::NeedsTeacherSupport => 4,
            self::NotCompleted => 5,
        };
    }

    public function isNumeric(): bool
    {
        return $this !== self::NotCompleted;
    }

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
