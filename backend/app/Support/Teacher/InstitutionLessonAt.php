<?php

namespace App\Support\Teacher;

use App\Models\InstitutionSetting;
use App\Models\User;
use Carbon\CarbonImmutable;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Validation\ValidationException;
use LogicException;
use Throwable;

final class InstitutionLessonAt
{
    private const NUMERIC_OFFSET_RFC3339 = '/\A(?<local>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d{1,6})?(?<offset>[+-]\d{2}:\d{2})\z/D';

    public static function hasValidSyntax(string $value): bool
    {
        if (preg_match(self::NUMERIC_OFFSET_RFC3339, $value, $matches) !== 1) {
            return false;
        }

        try {
            $dateTime = new DateTimeImmutable($value);
        } catch (Throwable) {
            return false;
        }

        $parseErrors = DateTimeImmutable::getLastErrors();

        return ($parseErrors === false || ($parseErrors['warning_count'] === 0 && $parseErrors['error_count'] === 0))
            && $dateTime->format('Y-m-d\TH:i:s') === $matches['local']
            && $dateTime->format('P') === $matches['offset'];
    }

    public function parse(User $teacher, string $value): CarbonImmutable
    {
        if (! self::hasValidSyntax($value)) {
            $this->reject();
        }

        $setting = InstitutionSetting::query()
            ->select(['institution_id', 'timezone'])
            ->whereKey($teacher->institution_id)
            ->first();

        if (! $setting instanceof InstitutionSetting
            || ! in_array($setting->timezone, DateTimeZone::listIdentifiers(), true)) {
            throw new LogicException('The institution must have a valid IANA timezone setting.');
        }

        $submitted = new DateTimeImmutable($value);
        $institutionLocal = $submitted->setTimezone(new DateTimeZone($setting->timezone));
        preg_match(self::NUMERIC_OFFSET_RFC3339, $value, $matches);

        if ($institutionLocal->format('Y-m-d\TH:i:s') !== $matches['local']
            || $institutionLocal->format('P') !== $matches['offset']) {
            $this->reject();
        }

        return CarbonImmutable::instance($submitted)->utc();
    }

    private function reject(): never
    {
        throw ValidationException::withMessages([
            'lesson_at' => ['The lesson_at must be a valid date-time for the institution timezone with an explicit numeric offset.'],
        ]);
    }
}
