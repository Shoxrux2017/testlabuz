<?php

namespace Tests\Feature\Console;

use App\Actions\Homework\ReconcileDueHomeworkDeadlines;
use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use Illuminate\Console\Command;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Exceptions;
use LogicException;
use Tests\TestCase;

class ReconcileHomeworkDeadlinesCommandTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-09 10:00:00 UTC'));
    }

    public function test_command_is_registered_and_scheduled_exactly_once_every_minute_with_five_minute_overlap_expiry(): void
    {
        $this->assertArrayHasKey('homework:reconcile-deadlines', Artisan::all());
        $events = collect(app(Schedule::class)->events())->filter(
            fn ($event) => str_contains($event->command ?? '', 'homework:reconcile-deadlines'),
        );

        $this->assertCount(1, $events);
        $event = $events->sole();
        $this->assertSame('* * * * *', $event->expression);
        $this->assertTrue($event->withoutOverlapping);
        $this->assertSame(5, $event->expiresAt);
        $this->assertFalse($event->onOneServer);
    }

    public function test_command_reconciles_due_work_across_institutions_and_ignores_ineligible_work(): void
    {
        $first = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $second = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()->subMinutes(3)]);
        $firstAttempt = $this->attempt($first);
        $secondAttempt = $this->attempt($second);
        $this->assertNotSame($first->institution_id, $second->institution_id);
        $ignored = [
            HomeworkAssignment::factory()->active()->create(['deadline_at' => now()->addSecond()]),
            HomeworkAssignment::factory()->active()->create(['deadline_at' => null]),
            HomeworkAssignment::factory()->draft()->create(['deadline_at' => now()]),
            HomeworkAssignment::factory()->closed()->create(['deadline_at' => now()]),
            HomeworkAssignment::factory()->archivedFromDraft()->create(['deadline_at' => now()]),
        ];
        $ignoredAttempts = array_map(fn ($homework) => $this->attempt($homework), $ignored);
        $noAttempts = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $terminalOnly = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $terminal = $this->attempt($terminalOnly);
        $terminal->update(['status' => AssessmentAttemptStatus::Submitted]);
        $preserved = [...$ignored, ...$ignoredAttempts, $noAttempts, $terminalOnly, $terminal, $first, $second];
        $before = array_map(fn ($model) => $model->fresh()->getAttributes(), $preserved);

        $this->artisan('homework:reconcile-deadlines')
            ->expectsOutput('Candidates: 2; finalized attempts: 2; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        foreach ([$firstAttempt, $secondAttempt] as $attempt) {
            $this->assertSame(AssessmentAttemptStatus::Submitted, $attempt->fresh()->status);
            $this->assertSame('homework_deadline_auto_submit', $attempt->fresh()->finalization_reason->value);
        }
        $this->assertSame($before, array_map(fn ($model) => $model->fresh()->getAttributes(), $preserved));
        $this->assertSame(['candidates' => 0, 'finalized_attempts' => 0, 'failures' => 0], app(ReconcileDueHomeworkDeadlines::class)());
    }

    public function test_keyset_scan_does_not_skip_work_as_successful_candidates_disappear(): void
    {
        $first = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $this->attempt($first);
        $assessment = $first->assessment;

        for ($index = 1; $index < 101; $index++) {
            $nextAssessment = Assessment::factory()->homework()->create([
                'institution_id' => $assessment->institution_id,
                'topic_id' => $assessment->topic_id,
                'teacher_id' => $assessment->teacher_id,
            ]);
            $homework = HomeworkAssignment::factory()->active()->create([
                'assessment_id' => $nextAssessment,
                'deadline_at' => now(),
            ]);
            $this->attempt($homework);
        }

        $this->assertSame(['candidates' => 101, 'finalized_attempts' => 101, 'failures' => 0], app(ReconcileDueHomeworkDeadlines::class)());
        $this->assertSame(0, AssessmentAttempt::query()->where('status', AssessmentAttemptStatus::InProgress->value)->count());
        $this->assertSame(101, AssessmentAttempt::query()->where('status', AssessmentAttemptStatus::Submitted->value)->count());
    }

    public function test_candidate_invariant_failure_is_reported_and_later_candidate_still_commits_with_command_failure(): void
    {
        Exceptions::fake();
        $firstAssessment = Assessment::factory()->homework()->create(['id' => '00000000-0000-4000-8000-000000000001']);
        $first = HomeworkAssignment::factory()->active()->create(['assessment_id' => $firstAssessment, 'deadline_at' => now()]);
        $valid = $this->attempt($first);
        $inconsistent = $this->attempt($first);
        $inconsistent->update(['locked_at' => now()]);
        $before = [$valid->fresh()->getAttributes(), $inconsistent->fresh()->getAttributes()];
        $secondAssessment = Assessment::factory()->homework()->create(['id' => '00000000-0000-4000-8000-000000000002']);
        $second = HomeworkAssignment::factory()->active()->create(['assessment_id' => $secondAssessment, 'deadline_at' => now()]);
        $later = $this->attempt($second);

        $this->artisan('homework:reconcile-deadlines')
            ->expectsOutput('Candidates: 2; finalized attempts: 1; failures: 1.')
            ->assertExitCode(Command::FAILURE);

        Exceptions::assertReported(LogicException::class);
        $this->assertSame($before, [$valid->fresh()->getAttributes(), $inconsistent->fresh()->getAttributes()]);
        $this->assertSame(AssessmentAttemptStatus::Submitted, $later->fresh()->status);
        $this->assertSame('homework_deadline_auto_submit', $later->fresh()->finalization_reason->value);
    }

    private function attempt(HomeworkAssignment $homework): AssessmentAttempt
    {
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);

        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient,
            'started_at' => now()->subHour(),
        ]);
    }
}
