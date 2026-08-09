<?php

namespace App\Enums;

enum UserRole: string
{
    case PlatformOwner = 'platform_owner';
    case InstitutionAdmin = 'institution_admin';
    case Teacher = 'teacher';
    case Student = 'student';
    case Parent = 'parent';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
