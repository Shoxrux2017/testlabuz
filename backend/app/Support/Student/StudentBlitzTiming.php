<?php

namespace App\Support\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzTimerStartMode;
use App\Exceptions\Student\StudentBlitzTimeExpiredException;
use App\Models\AssessmentAttempt;
use App\Models\BlitzTask;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use LogicException;

final class StudentBlitzTiming
{
    public function now(): CarbonImmutable
    {
        return CarbonImmutable::instance(now())->utc()->startOfSecond();
    }

    public function assertValidTask(BlitzTask $blitz): void
    {
        if ($blitz->activated_at === null || $blitz->duration_seconds <= 0
            || ! $blitz->timer_start_mode_snapshot instanceof BlitzTimerStartMode) {
            throw new LogicException('Active Blitz requires complete activation timing.');
        }

        $this->assertWholeSecond($blitz->activated_at);

        if ($blitz->timer_start_mode_snapshot === BlitzTimerStartMode::Synchronized) {
            if ($blitz->synchronized_ends_at === null
                || ! $blitz->synchronized_ends_at->equalTo($blitz->activated_at->copy()->addSeconds($blitz->duration_seconds))) {
                throw new LogicException('Synchronized Blitz end must match its activation duration.');
            }

            $this->assertWholeSecond($blitz->synchronized_ends_at);
        } elseif ($blitz->synchronized_ends_at !== null) {
            throw new LogicException('Individual Blitz cannot have a synchronized end.');
        }
    }

    public function assertValidAttempt(BlitzTask $blitz, AssessmentAttempt $attempt): void
    {
        if ($attempt->started_at === null || $attempt->deadline_at === null) {
            throw new LogicException('Blitz Attempt requires persisted start and deadline timestamps.');
        }

        $this->assertWholeSecond($attempt->started_at);
        $this->assertWholeSecond($attempt->deadline_at);
        $expectedDeadline = $blitz->timer_start_mode_snapshot === BlitzTimerStartMode::Synchronized
            ? $blitz->synchronized_ends_at
            : $attempt->started_at->copy()->addSeconds($blitz->duration_seconds);

        if ($expectedDeadline === null || ! $attempt->deadline_at->equalTo($expectedDeadline)
            || ! $attempt->started_at->lt($attempt->deadline_at)) {
            throw new LogicException('Blitz Attempt deadline must match its authoritative timer mode.');
        }
    }

    public function assertExecutable(BlitzTask $blitz, ?AssessmentAttempt $attempt, CarbonInterface $serverNow): void
    {
        $this->assertWholeSecond($serverNow);
        $deadline = $blitz->timer_start_mode_snapshot === BlitzTimerStartMode::Synchronized
            ? $blitz->synchronized_ends_at
            : ($attempt?->status === AssessmentAttemptStatus::InProgress ? $attempt->deadline_at : null);

        if ($deadline !== null && $serverNow->gte($deadline)) {
            throw new StudentBlitzTimeExpiredException;
        }
    }

    /** @return array<string, mixed> */
    public function project(BlitzTask $blitz, ?AssessmentAttempt $attempt, CarbonInterface $serverNow): array
    {
        $this->assertValidTask($blitz);
        $this->assertWholeSecond($serverNow);

        if ($attempt !== null) {
            $this->assertValidAttempt($blitz, $attempt);
        }

        $deadline = $blitz->timer_start_mode_snapshot === BlitzTimerStartMode::Synchronized
            ? $blitz->synchronized_ends_at
            : $attempt?->deadline_at;

        return [
            'mode' => $blitz->timer_start_mode_snapshot->value,
            'server_now' => $this->serialize($serverNow),
            'synchronized_ends_at' => $blitz->synchronized_ends_at === null ? null : $this->serialize($blitz->synchronized_ends_at),
            'deadline_at' => $deadline === null ? null : $this->serialize($deadline),
            'remaining_seconds' => $deadline === null ? null : max(0, $deadline->getTimestamp() - $serverNow->getTimestamp()),
        ];
    }

    private function assertWholeSecond(CarbonInterface $instant): void
    {
        if ($instant->micro !== 0) {
            throw new LogicException('Blitz timer timestamps must use whole-second precision.');
        }
    }

    private function serialize(CarbonInterface $instant): string
    {
        return $instant->copy()->utc()->format('Y-m-d\TH:i:s\Z');
    }
}
