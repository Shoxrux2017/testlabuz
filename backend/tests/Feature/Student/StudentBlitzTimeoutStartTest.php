<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Models\GroupTeacherMembership;
use App\Models\IdempotencyRecord;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzTimeoutStartTest extends TestCase
{
    use BuildsStudentBlitzContext, BuildsStudentHomeworkFileAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
        config(['filesystems.private_files_disk' => 'local']);
    }

    public function test_new_synchronized_start_at_common_end_creates_neither_attempt_nor_claim(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, 'synchronized');
        $this->travelTo($assessment->blitzTask->synchronized_ends_at);

        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('dueRequests')]
    public function test_new_start_or_resume_key_reconciles_due_attempt_without_retaining_the_failed_claim(string $mode, string $intent): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $this->startStudentBlitz($student, $assessment)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $claimBefore = IdempotencyRecord::query()->sole()->getAttributes();
        $key = (string) Str::uuid();
        $this->travelTo($attempt->deadline_at);

        $this->startStudentBlitz($student, $assessment, $key, $intent, $intent === 'resume' ? $attempt->id : null)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $current = $attempt->fresh();
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $current->status);
        $this->assertTrue($attempt->deadline_at->equalTo($current->finalized_at));
        $this->assertTrue($attempt->deadline_at->equalTo($current->locked_at));
        $this->assertNull($current->submitted_at);
        $this->assertSame($claimBefore, IdempotencyRecord::query()->sole()->getAttributes());
        $this->assertDatabaseMissing('idempotency_records', ['idempotency_key' => $key]);
        $frozen = $current->getAttributes();

        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id)
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $this->assertSame($frozen, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    #[DataProvider('completedReplays')]
    public function test_completed_start_replay_reconciles_then_returns_original_http_status_and_frozen_answer_state(string $mode, int $originalStatus): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $textQuestion = $this->answerQuestion($assessment->blitzTask, 'short_written');
        $fileQuestion = $this->answerQuestion($assessment->blitzTask, 'file_based', 2);
        $this->answerQuestion($assessment->blitzTask, 'open_written', 3);
        $key = (string) Str::uuid();
        $started = $this->startStudentBlitz($student, $assessment, $key)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $textState = $this->answerRequest($student, $attempt, $textQuestion,
            ['type' => 'short_written', 'text' => "  Exact frozen text\n"])->assertOk()->json('data');
        $fileState = $this->fileAnswerRequest($student, $attempt, $fileQuestion, $this->fileAnswerUpload())
            ->assertOk()->json('data');
        $intent = $originalStatus === 200 ? 'resume' : 'start_normal';
        $target = $originalStatus === 200 ? $attempt->id : null;
        if ($originalStatus === 200) {
            $key = (string) Str::uuid();
            $this->startStudentBlitz($student, $assessment, $key, $intent, $target)->assertOk();
        }
        $claimsBefore = IdempotencyRecord::query()->orderBy('id')->get()->map->getAttributes()->all();
        $answersBefore = $this->fileAnswerSnapshot();
        $this->travelTo($attempt->deadline_at->copy()->addMinutes(3));

        $response = $this->startStudentBlitz($student, $assessment, $key, $intent, $target)
            ->assertStatus($originalStatus)->assertJsonPath('data.id', $attempt->id)
            ->assertJsonPath('data.status', 'timed_out_finalized')
            ->assertJsonPath('data.started_at', $started->json('data.started_at'))
            ->assertJsonPath('data.deadline_at', $started->json('data.deadline_at'))
            ->assertJsonPath('data.submitted_at', null)
            ->assertJsonPath('data.finalized_at', $started->json('data.deadline_at'))
            ->assertJsonPath('data.finalization_reason', 'timeout_auto_submit')
            ->assertJsonPath('data.timing.remaining_seconds', 0)
            ->assertJsonPath('data.answers', [$textState, $fileState]);

        $this->assertNoAnswerSecrets($response->json('data'));
        $this->assertNoFileAnswerSecrets($response->json('data'));
        $this->assertSame($answersBefore, $this->fileAnswerSnapshot());
        $this->assertSame($claimsBefore, IdempotencyRecord::query()->orderBy('id')->get()->map->getAttributes()->all());
        $frozen = $attempt->fresh()->getAttributes();
        $this->travel(1)->minutes();
        $this->startStudentBlitz($student, $assessment, $key, $intent, $target)->assertStatus($originalStatus)
            ->assertJsonPath('data.status', 'timed_out_finalized')->assertJsonPath('data.timing.remaining_seconds', 0);
        $this->assertSame($frozen, $attempt->fresh()->getAttributes());
        $this->assertSame($claimsBefore, IdempotencyRecord::query()->orderBy('id')->get()->map->getAttributes()->all());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('attempt_answers', 2);
        $this->assertDatabaseCount('files', 1);
    }

    public static function dueRequests(): array
    {
        return [['individual', 'start_normal'], ['individual', 'resume'], ['synchronized', 'start_normal'], ['synchronized', 'resume']];
    }

    #[DataProvider('completedReplays')]
    public function test_completed_start_replays_teacher_closed_attempt_before_deadline_without_changing_timer_or_claim(string $mode, int $originalStatus): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $teacher = $assessment->teacher;
        $teacher->update(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $student->institution_id, 'group_id' => $assessment->topic->group_id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $teacher->id,
        ]);
        $key = (string) Str::uuid();
        $started = $this->startStudentBlitz($student, $assessment, $key)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $intent = $originalStatus === 200 ? 'resume' : 'start_normal';
        $target = $originalStatus === 200 ? $attempt->id : null;
        if ($originalStatus === 200) {
            $key = (string) Str::uuid();
            $this->startStudentBlitz($student, $assessment, $key, $intent, $target)->assertOk();
        }
        $claimsBefore = IdempotencyRecord::query()->orderBy('id')->get()->map->getAttributes()->all();
        $this->travel(1)->minutes();
        $closedAt = now()->format('Y-m-d\TH:i:s\Z');
        $this->blitzRaw($teacher, 'POST', '/api/v1/teacher/blitz/'.$assessment->id.'/close')->assertOk();
        $frozen = $attempt->fresh()->getAttributes();
        $this->travel(1)->minutes();

        $this->startStudentBlitz($student, $assessment, $key, $intent, $target)->assertStatus($originalStatus)
            ->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.submitted_at', null)->assertJsonPath('data.finalized_at', $closedAt)
            ->assertJsonPath('data.finalization_reason', 'task_closed_auto_finalize')
            ->assertJsonPath('data.started_at', $started->json('data.started_at'))
            ->assertJsonPath('data.deadline_at', $started->json('data.deadline_at'))
            ->assertJsonPath('data.timing.remaining_seconds', 0);

        $this->assertSame($claimsBefore, IdempotencyRecord::query()->orderBy('id')->get()->map->getAttributes()->all());
        $this->assertSame($frozen, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('attempt_answers', 0);
    }

    public static function completedReplays(): array
    {
        return [['individual', 200], ['individual', 201], ['synchronized', 200], ['synchronized', 201]];
    }
}
