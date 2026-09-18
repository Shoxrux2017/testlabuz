<?php

namespace Tests\Feature\Student;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Actions\Teacher\CloseTeacherBlitz;
use App\Models\AssessmentAttempt;
use App\Models\InstitutionSetting;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

class StudentBlitzReplacementAttemptTimingTest extends TestCase
{
    use BuildsBlitzExceptionContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('replacementWindows')]
    public function test_replacement_gets_full_duration_and_projects_its_own_window(string $mode, string $instant): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext($mode);
        $blitzBefore = $assessment->blitzTask->getAttributes();
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        InstitutionSetting::query()->whereKey($student->institution_id)->update(['blitz_timer_start_mode' => $mode === 'individual' ? 'synchronized' : 'individual']);
        $this->travelTo(Carbon::parse($instant));
        $detail = $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk()
            ->assertJsonPath('data.attempts.additional_exception_granted', true)
            ->assertJsonPath('data.attempts.replacement_attempt_available', true)
            ->assertJsonPath('data.attempts.in_progress_attempt_id', null)
            ->assertJsonPath('data.timing.deadline_at', null)->assertJsonPath('data.timing.remaining_seconds', null);
        $this->assertStringNotContainsString('Device interruption.', $detail->getContent());
        $this->assertStringNotContainsString('reason_type', $detail->getContent());
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk()->assertJsonCount(1, 'data');
        $response = $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertCreated();
        $replacement = AssessmentAttempt::query()->findOrFail($response->json('data.id'));
        $this->assertTrue($replacement->started_at->equalTo(now()->startOfSecond()));
        $this->assertTrue($replacement->deadline_at->equalTo(now()->startOfSecond()->addSeconds(600)));
        $this->assertSame('000000', $replacement->started_at->format('u'));
        $this->assertSame('000000', $replacement->deadline_at->format('u'));
        $this->assertSame($blitzBefore, $assessment->blitzTask->fresh()->getAttributes());
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk()
            ->assertJsonPath('data.attempts.in_progress_attempt_id', $replacement->id)
            ->assertJsonPath('data.attempts.replacement_attempt_available', false)
            ->assertJsonPath('data.timing.remaining_seconds', 600)
            ->assertJsonPath('data.timing.deadline_at', $replacement->deadline_at->format('Y-m-d\TH:i:s\Z'));
        if ($mode === 'synchronized') {
            $this->assertSame(0, app(FinalizeTimedOutBlitzAttempts::class)($student->institution_id, $assessment->id));
        }
        $this->travelTo($replacement->deadline_at);
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk()->assertJsonCount(0, 'data');
        $fresh = $replacement->fresh();
        $this->assertSame('timeout_auto_submit', $fresh->finalization_reason->value);
        $this->assertTrue($fresh->finalized_at->equalTo($replacement->deadline_at));
        $this->assertFalse($normal->fresh()->official_score_eligible);
    }

    public static function replacementWindows(): array
    {
        return [['individual', '2026-09-17T12:00:00.500000Z'], ['individual', '2026-09-17T12:00:00.999999Z'],
            ['synchronized', '2026-09-17T12:00:00.500000Z'], ['synchronized', '2026-09-17T12:00:00.999999Z'],
            ['synchronized', '2026-09-17T12:10:00Z']];
    }

    #[DataProvider('closeInstants')]
    public function test_teacher_close_uses_replacement_deadline_precedence(int $seconds, string $reason): void
    {
        [$student, $assessment, $normal, $teacher, $replacement] = $this->replacementContext('synchronized');
        $before = $normal->getAttributes();
        $this->travelTo($replacement->deadline_at->copy()->addSeconds($seconds));
        app(CloseTeacherBlitz::class)($teacher, $assessment->id);
        $this->assertSame($reason, $replacement->fresh()->finalization_reason->value);
        $this->assertTrue($replacement->fresh()->finalized_at->equalTo($seconds < 0 ? now() : $replacement->deadline_at));
        $this->assertSame($before, $normal->fresh()->getAttributes());
    }

    public static function closeInstants(): array
    {
        return [[-1, 'task_closed_auto_finalize'], [0, 'timeout_auto_submit'], [1, 'timeout_auto_submit']];
    }

    #[DataProvider('submitInstants')]
    public function test_attempt_id_submit_works_for_replacement_and_preserves_original_history(bool $late): void
    {
        [$student, $assessment, $normal, , $replacement] = $this->replacementContext('synchronized');
        $before = $normal->getAttributes();
        $this->travelTo($replacement->deadline_at->copy()->addSeconds($late ? 0 : -1));
        $key = (string) Str::uuid();
        $response = $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$replacement->id.'/submit', key: $key);
        if ($late) {
            $response->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        } else {
            $response->assertOk()->assertJsonPath('data.finalization_reason', 'student_submit');
            $this->travelTo($replacement->deadline_at->copy()->addMinute());
            $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$replacement->id.'/submit', key: $key)
                ->assertOk()->assertJsonPath('data.id', $replacement->id);
        }
        $this->assertSame($before, $normal->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 2);
    }

    public function test_scheduler_ignores_common_end_and_finalizes_only_at_replacement_deadline(): void
    {
        [$student, $assessment, , , $replacement] = $this->replacementContext('synchronized');
        $this->travelTo($assessment->blitzTask->synchronized_ends_at);
        $this->artisan('blitz:reconcile-timeouts')->expectsOutput('Candidates: 0; finalized attempts: 0; failures: 0.')->assertSuccessful();
        $this->assertSame('in_progress', $replacement->fresh()->status->value);
        $this->travelTo($replacement->deadline_at);
        $this->artisan('blitz:reconcile-timeouts')->expectsOutput('Candidates: 1; finalized attempts: 1; failures: 0.')->assertSuccessful();
        $this->assertSame('timeout_auto_submit', $replacement->fresh()->finalization_reason->value);
        $this->assertTrue($replacement->deadline_at->equalTo($replacement->fresh()->finalized_at));
        $this->artisan('blitz:reconcile-timeouts')->expectsOutput('Candidates: 0; finalized attempts: 0; failures: 0.')->assertSuccessful();
    }

    public static function submitInstants(): array
    {
        return [[false], [true]];
    }
}
