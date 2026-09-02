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

final class InstitutionEducationalDateTime
{
    private const NUMERIC_OFFSET_RFC3339 = '/\A(?<local>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d{1,6})?(?<offset>[+-]\d{2}:\d{2})\z/D';

    /** @var array<string, string> */
    private array $timezones = [];

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

    public function parse(User $teacher, string $value, string $field): CarbonImmutable
    {
        if (! self::hasValidSyntax($value)) {
            $this->reject($field);
        }

        $timezone = $this->timezone($teacher);
        $submitted = new DateTimeImmutable($value);
        $institutionLocal = $submitted->setTimezone(new DateTimeZone($timezone));
        preg_match(self::NUMERIC_OFFSET_RFC3339, $value, $matches);

        if ($institutionLocal->format('Y-m-d\TH:i:s') !== $matches['local']
            || $institutionLocal->format('P') !== $matches['offset']) {
            $this->reject($field);
        }

        return CarbonImmutable::instance($submitted)->utc();
    }

    public function timezone(User $teacher): string
    {
        $institutionId = (string) $teacher->institution_id;

        if (isset($this->timezones[$institutionId])) {
            return $this->timezones[$institutionId];
        }

        $setting = InstitutionSetting::query()
            ->select(['institution_id', 'timezone'])
            ->whereKey($institutionId)
            ->first();

        if (! $setting instanceof InstitutionSetting
            || ! in_array($setting->timezone, DateTimeZone::listIdentifiers(), true)) {
            throw new LogicException('The institution must have a valid IANA timezone setting.');
        }

        return $this->timezones[$institutionId] = $setting->timezone;
    }

    private function reject(string $field): never
    {
        throw ValidationException::withMessages([
            $field => ["The {$field} must be a valid date-time for the institution timezone with an explicit numeric offset."],
        ]);
    }
}
