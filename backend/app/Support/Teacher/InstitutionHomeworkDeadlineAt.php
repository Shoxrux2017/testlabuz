<?php

namespace App\Support\Teacher;

use App\Models\User;
use Carbon\CarbonImmutable;

final class InstitutionHomeworkDeadlineAt
{
    public function __construct(private readonly InstitutionEducationalDateTime $dateTime) {}

    public static function hasValidSyntax(string $value): bool
    {
        return InstitutionEducationalDateTime::hasValidSyntax($value);
    }

    public function parse(User $teacher, string $value): CarbonImmutable
    {
        return $this->dateTime->parse($teacher, $value, 'deadline_at');
    }

    public function timezone(User $teacher): string
    {
        return $this->dateTime->timezone($teacher);
    }
}
