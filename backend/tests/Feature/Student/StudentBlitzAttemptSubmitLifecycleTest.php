<?php

namespace Tests\Feature\Student;

use App\Actions\Blitz\FinalizeTimedOutBlitzAttempts;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\TopicStatus;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzAttemptSubmitLifecycleTest extends TestCase
{
    use BuildsStudentBlitzAnswerContext, BuildsStudentHomeworkFileAnswerContext, RefreshDatabase {
        BuildsStudentBlitzAnswerContext::answerContext insteadof BuildsStudentHomeworkFileAnswerContext;
    }

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
    }

    #[DataProvider('timerModes')]
    public function test_the_last_second_before_persisted_deadline_allows_explicit_submit(string $mode): void
    {
        [$student, , $attempt] = $this->answerContext($mode);
        $deadline = $attempt->getRawOriginal('deadline_at');
        $this->travelTo($attempt->deadline_at->copy()->subSecond());
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')
            ->assertOk()->assertJsonPath('data.status', 'submitted')->assertJsonPath('data.finalization_reason', 'student_submit');
        $fresh = $attempt->fresh();
        $this->assertSame($deadline, $fresh->getRawOriginal('deadline_at'));
        foreach (['submitted_at', 'finalized_at', 'locked_at'] as $field) {
            $this->assertTrue($fresh->getAttribute($field)->equalTo(now()));
            $this->assertTrue($fresh->getAttribute($field)->lt($fresh->deadline_at));
        }
    }

    public static function timerModes(): array
    {
        return [['individual'], ['synchronized']];
    }

    #[DataProvider('dueRequests')]
    public function test_exact_deadline_and_late_submit_reconcile_due_attempts_and_preserve_saved_answers_without_a_claim(string $mode, int $offset): void
    {
        [$student, $blitz, $attempt] = $this->answerContext($mode);
        $question = $this->answerQuestion($blitz, 'open_written');
        $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        [, , $file] = $this->savedFileAnswer($attempt, $this->answerQuestion($blitz, 'file_based', 2));
        $otherStudent = $this->studentBlitzActor($student->institution);
        $this->studentBlitzAttempt($blitz->assessment, $otherStudent);
        $attemptsBefore = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $answersBefore = $this->fileAnswerSnapshot();
        $bytesBefore = Storage::disk('local')->get($file->storage_key);
        $blitzBefore = $blitz->getAttributes();
        $this->travelTo($attempt->deadline_at->copy()->addSeconds($offset));
        $key = (string) Str::uuid();

        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', key: $key)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $transition = array_flip(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at']);
        foreach (AssessmentAttempt::query()->orderBy('id')->get() as $index => $finalized) {
            $this->assertSame(array_diff_key($attemptsBefore[$index], $transition), array_diff_key($finalized->getAttributes(), $transition));
            $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $finalized->status);
            $this->assertSame(AssessmentAttemptFinalizationReason::TimeoutAutoSubmit, $finalized->finalization_reason);
            $this->assertNull($finalized->submitted_at);
            $this->assertTrue($finalized->deadline_at->equalTo($finalized->finalized_at));
            $this->assertTrue($finalized->deadline_at->equalTo($finalized->locked_at));
        }
        $this->assertSame($answersBefore, $this->fileAnswerSnapshot());
        $this->assertSame($bytesBefore, Storage::disk('local')->get($file->storage_key));
        $this->assertSame($blitzBefore, $blitz->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
        $frozen = $attempt->fresh()->getAttributes();
        $this->travel(1)->minutes();
        foreach ([$key, (string) Str::uuid()] as $retryKey) {
            $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', key: $retryKey)
                ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
            $this->assertSame($frozen, $attempt->fresh()->getAttributes());
            $this->assertDatabaseCount('idempotency_records', 0);
        }
    }

    public static function dueRequests(): array
    {
        return [['individual', 0], ['individual', 1], ['synchronized', 0], ['synchronized', 1]];
    }

    #[DataProvider('terminalAttempts')]
    public function test_terminal_new_key_precedes_parent_lifecycle_and_due_time_without_rewriting_execution(string $status, string $reason, string $expectedCode): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $finalizedAt = $reason === 'timeout_auto_submit' ? $attempt->deadline_at : now();
        $attempt->update([
            'status' => $status, 'finalization_reason' => $reason,
            'submitted_at' => $reason === 'student_submit' ? $finalizedAt : null,
            'finalized_at' => $finalizedAt, 'locked_at' => $finalizedAt,
        ]);
        $blitz->update(['status' => 'archived', 'closed_at' => now(), 'archived_at' => now()]);
        $blitz->assessment->topic->update(['status' => TopicStatus::Closed, 'closed_at' => now()]);
        $before = $attempt->fresh()->getAttributes();
        $this->travelTo($attempt->deadline_at->copy()->addMinute());

        $response = $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')
            ->assertConflict()->assertJsonPath('code', $expectedCode);

        $this->assertStringNotContainsString('submission_locked', $response->getContent());
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function terminalAttempts(): array
    {
        $cases = [['timed_out_finalized', 'timeout_auto_submit', 'blitz_time_expired']];
        foreach (['submitted', 'waiting_for_teacher_review', 'checked'] as $status) {
            foreach (['student_submit', 'task_closed_auto_finalize'] as $reason) {
                $cases[] = [$status, $reason, 'attempt_not_editable'];
            }
        }
        foreach (['waiting_for_teacher_review', 'checked'] as $status) {
            $cases[] = [$status, 'timeout_auto_submit', 'attempt_not_editable'];
        }

        return $cases;
    }

    #[DataProvider('inactiveStates')]
    public function test_in_progress_attempt_under_non_active_parent_returns_blitz_not_active_before_due_reconciliation(string $state): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        if ($state === 'topic') {
            $blitz->assessment->topic->update(['status' => TopicStatus::Closed, 'closed_at' => now()]);
        } else {
            $blitz->update(match ($state) {
                'closed' => ['status' => 'closed', 'closed_at' => now()],
                'archived' => ['status' => 'archived', 'closed_at' => now(), 'archived_at' => now()],
                'draft', 'scheduled' => ['status' => $state, 'activated_at' => null, 'activated_by_user_id' => null,
                    'timer_start_mode_snapshot' => null, 'synchronized_ends_at' => null,
                    'scheduled_at' => $state === 'scheduled' ? now()->addHour() : null],
            });
        }
        $before = $attempt->getAttributes();
        $this->travelTo($attempt->deadline_at);
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')
            ->assertConflict()->assertJsonPath('code', 'blitz_not_active');
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function inactiveStates(): array
    {
        return array_map(fn (string $state): array => [$state], ['topic', 'draft', 'scheduled', 'closed', 'archived']);
    }

    #[DataProvider('savedAnswerCorruption')]
    public function test_invalid_saved_execution_answers_abort_submit_without_repair_or_claim(string $corruption): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($blitz, 'open_written');
        $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        $answer = AttemptAnswer::query()->where('question_id', $question->id)->sole();
        [, , $file] = $this->savedFileAnswer($attempt, $this->answerQuestion($blitz, 'file_based', 2));
        if ($corruption === 'file integrity') {
            DB::table('files')->where('id', $file->id)->update(['checksum_sha256' => null]);
        } elseif ($corruption === 'foreign question') {
            $otherAssessment = $this->studentBlitz($student);
            $question->update(['assessment_id' => $otherAssessment->id]);
        } else {
            DB::table('attempt_answers')->where('id', $answer->id)->update(match ($corruption) {
                'checking state' => ['checking_status' => 'waiting_for_teacher_review'],
                'feedback' => ['feedback' => 'Later checking feedback'],
                'awarded points' => ['awarded_points' => '1.000000'],
                'checked actor' => ['checked_by_user_id' => $blitz->assessment->teacher_id],
                'checked time' => ['checked_at' => now()],
            });
        }
        $before = [$attempt->getAttributes(), $this->fileAnswerSnapshot(), Storage::disk('local')->get($file->storage_key)];
        $response = $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')
            ->assertStatus(500)->assertJsonPath('code', 'server_error');
        foreach (['LogicException', 'SQLSTATE', 'checksum_sha256', 'Later checking feedback', $attempt->id] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $this->fileAnswerSnapshot(), Storage::disk('local')->get($file->storage_key)]);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function savedAnswerCorruption(): array
    {
        return array_map(fn (string $state): array => [$state], ['checking state', 'feedback', 'awarded points', 'checked actor', 'checked time', 'file integrity', 'foreign question']);
    }

    public function test_timeout_finalized_by_delivered_reconciler_remains_expired_with_a_new_submit_key(): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $this->travelTo($attempt->deadline_at);
        app(FinalizeTimedOutBlitzAttempts::class)($student->institution_id, $blitz->assessment_id);
        $before = $attempt->fresh()->getAttributes();
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
    }
}
