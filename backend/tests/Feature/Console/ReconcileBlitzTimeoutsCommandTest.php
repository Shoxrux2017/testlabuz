<?php

namespace Tests\Feature\Console;

use App\Actions\Blitz\ReconcileDueBlitzTimeouts;
use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use Illuminate\Console\Command;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Exceptions;
use LogicException;
use Tests\TestCase;

class ReconcileBlitzTimeoutsCommandTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_command_is_registered_once_every_minute_with_five_minute_overlap_expiry_and_homework_schedule_preserved(): void
    {
        foreach (['blitz:reconcile-timeouts', 'homework:reconcile-deadlines'] as $command) {
            $this->assertArrayHasKey($command, Artisan::all());
            $events = collect(app(Schedule::class)->events())->filter(
                fn ($event) => str_contains($event->command ?? '', $command),
            );
            $this->assertCount(1, $events);
            $event = $events->sole();
            $this->assertSame('* * * * *', $event->expression);
            $this->assertTrue($event->withoutOverlapping);
            $this->assertSame(5, $event->expiresAt);
            $this->assertFalse($event->onOneServer);
        }
    }

    public function test_command_finalizes_only_due_attempts_across_institutions_without_closing_tasks_or_changing_homework(): void
    {
        $synchronized = BlitzTask::factory()->activeSynchronized()->create([
            'created_at' => now()->subMinutes(11), 'activated_at' => now()->subMinutes(10),
        ]);
        $individual = BlitzTask::factory()->activeIndividual()->create();
        $this->assertNotSame($synchronized->institution_id, $individual->institution_id);
        $synchronizedDue = $this->attempt($synchronized);
        $individualDue = $this->attempt($individual, ['deadline_at' => now()->subMinutes(3)]);
        $future = $this->attempt($individual, ['deadline_at' => now()->addSecond()]);
        $ignored = [$future, $synchronized, $synchronized->assessment, $individual, $individual->assessment];
        foreach (['draft', 'scheduled', 'closedIndividual', 'archivedFromDraft'] as $state) {
            $blitz = BlitzTask::factory()->{$state}()->create();
            $ignored[] = $this->attempt($blitz);
            $ignored[] = $blitz;
        }
        $terminalOnly = BlitzTask::factory()->activeIndividual()->create();
        $ignored[] = $this->attempt($terminalOnly, ['status' => AssessmentAttemptStatus::Submitted]);
        $ignored[] = BlitzTask::factory()->activeIndividual()->create();
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);
        $ignored[] = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient, 'started_at' => now()->subHour(), 'deadline_at' => now(),
        ]);
        $ignored[] = $homework;
        $before = array_map(fn ($model) => $model->fresh()->getAttributes(), $ignored);

        $this->artisan('blitz:reconcile-timeouts')
            ->expectsOutput('Candidates: 2; finalized attempts: 2; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        foreach ([$synchronizedDue, $individualDue] as $attempt) {
            $frozen = $attempt->fresh();
            $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $frozen->status);
            $this->assertSame('timeout_auto_submit', $frozen->finalization_reason->value);
            $this->assertNull($frozen->submitted_at);
            $this->assertTrue($frozen->finalized_at->equalTo($attempt->deadline_at));
            $this->assertTrue($frozen->locked_at->equalTo($attempt->deadline_at));
        }
        $this->assertSame($before, array_map(fn ($model) => $model->fresh()->getAttributes(), $ignored));
        $this->assertSame(['candidates' => 0, 'finalized_attempts' => 0, 'failures' => 0], app(ReconcileDueBlitzTimeouts::class)());
    }

    public function test_keyset_scan_continues_past_a_batch_as_successful_candidates_disappear(): void
    {
        $first = BlitzTask::factory()->activeIndividual()->create();
        $this->attempt($first);
        $assessment = $first->assessment;

        for ($index = 1; $index < 101; $index++) {
            $next = Assessment::factory()->blitz()->create([
                'institution_id' => $assessment->institution_id,
                'topic_id' => $assessment->topic_id,
                'teacher_id' => $assessment->teacher_id,
            ]);
            $blitz = BlitzTask::factory()->activeIndividual()->create(['assessment_id' => $next]);
            $this->attempt($blitz);
        }

        $this->assertSame(['candidates' => 101, 'finalized_attempts' => 101, 'failures' => 0], app(ReconcileDueBlitzTimeouts::class)());
        $this->assertSame(0, AssessmentAttempt::query()->where('status', AssessmentAttemptStatus::InProgress->value)->count());
        $this->assertSame(101, AssessmentAttempt::query()->where('status', AssessmentAttemptStatus::TimedOutFinalized->value)->count());
    }

    public function test_corrupt_candidate_is_reported_and_rolled_back_while_a_later_candidate_commits(): void
    {
        Exceptions::fake();
        $firstAssessment = Assessment::factory()->blitz()->create(['id' => '00000000-0000-4000-8000-000000000001']);
        $first = BlitzTask::factory()->activeIndividual()->create(['assessment_id' => $firstAssessment]);
        $valid = $this->attempt($first, ['id' => '00000000-0000-4000-8000-000000000001']);
        $invalid = $this->attempt($first, ['id' => '00000000-0000-4000-8000-000000000002', 'locked_at' => now()]);
        $before = [$valid->fresh()->getAttributes(), $invalid->fresh()->getAttributes()];
        $secondAssessment = Assessment::factory()->blitz()->create(['id' => '00000000-0000-4000-8000-000000000002']);
        $second = BlitzTask::factory()->activeIndividual()->create(['assessment_id' => $secondAssessment]);
        $later = $this->attempt($second);

        $this->artisan('blitz:reconcile-timeouts')
            ->expectsOutput('Candidates: 2; finalized attempts: 1; failures: 1.')
            ->assertExitCode(Command::FAILURE);

        Exceptions::assertReported(LogicException::class);
        $this->assertSame($before, [$valid->fresh()->getAttributes(), $invalid->fresh()->getAttributes()]);
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $later->fresh()->status);
        $this->assertTrue($later->fresh()->finalized_at->equalTo($later->deadline_at));
    }

    private function attempt(BlitzTask $blitz, array $attributes = []): AssessmentAttempt
    {
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $blitz->assessment_id]);

        return AssessmentAttempt::factory()->create(array_merge([
            'assessment_student_id' => $recipient, 'started_at' => now()->subHour(), 'deadline_at' => now(),
        ], $attributes))->fresh();
    }
}
