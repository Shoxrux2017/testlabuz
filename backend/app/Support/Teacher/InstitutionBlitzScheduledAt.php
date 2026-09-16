<?php

namespace App\Support\Teacher;

use App\Models\User;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use Illuminate\Validation\ValidationException;

final class InstitutionBlitzScheduledAt
{
    public function __construct(private readonly InstitutionEducationalDateTime $dateTime) {}

    public static function hasValidSyntax(string $value): bool
    {
        return InstitutionEducationalDateTime::hasValidSyntax($value);
    }

    public static function serialize(?DateTimeInterface $scheduledAt): ?string
    {
        if ($scheduledAt === null) {
            return null;
        }

        $utc = DateTimeImmutable::createFromInterface($scheduledAt)->setTimezone(new DateTimeZone('UTC'));

        return $utc->format($utc->format('u') === '000000' ? 'Y-m-d\TH:i:s\Z' : 'Y-m-d\TH:i:s.u\Z');
    }

    public function parse(User $teacher, string $value): CarbonImmutable
    {
        return $this->dateTime->parse($teacher, $value, 'scheduled_at');
    }

    public function requireFuture(User $teacher, string $value, CarbonInterface $now): CarbonImmutable
    {
        $scheduledAt = $this->parse($teacher, $value);

        if (! $scheduledAt->greaterThan($now)) {
            throw ValidationException::withMessages([
                'scheduled_at' => ['The scheduled_at must be in the future.'],
            ]);
        }

        return $scheduledAt;
    }

    public function timezone(User $teacher): string
    {
        return $this->dateTime->timezone($teacher);
    }
}
