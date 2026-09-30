<?php

namespace Tests\Feature\Console;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\HomeworkAssignment;
use App\Models\OfficialTaskScore;
use App\Models\TopicResultPair;
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

    public function test_the_sweep_repairs_missing_and_stale_official_rows_only(): void
    {
        $missing = $this->officialRecipient();
        $missingBest = $this->scoredAttempt($missing, 1, 'checked', '80.00000000');
        $stale = $this->officialRecipient();
        $staleFirst = $this->scoredAttempt($stale, 1, 'checked', '80.00000000');
        $staleBest = $this->scoredAttempt($stale, 2, 'checked', '90.00000000');
        $this->officialRow($stale, $staleFirst);
        $waiting = $this->officialRecipient();
        $this->scoredAttempt($waiting, 1, 'checked', '80.00000000');
        $this->scoredAttempt($waiting, 2, 'waiting_for_teacher_review');
        $practice = AssessmentStudent::factory()->create(['assessment_id' => HomeworkAssignment::factory()->closed()->create()->assessment_id]);
        $this->scoredAttempt($practice, 1, 'checked', '80.00000000');
        $current = $this->officialRecipient();
        $currentRow = $this->officialRow($current, $this->scoredAttempt($current, 1, 'checked', '70.00000000'))->getAttributes();
        $this->travel(1)->hours();

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Candidates: 0; checked attempts: 0; failures: 0.')
            ->expectsOutput('Official scores repaired: 2; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        $this->assertSame([$missingBest->id, $staleBest->id], [
            OfficialTaskScore::query()->where('student_id', $missing->student_id)->sole()->official_attempt_id,
            OfficialTaskScore::query()->where('student_id', $stale->student_id)->sole()->official_attempt_id,
        ]);
        $this->assertTrue(OfficialTaskScore::query()->where('student_id', $missing->student_id)->sole()->selected_at->equalTo(now()));
        // A pending eligible Attempt leaves the decision to the writer that checks or reviews it.
        $this->assertDatabaseMissing('official_task_scores', ['student_id' => $waiting->student_id]);
        $this->assertDatabaseMissing('official_task_scores', ['student_id' => $practice->student_id]);
        $this->assertSame($currentRow, OfficialTaskScore::query()->where('student_id', $current->student_id)->sole()->getAttributes());
    }

    public function test_one_failing_repair_is_reported_and_the_others_are_repaired(): void
    {
        Exceptions::fake();
        $broken = $this->officialRecipient();
        $this->scoredAttempt($broken, 1, 'checked', '80.00000000');
        // A Homework Attempt is never ineligible, so evaluating this history fails.
        DB::table('assessment_attempts')->where('id', $this->scoredAttempt($broken, 2, 'checked', '50.00000000')->id)
            ->update(['official_score_eligible' => false]);
        $healthy = $this->officialRecipient();
        $this->scoredAttempt($healthy, 1, 'checked', '80.00000000');

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Official scores repaired: 1; failures: 1.')
            ->assertExitCode(Command::FAILURE);

        Exceptions::assertReported(LogicException::class);
        $this->assertDatabaseMissing('official_task_scores', ['student_id' => $broken->student_id]);
        $this->assertDatabaseHas('official_task_scores', ['student_id' => $healthy->student_id]);
    }

    public function test_the_sweep_repairs_official_blitz_rows_including_an_exception_replacement(): void
    {
        $normal = $this->officialBlitzRecipient();
        $normalBest = $this->scoredAttempt($normal, 1, 'checked', '60.00000000');
        $excused = $this->officialBlitzRecipient();
        // The invalidated #1 still waits for review; it is ineligible, so it holds nothing back.
        $invalidated = $this->scoredAttempt($excused, 1, 'waiting_for_teacher_review');
        DB::table('assessment_attempts')->where('id', $invalidated->id)->update(['official_score_eligible' => false]);
        $replacement = $this->scoredAttempt($excused, 2, 'checked', '70.00000000');
        BlitzAttemptException::factory()->create([
            'assessment_id' => $excused->assessment_id, 'assessment_student_id' => $excused->id,
            'invalidated_attempt_id' => $invalidated->id, 'replacement_attempt_id' => $replacement->id,
        ]);

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Official scores repaired: 2; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        $this->assertSame([[$normalBest->id, 'valid_normal_blitz'], [$replacement->id, 'approved_blitz_exception_replacement']], array_map(
            fn (AssessmentStudent $recipient): array => [
                OfficialTaskScore::query()->where('student_id', $recipient->student_id)->sole()->official_attempt_id,
                OfficialTaskScore::query()->where('student_id', $recipient->student_id)->sole()->getRawOriginal('selection_policy_code'),
            ], [$normal, $excused]));
    }

    public function test_a_tie_already_stored_on_the_lower_attempt_number_is_not_a_repair_candidate(): void
    {
        $tied = $this->officialRecipient();
        $first = $this->scoredAttempt($tied, 1, 'checked', '80.00000000');
        $this->scoredAttempt($tied, 2, 'checked', '80.00000000');
        $row = $this->officialRow($tied, $first)->getAttributes();
        $recipientLocks = 0;
        DB::listen(function ($query) use (&$recipientLocks): void {
            if (str_contains($query->sql, 'from "assessment_students"') && str_ends_with($query->sql, 'for update')) {
                $recipientLocks++;
            }
        });

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Official scores repaired: 0; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        // The candidate query keeps the evaluator's tie-break, so nothing is locked or resolved.
        $this->assertSame(0, $recipientLocks);
        $this->assertSame($row, OfficialTaskScore::query()->sole()->getAttributes());
    }

    private function officialBlitzRecipient(): AssessmentStudent
    {
        $blitzId = TopicResultPair::factory()->withBlitz()->create()->blitz_assessment_id;
        BlitzTask::factory()->closedIndividual()->create(['assessment_id' => $blitzId]);

        return AssessmentStudent::factory()->create(['assessment_id' => $blitzId]);
    }

    private function officialRecipient(): AssessmentStudent
    {
        $homework = HomeworkAssignment::factory()->closed()->create();
        TopicResultPair::factory()->create(['homework_assessment_id' => $homework->assessment_id]);

        return AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id]);
    }

    private function scoredAttempt(AssessmentStudent $recipient, int $number, string $status, ?string $normalized = null): AssessmentAttempt
    {
        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id, 'attempt_number' => $number, 'status' => $status,
            'started_at' => now()->subHour(), 'submitted_at' => now()->subMinutes(30), 'finalized_at' => now()->subMinutes(30),
            'locked_at' => now()->subMinutes(30), 'finalization_reason' => 'student_submit', 'possible_points' => '4.000000',
            'normalized_score' => $normalized, 'earned_points' => $normalized === null ? null : '1.00000000',
            'scoring_completed_at' => $normalized === null ? null : now()->subMinutes(20),
        ])->fresh();
    }

    private function officialRow(AssessmentStudent $recipient, AssessmentAttempt $attempt): OfficialTaskScore
    {
        return OfficialTaskScore::factory()->create([
            'institution_id' => $recipient->institution_id, 'assessment_id' => $recipient->assessment_id,
            'student_id' => $recipient->student_id, 'official_attempt_id' => $attempt->id,
            'normalized_score' => $attempt->normalized_score, 'selection_policy_code' => 'highest_valid_completed',
            'selected_at' => now()->subMinutes(20),
        ])->fresh();
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
