<?php

namespace Tests\Feature\Checking;

use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\QuestionTrueFalseAnswer;
use App\Support\Checking\FrozenAttemptCheckQueue;
use Illuminate\Console\Command;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Exceptions;
use Illuminate\Support\Str;
use LogicException;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

/**
 * S09-T1: every freeze is checked right after its transaction commits, without changing
 * the freeze or its response.
 */
class FrozenAttemptCheckTriggerTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
    }

    public function test_an_http_submit_responds_as_before_and_its_attempt_is_checked_afterwards(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'true_false');
        $this->answerRequest($student, $attempt, $question, ['type' => 'true_false', 'value' => true])->assertOk();

        $this->submit($student, $attempt)->assertOk()
            ->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.finalization_reason', 'student_submit');

        $fresh = $attempt->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame('1.00000000', $fresh->earned_points);
        $this->assertSame('12.50000000', $fresh->normalized_score);
        $this->assertSame('auto_checked', AttemptAnswer::query()->sole()->getRawOriginal('checking_status'));
    }

    public function test_a_checking_failure_is_reported_and_leaves_the_freeze_and_response_intact(): void
    {
        Exceptions::fake();
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'true_false');
        $this->answerRequest($student, $attempt, $question, ['type' => 'true_false', 'value' => true])->assertOk();
        // A true/false Question without its key cannot be checked.
        QuestionTrueFalseAnswer::query()->where('question_id', $question->id)->delete();

        $this->submit($student, $attempt)->assertOk()->assertJsonPath('data.status', 'submitted');

        Exceptions::assertReported(LogicException::class);
        $fresh = $attempt->fresh();
        $this->assertSame('submitted', $fresh->getRawOriginal('status'));
        $this->assertSame('student_submit', $fresh->getRawOriginal('finalization_reason'));
        $this->assertSame('pending', AttemptAnswer::query()->sole()->getRawOriginal('checking_status'));
    }

    public function test_a_teacher_homework_close_responds_as_before_and_checks_the_attempt_it_froze(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'true_false');
        $this->answerRequest($student, $attempt, $question, ['type' => 'true_false', 'value' => true])->assertOk();
        $teacher = $homework->assessment->teacher;
        $teacher->update(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $teacher->institution_id, 'group_id' => $homework->assessment->topic->group_id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $teacher->id,
        ]);

        $this->answerHttp($teacher, 'POST', '/api/v1/teacher/homework/'.$homework->assessment_id.'/close')
            ->assertOk()->assertJsonPath('data.status', 'closed');

        $fresh = $attempt->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame('task_closed_auto_finalize', $fresh->getRawOriginal('finalization_reason'));
        $this->assertSame('1.00000000', $fresh->earned_points);
    }

    public function test_a_deadline_reconciling_student_read_checks_the_attempt_it_froze(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'true_false');
        $this->answerRequest($student, $attempt, $question, ['type' => 'true_false', 'value' => true])->assertOk();
        $this->travelTo($homework->deadline_at);

        $this->answerHttp($student, 'GET', '/api/v1/student/homework/'.$homework->assessment_id)->assertOk()
            ->assertJsonPath('data.my_status', 'submitted');

        $fresh = $attempt->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame('homework_deadline_auto_submit', $fresh->getRawOriginal('finalization_reason'));
        $this->assertTrue($fresh->finalized_at->equalTo($homework->deadline_at));
        $this->assertSame('1.00000000', $fresh->earned_points);
    }

    public function test_the_homework_deadline_reconciler_checks_what_it_froze(): void
    {
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $attempt = $this->factoryAttempt($homework->assessment_id);

        $this->artisan('homework:reconcile-deadlines')
            ->expectsOutput('Candidates: 1; finalized attempts: 1; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        $fresh = $attempt->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame('homework_deadline_auto_submit', $fresh->getRawOriginal('finalization_reason'));
        $this->assertTrue($fresh->finalized_at->equalTo($homework->deadline_at));
    }

    public function test_the_blitz_timeout_reconciler_checks_what_it_froze(): void
    {
        $blitz = BlitzTask::factory()->activeIndividual()->create();
        $attempt = $this->factoryAttempt($blitz->assessment_id, ['deadline_at' => now()->subMinute()]);

        $this->artisan('blitz:reconcile-timeouts')
            ->expectsOutput('Candidates: 1; finalized attempts: 1; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        $fresh = $attempt->fresh();
        $this->assertSame('checked', $fresh->getRawOriginal('status'));
        $this->assertSame('timeout_auto_submit', $fresh->getRawOriginal('finalization_reason'));
    }

    public function test_a_reconciler_checking_failure_is_reported_but_not_counted(): void
    {
        Exceptions::fake();
        $homework = HomeworkAssignment::factory()->active()->create(['deadline_at' => now()]);
        $attempt = $this->factoryAttempt($homework->assessment_id, ['possible_points' => '0.000000']);

        $this->artisan('homework:reconcile-deadlines')
            ->expectsOutput('Candidates: 1; finalized attempts: 1; failures: 0.')
            ->assertExitCode(Command::SUCCESS);

        Exceptions::assertReported(LogicException::class);
        $this->assertSame('submitted', $attempt->fresh()->getRawOriginal('status'));
    }

    public function test_the_queue_checks_a_recorded_id_once_and_ignores_rolled_back_or_unfrozen_ids(): void
    {
        $frozen = $this->submittedFactoryAttempt(HomeworkAssignment::factory()->closed()->create()->assessment_id);
        $inProgress = $this->factoryAttempt(HomeworkAssignment::factory()->active()->create()->assessment_id);
        $queue = app(FrozenAttemptCheckQueue::class);

        $queue->add($frozen->id);
        $queue->add($frozen->id);
        $queue->add($inProgress->id);
        $queue->add((string) Str::uuid());
        $queue->drain();
        $checkedOnce = $frozen->fresh()->getAttributes();
        $queue->drain();

        $this->assertSame('checked', $checkedOnce['status']);
        $this->assertSame($checkedOnce, $frozen->fresh()->getAttributes());
        $this->assertSame('in_progress', $inProgress->fresh()->getRawOriginal('status'));
    }

    public function test_one_failing_attempt_does_not_stop_the_rest_of_a_drain(): void
    {
        Exceptions::fake();
        $assessmentId = HomeworkAssignment::factory()->closed()->create()->assessment_id;
        // A zero possible-points snapshot cannot be normalized.
        $broken = $this->submittedFactoryAttempt($assessmentId, ['possible_points' => '0.000000']);
        $healthy = $this->submittedFactoryAttempt($assessmentId);
        $queue = app(FrozenAttemptCheckQueue::class);

        $queue->add($broken->id);
        $queue->add($healthy->id);
        $queue->drain();

        Exceptions::assertReported(LogicException::class);
        $this->assertSame('submitted', $broken->fresh()->getRawOriginal('status'));
        $this->assertSame('checked', $healthy->fresh()->getRawOriginal('status'));
    }

    private function submit($student, AssessmentAttempt $attempt)
    {
        return $this->answerHttp($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', headers: [
            'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
        ]);
    }

    /** @param array<string, mixed> $attributes */
    private function factoryAttempt(string $assessmentId, array $attributes = []): AssessmentAttempt
    {
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $assessmentId]);

        return AssessmentAttempt::factory()->create(array_merge([
            'assessment_student_id' => $recipient,
            'started_at' => now()->subHour(),
            'possible_points' => '4.000000',
        ], $attributes))->fresh();
    }

    /** @param array<string, mixed> $attributes */
    private function submittedFactoryAttempt(string $assessmentId, array $attributes = []): AssessmentAttempt
    {
        $attempt = $this->factoryAttempt($assessmentId, $attributes);
        DB::table('assessment_attempts')->where('id', $attempt->id)->update([
            'status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit',
        ]);

        return $attempt->fresh();
    }
}
