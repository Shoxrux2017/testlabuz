<?php

namespace Tests\Feature\Console;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use Illuminate\Console\Command;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Exceptions;
use LogicException;
use Tests\TestCase;

class CheckFrozenAttemptsCommandTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
    }

    public function test_the_sweep_is_registered_and_scheduled_every_minute_without_overlap(): void
    {
        $this->assertArrayHasKey('attempts:check-frozen', Artisan::all());
        $events = collect(app(Schedule::class)->events())->filter(
            fn ($event) => str_contains($event->command ?? '', 'attempts:check-frozen'),
        );

        $this->assertCount(1, $events);
        $event = $events->sole();
        $this->assertSame('* * * * *', $event->expression);
        $this->assertTrue($event->withoutOverlapping);
        $this->assertSame(5, $event->expiresAt);
        $this->assertFalse($event->onOneServer);
    }

    public function test_the_sweep_checks_every_frozen_attempt_and_ignores_the_rest(): void
    {
        $submitted = $this->frozenAttempt(AssessmentAttemptStatus::Submitted);
        $timedOut = $this->frozenAttempt(AssessmentAttemptStatus::TimedOutFinalized);
        $inProgress = $this->attempt(HomeworkAssignment::factory()->active()->create());
        $checked = $this->frozenAttempt(AssessmentAttemptStatus::Submitted);
        DB::table('assessment_attempts')->where('id', $checked->id)->update(['status' => 'checked']);
        $untouched = [$inProgress->fresh()->getAttributes(), $checked->fresh()->getAttributes()];

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Candidates: 2; checked attempts: 2; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        foreach ([$submitted, $timedOut] as $attempt) {
            $fresh = $attempt->fresh();
            $this->assertSame('checked', $fresh->getRawOriginal('status'));
            $this->assertSame('0.00000000', $fresh->earned_points);
            $this->assertSame('0.00000000', $fresh->normalized_score);
        }
        $this->assertSame($untouched, [$inProgress->fresh()->getAttributes(), $checked->fresh()->getAttributes()]);

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Candidates: 0; checked attempts: 0; failures: 0.')
            ->assertExitCode(Command::SUCCESS);
    }

    public function test_one_failing_attempt_is_reported_and_the_others_are_checked(): void
    {
        Exceptions::fake();
        $broken = $this->frozenAttempt(AssessmentAttemptStatus::Submitted);
        // A zero possible-points snapshot cannot be normalized.
        DB::table('assessment_attempts')->where('id', $broken->id)->update(['possible_points' => '0.000000']);
        $healthy = $this->frozenAttempt(AssessmentAttemptStatus::Submitted);
        $brokenBefore = $broken->fresh()->getAttributes();

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Candidates: 2; checked attempts: 1; failures: 1.')
            ->assertExitCode(Command::FAILURE);

        Exceptions::assertReported(LogicException::class);
        $this->assertSame($brokenBefore, $broken->fresh()->getAttributes());
        $this->assertSame('checked', $healthy->fresh()->getRawOriginal('status'));
    }

    private function frozenAttempt(AssessmentAttemptStatus $status): AssessmentAttempt
    {
        $attempt = $this->attempt(HomeworkAssignment::factory()->closed()->create());
        $timedOut = $status === AssessmentAttemptStatus::TimedOutFinalized;
        $attempt->update([
            'status' => $status,
            'submitted_at' => $timedOut ? null : now()->subMinutes(30),
            'finalized_at' => now()->subMinutes(30),
            'locked_at' => now()->subMinutes(30),
            'finalization_reason' => $timedOut
                ? AssessmentAttemptFinalizationReason::TimeoutAutoSubmit
                : AssessmentAttemptFinalizationReason::StudentSubmit,
        ]);

        return $attempt->fresh();
    }

    private function attempt(HomeworkAssignment $homework): AssessmentAttempt
    {
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);

        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient,
            'started_at' => now()->subHour(),
            'possible_points' => '5.000000',
        ]);
    }
}
