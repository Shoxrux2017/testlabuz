<?php

namespace Tests\Feature\Checking;

use App\Enums\AssessmentAttemptStatus;
use App\Models\BlitzAttemptException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\Feature\Results\Concerns\RunsLockRaceWorkers;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

/**
 * Carried CL9-9 (S10-BE-004): an exception grant and a checking run of the same Blitz Attempt
 * serialize on the Topic — checking holds it shared, the grant needs it exclusively.
 */
class BlitzExceptionCheckingConcurrencyTest extends TestCase
{
    use BuildsBlitzExceptionContext;
    use RunsLockRaceWorkers;
    use UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_an_exception_grant_waits_for_the_checking_run_of_the_normal_attempt(): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext(terminal: true);
        $this->assertSame(AssessmentAttemptStatus::Submitted, $normal->status);

        [$check, $grant] = $this->lockRace(
            $this->raceInput('check_attempt', ['attempt' => $normal->id, 'hold' => ['table' => 'assessment_students', 'lock' => 'for update']]),
            $this->raceInput('grant_exception', ['actor' => $teacher->id, 'assessment' => $assessment->id, 'student' => $student->id,
                'key' => (string) Str::uuid()]),
            'topics',
        );

        $this->assertSame(['event' => 'result', 'outcome' => 'ok', 'checked' => true], $check);
        $this->assertSame(['event' => 'result', 'outcome' => 'ok'], $grant);
        $normal->refresh();
        // The grant saw the committed checking result and withdrew the checked Attempt from the official score.
        $this->assertNotContains($normal->status, [AssessmentAttemptStatus::Submitted, AssessmentAttemptStatus::TimedOutFinalized]);
        $this->assertFalse($normal->official_score_eligible);
        $this->assertSame($normal->id, BlitzAttemptException::query()->sole()->invalidated_attempt_id);
    }
}
