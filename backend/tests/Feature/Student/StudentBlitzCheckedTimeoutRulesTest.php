<?php

namespace Tests\Feature\Student;

use App\Models\AssessmentAttempt;
use App\Models\IdempotencyRecord;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

/**
 * S09-T2: rules that mean "this Attempt ended by timeout" follow the finalization
 * reason, so Stage 9 checking a timed-out Attempt changes no Stage 8 response.
 */
class StudentBlitzCheckedTimeoutRulesTest extends TestCase
{
    // Blitz reads own a real top-level snapshot transaction, so fixtures are committed.
    use BuildsBlitzExceptionContext;
    use UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        // Whole-second time, as the exception fixtures derive lineage times from now().
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    /** @return array<string, array{string}> */
    public static function checkedStatuses(): array
    {
        return [
            'still timed out' => ['timed_out_finalized'],
            'waiting for Teacher review' => ['waiting_for_teacher_review'],
            'checked' => ['checked'],
        ];
    }

    #[DataProvider('checkedStatuses')]
    public function test_a_timed_out_attempt_keeps_expiring_every_start_and_read_after_checking(string $status): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, 'individual');
        $this->startStudentBlitz($student, $assessment)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $this->travelTo($attempt->deadline_at);
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->assertSame('timeout_auto_submit', $attempt->fresh()->getRawOriginal('finalization_reason'));
        DB::table('assessment_attempts')->where('id', $attempt->id)->update(['status' => $status]);
        $before = $attempt->fresh()->getAttributes();
        $claims = IdempotencyRecord::query()->count();

        $this->startStudentBlitz($student, $assessment)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertSame($claims, IdempotencyRecord::query()->count());
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    #[DataProvider('checkedStatuses')]
    public function test_an_exception_over_a_timed_out_first_attempt_still_exhausts_a_normal_start(string $status): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext(terminal: false);
        $this->travelTo($normal->deadline_at->copy()->addMinute());
        $this->timeOut($normal, $status);
        $this->grantException($teacher, $assessment, $student)->assertCreated();

        // The exception rule precedes the timeout rule for start_normal.
        $this->startStudentBlitz($student, $assessment)
            ->assertConflict()->assertJsonPath('code', 'attempts_exhausted');
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    #[DataProvider('checkedStatuses')]
    public function test_a_timed_out_replacement_keeps_expiring_after_checking(string $status): void
    {
        [$student, $assessment, , , $replacement] = $this->replacementContext();
        $this->travelTo($replacement->deadline_at->copy()->addMinute());
        $this->timeOut($replacement, $status);

        $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $replacement->id)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->assertDatabaseCount('assessment_attempts', 2);
    }

    /** @return array<string, array{string}> */
    public static function checkingStatuses(): array
    {
        return [
            'waiting for Teacher review' => ['waiting_for_teacher_review'],
            'checked' => ['checked'],
        ];
    }

    #[DataProvider('checkingStatuses')]
    public function test_a_student_submitted_attempt_keeps_its_rules_after_checking(string $status): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, 'individual');
        $this->startStudentBlitz($student, $assessment)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $this->terminateStudentBlitzAttempt($attempt);
        DB::table('assessment_attempts')->where('id', $attempt->id)->update(['status' => $status]);
        $before = $attempt->fresh()->getAttributes();

        $this->startStudentBlitz($student, $assessment)
            ->assertConflict()->assertJsonPath('code', 'attempts_exhausted');
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id)
            ->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk();

        $this->assertSame($before, $attempt->fresh()->getAttributes());
    }

    /** Freezes the Attempt at its deadline by timeout, then puts it in the given checking status. */
    private function timeOut(AssessmentAttempt $attempt, string $status): void
    {
        DB::table('assessment_attempts')->where('id', $attempt->id)->update([
            'status' => $status,
            'submitted_at' => null,
            'finalized_at' => $attempt->deadline_at,
            'locked_at' => $attempt->deadline_at,
            'finalization_reason' => 'timeout_auto_submit',
        ]);
    }
}
