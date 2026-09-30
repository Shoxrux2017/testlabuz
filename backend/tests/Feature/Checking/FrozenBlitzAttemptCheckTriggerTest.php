<?php

namespace Tests\Feature\Checking;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\QuestionChoiceOption;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\TestCase;

/**
 * S09-T1: every Blitz freeze is checked right after its transaction commits, without
 * changing the freeze or its response.
 */
class FrozenBlitzAttemptCheckTriggerTest extends TestCase
{
    use BuildsBlitzExceptionContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_a_blitz_submit_responds_as_before_and_its_attempt_is_checked_afterwards(): void
    {
        [$student, $assessment, $attempt] = $this->exceptionContext(terminal: false);
        $this->answerCorrectChoice($student, $assessment, $attempt);

        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')->assertOk()
            ->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.finalization_reason', 'student_submit');

        $this->assertCheckedWithChoicePoints($attempt, 'student_submit');
    }

    public function test_a_blitz_close_responds_as_before_and_checks_the_attempt_it_froze(): void
    {
        [$student, $assessment, $attempt, $teacher] = $this->exceptionContext(terminal: false);
        $this->answerCorrectChoice($student, $assessment, $attempt);

        $this->studentBlitzRequest($teacher, 'POST', '/api/v1/teacher/blitz/'.$assessment->id.'/close', '{}', null)
            ->assertOk()->assertJsonPath('data.status', 'closed');

        $this->assertCheckedWithChoicePoints($attempt, 'task_closed_auto_finalize');
    }

    public function test_an_exception_grant_checks_the_normal_attempt_it_timed_out_and_keeps_it_ineligible(): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext('synchronized', false);
        $this->answerCorrectChoice($student, $assessment, $normal);
        $this->travelTo($normal->deadline_at);

        $this->grantException($teacher, $assessment, $student)->assertCreated();

        $this->assertCheckedWithChoicePoints($normal, 'timeout_auto_submit');
        $this->assertTrue($normal->fresh()->finalized_at->equalTo($normal->deadline_at));
        $this->assertFalse($normal->fresh()->official_score_eligible);
    }

    public function test_the_sweep_checks_an_invalidated_normal_attempt_without_touching_its_running_replacement(): void
    {
        [, , $normal, , $replacement] = $this->replacementContext();
        $replacementBefore = $replacement->fresh()->getAttributes();
        $this->assertSame('submitted', $normal->getRawOriginal('status'));
        $this->assertFalse($normal->official_score_eligible);

        $this->artisan('attempts:check-frozen')
            ->expectsOutput('Candidates: 1; checked attempts: 1; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        $fresh = $normal->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame('0.00000000', $fresh->earned_points);
        $this->assertFalse($fresh->official_score_eligible);
        $this->assertSame($replacementBefore, $replacement->fresh()->getAttributes());
    }

    private function answerCorrectChoice(User $student, Assessment $assessment, AssessmentAttempt $attempt): void
    {
        [$choice] = $this->studentBlitzQuestions($assessment);
        $correct = QuestionChoiceOption::query()->where('question_id', $choice->id)->where('is_correct', true)->sole();

        $this->studentBlitzRequest($student, 'PUT', '/api/v1/student/attempts/'.$attempt->id.'/answers/'.$choice->id,
            json_encode(['type' => 'single_choice', 'selected_option_ids' => [$correct->id]], JSON_THROW_ON_ERROR), null)
            ->assertOk();
    }

    // The correct 3-point choice of the 5-point Blitz is checked automatically; the unanswered file adds nothing.
    private function assertCheckedWithChoicePoints(AssessmentAttempt $attempt, string $reason): void
    {
        $fresh = $attempt->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame($reason, $fresh->getRawOriginal('finalization_reason'));
        $this->assertSame('3.00000000', $fresh->earned_points);
        $this->assertSame('60.00000000', $fresh->normalized_score);
    }
}
