<?php

namespace Tests\Feature\Checking;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\Feature\Results\Concerns\RunsLockRaceWorkers;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkAnswerContext;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

/**
 * Carried CL9-9 (S10-BE-004): the `attempts:check-frozen` sweep and a Homework Submit of the same
 * Student serialize on the Attempt rows — checking locks every Attempt of the recipient.
 */
class FrozenAttemptSweepConcurrencyTest extends TestCase
{
    use BuildsStudentHomeworkAnswerContext;
    use RunsLockRaceWorkers;
    use UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
    }

    public function test_a_homework_submit_waits_for_the_sweep_checking_an_earlier_frozen_attempt(): void
    {
        [$student, , $current] = $this->answerContext();
        // The frozen #1 is created after #2, so its id is higher and the sweep's next page cannot pick up #2.
        $current->update(['attempt_number' => 2, 'started_at' => now()->subMinutes(10)]);
        $frozen = AssessmentAttempt::factory()->create(['assessment_student_id' => $current->assessment_student_id, 'attempt_number' => 1,
            'possible_points' => '8.000000', 'started_at' => now()->subHour(), 'status' => 'submitted', 'submitted_at' => now()->subMinutes(30),
            'finalized_at' => now()->subMinutes(30), 'locked_at' => now()->subMinutes(30), 'finalization_reason' => 'student_submit']);

        [$sweep, $submit] = $this->lockRace(
            $this->raceInput('sweep', ['hold' => ['table' => 'assessment_attempts', 'lock' => 'for update']]),
            $this->raceInput('submit_homework', ['actor' => $student->id, 'attempt' => $current->id, 'key' => (string) Str::uuid()]),
            'assessment_attempts',
        );

        $this->assertSame(['event' => 'result', 'outcome' => 'ok', 'counts' => ['candidates' => 1, 'checked_attempts' => 1, 'failures' => 0]], $sweep);
        $this->assertSame(['event' => 'result', 'outcome' => 'ok'], $submit);
        $this->assertSame(AssessmentAttemptStatus::Checked, $frozen->fresh()->status);
        $current->refresh();
        $this->assertSame([AssessmentAttemptStatus::Submitted, AssessmentAttemptFinalizationReason::StudentSubmit],
            [$current->status, $current->finalization_reason]);
    }
}
