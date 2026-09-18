<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\TestCase;

class StudentBlitzTimeoutReadReconciliationTest extends TestCase
{
    use BuildsStudentBlitzAnswerContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_active_list_reconciles_the_due_aggregate_and_projects_only_future_own_work(): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $otherDue = $this->studentBlitzAttempt($blitz->assessment, $this->studentBlitzActor($student->institution), [
            'started_at' => now()->subMinutes(2), 'deadline_at' => now()->addMinutes(8),
        ]);
        $otherFuture = $this->studentBlitzAttempt($blitz->assessment, $this->studentBlitzActor($student->institution), [
            'started_at' => now(), 'deadline_at' => now()->addMinutes(10),
        ]);
        $futureAssessment = $this->studentBlitz($student);
        $futureAttempt = $this->studentBlitzAttempt($futureAssessment, $student, [
            'started_at' => now(), 'deadline_at' => now()->addMinutes(10),
        ]);
        $privateStudent = $this->studentBlitzActor($student->institution);
        $privateAttempt = $this->studentBlitzAttempt($this->studentBlitz($privateStudent), $privateStudent);
        $foreignStudent = $this->studentBlitzActor();
        $foreignAttempt = $this->studentBlitzAttempt($this->studentBlitz($foreignStudent), $foreignStudent);
        $preserved = collect([$otherFuture, $futureAttempt, $privateAttempt, $foreignAttempt])
            ->mapWithKeys(fn (AssessmentAttempt $row): array => [$row->id => $row->getAttributes()])->all();
        $this->travelTo($attempt->deadline_at);

        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/active')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $futureAssessment->id)
            ->assertJsonPath('data.0.attempts.in_progress_attempt_id', $futureAttempt->id)
            ->assertJsonPath('data.0.timing.remaining_seconds', 60);

        foreach ([$attempt, $otherDue] as $due) {
            $this->assertTimeoutAtPersistedDeadline($due);
        }
        foreach ($preserved as $id => $attributes) {
            $this->assertSame($attributes, AssessmentAttempt::query()->findOrFail($id)->getAttributes());
        }
        $this->assertSame(BlitzStatus::Active, $blitz->fresh()->status);
        $this->assertDatabaseCount('assessment_attempts', 6);
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('expiredDetails')]
    public function test_detail_finalizes_exact_deadline_and_preserves_saved_answers_without_scoring(string $mode, int $delay): void
    {
        [$student, $blitz, $attempt] = $this->answerContext($mode);
        $question = $this->answerQuestion($blitz, 'short_written');
        $this->answerQuestion($blitz, 'open_written', 2);
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => "  Frozen answer\n"])->assertOk();
        $answerBefore = $this->answerSnapshot();
        $attemptBefore = $attempt->getAttributes();
        $this->travelTo($attempt->deadline_at->copy()->addSeconds($delay));

        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$blitz->assessment_id)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $this->assertTimeoutAtPersistedDeadline($attempt);
        $this->assertSame($answerBefore, $this->answerSnapshot());
        foreach (['started_at', 'deadline_at', 'attempt_number', 'assessment_student_id', 'student_id',
            'official_score_eligible', 'possible_points', 'earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertSame($attemptBefore[$field], $attempt->fresh()->getAttributes()[$field], $field);
        }
        $answer = AttemptAnswer::query()->sole();
        $this->assertSame('pending', $answer->checking_status->value);
        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
            $this->assertNull($answer->{$field});
        }
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('attempt_answers', 1);
    }

    public static function expiredDetails(): array
    {
        return [['individual', 0], ['individual', 180], ['synchronized', 0], ['synchronized', 180]];
    }

    private function assertTimeoutAtPersistedDeadline(AssessmentAttempt $attempt): void
    {
        $current = $attempt->fresh();
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $current->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::TimeoutAutoSubmit, $current->finalization_reason);
        $this->assertNull($current->submitted_at);
        $this->assertTrue($current->deadline_at->equalTo($current->finalized_at));
        $this->assertTrue($current->deadline_at->equalTo($current->locked_at));
    }
}
