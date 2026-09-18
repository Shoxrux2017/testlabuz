<?php

namespace Tests\Feature\Student;

use App\Actions\Student\ShowStudentBlitzAttempt;
use App\Enums\IdempotencyOperation;
use App\Http\Resources\Student\StudentBlitzAttemptResource;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\IdempotencyRecord;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use App\Support\Student\StudentBlitzHistoricalAnswerReadProof;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzHistoricalReplayContext;
use Tests\TestCase;

class StudentBlitzAttemptStartHistoricalReplayTest extends TestCase
{
    use BuildsStudentBlitzHistoricalReplayContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
    }

    #[DataProvider('publicReplayHistories')]
    public function test_completed_normal_and_resume_replays_keep_original_result_and_each_valid_terminal_lineage(string $intent, string $status, string $reason): void
    {
        [$student, $assessment, $attempt, $key, $typed, $fileAnswer, $file] = $this->historicalReplayContext();
        $httpStatus = 201;
        $resumeId = null;
        if ($intent === 'resume') {
            $key = (string) Str::uuid();
            $resumeId = $attempt->id;
            $this->startStudentBlitz($student, $assessment, $key, $intent, $resumeId)->assertOk();
            $httpStatus = 200;
        }
        $this->advanceHistoricalReplay($attempt, $status, $reason, $typed, $fileAnswer);
        $before = $this->historicalReplaySnapshot();
        $this->travel(1)->hours();
        $response = $this->startStudentBlitz($student, $assessment, $key, $intent, $resumeId)
            ->assertStatus($httpStatus)->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.status', $status)
            ->assertJsonPath('data.finalization_reason', $reason)->assertJsonPath('data.answers.0.answer.value', true)
            ->assertJsonPath('data.answers.1.answer.file.id', $file->id)
            ->assertJsonPath('message', $httpStatus === 201 ? 'Blitz attempt started successfully.' : 'Blitz attempt resumed successfully.');
        $this->assertHistoricalReplayPrivacy($response->json());
        $this->assertSame($before, $this->historicalReplaySnapshot());
        $this->startStudentBlitz($student, $assessment, $key, $intent === 'resume' ? 'start_normal' : 'resume', $intent === 'resume' ? null : $attempt->id)
            ->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->startStudentBlitz($student, $assessment, $key, 'resume', (string) Str::uuid())
            ->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $otherBlitz = $this->studentBlitz($student);
        $this->startStudentBlitz($student, $otherBlitz, $key, $intent, $resumeId)
            ->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
    }

    public static function publicReplayHistories(): array
    {
        return [
            ['start_normal', 'waiting_for_teacher_review', 'student_submit'],
            ['start_normal', 'checked', 'timeout_auto_submit'],
            ['start_normal', 'checked', 'task_closed_auto_finalize'],
            ['resume', 'checked', 'student_submit'],
            ['resume', 'waiting_for_teacher_review', 'timeout_auto_submit'],
            ['resume', 'waiting_for_teacher_review', 'task_closed_auto_finalize'],
        ];
    }

    #[DataProvider('replacementReplayIntents')]
    public function test_replacement_and_resume_number_two_proof_and_public_replay_preserve_exact_identity(string $intent, string $status): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $original = $this->studentBlitzAttempt($assessment, $student, ['official_score_eligible' => false]);
        $this->terminateStudentBlitzAttempt($original);
        $replacement = $this->studentBlitzAttempt($assessment, $student, ['attempt_number' => 2]);
        BlitzAttemptException::factory()->create(['assessment_id' => $assessment->id, 'assessment_student_id' => $replacement->assessment_student_id,
            'invalidated_attempt_id' => $original->id, 'replacement_attempt_id' => $replacement->id]);
        [$typed, $fileAnswer, $file] = $this->historicalReplayAnswers($replacement, $assessment);
        $this->advanceHistoricalReplay($replacement, $status, 'student_submit', $typed, $fileAnswer);
        $key = (string) Str::uuid();
        $resumeId = $intent === 'resume' ? $replacement->id : null;
        $body = ['intent' => $intent] + ($resumeId === null ? [] : ['attempt_id' => $resumeId]);
        $fingerprint = app(IdempotencyRequestFingerprint::class)->make($student, IdempotencyOperation::StudentBlitzAttemptStart, ['blitz_id' => $assessment->id], $body);
        $record = IdempotencyRecord::query()->create(['institution_id' => $student->institution_id, 'user_id' => $student->id,
            'operation' => IdempotencyOperation::StudentBlitzAttemptStart, 'idempotency_key' => $key, 'request_fingerprint' => $fingerprint,
            'result_resource_type' => 'assessment_attempt', 'result_resource_id' => $replacement->id,
            'response_status' => $intent === 'resume' ? 200 : 201, 'completed_at' => now()]);
        $before = $this->historicalReplaySnapshot();
        $proof = StudentBlitzHistoricalAnswerReadProof::forStart($student, $assessment, $replacement, $record, $key, $fingerprint, $intent, $resumeId);
        $shown = app(ShowStudentBlitzAttempt::class)($student, $assessment, BlitzTask::query()->findOrFail($assessment->id), $replacement, now(), $proof);
        $payload = (new StudentBlitzAttemptResource($shown))->response()->getData(true);
        $this->assertSame($replacement->id, $payload['data']['id']);
        $this->assertSame(2, $payload['data']['attempt_number']);
        $this->assertSame(true, $payload['data']['answers'][0]['answer']['value']);
        $this->assertSame($file->id, $payload['data']['answers'][1]['answer']['file']['id']);
        $this->assertSame($record->response_status, $proof->completedResponseStatus);
        $this->assertSame($intent, $proof->startIntent);
        $this->assertSame($resumeId, $proof->resumeAttemptId);
        $this->assertHistoricalReplayPrivacy($payload);
        $this->assertSame($before, $this->historicalReplaySnapshot());
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertDatabaseCount('blitz_attempt_exceptions', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->startStudentBlitz($student, $assessment, $key, $intent, $resumeId)->assertStatus($record->response_status)
            ->assertJsonPath('data.id', $replacement->id)->assertJsonPath('data.status', $status)
            ->assertJsonPath('data.answers.1.answer.file.id', $file->id);
        $this->assertSame($before, $this->historicalReplaySnapshot());
        if ($intent === 'resume') {
            $this->startStudentBlitz($student, $assessment, $key, 'start_replacement')
                ->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        }
        foreach ([['resume', $original->id], ['start_normal', null], ['resume', $replacement->id === $resumeId ? $original->id : $replacement->id]] as [$changedIntent, $changedTarget]) {
            try {
                StudentBlitzHistoricalAnswerReadProof::forStart($student, $assessment, $replacement, $record, $key, $fingerprint, $changedIntent, $changedTarget);
                $this->fail('A changed body must never construct a historical replay proof.');
            } catch (LogicException) {
                $this->assertSame($before, $this->historicalReplaySnapshot());
            }
        }
    }

    public static function replacementReplayIntents(): array
    {
        return [['start_replacement', 'waiting_for_teacher_review'], ['resume', 'checked']];
    }

    #[DataProvider('corruptLineages')]
    public function test_corrupt_or_mixed_terminal_lineage_is_never_repaired(array $changes): void
    {
        [$student, $assessment, $attempt, $key, $typed, $fileAnswer] = $this->historicalReplayContext();
        $this->advanceHistoricalReplay($attempt, 'checked', 'student_submit', $typed, $fileAnswer);
        $attempt->update($changes);
        $before = $this->historicalReplaySnapshot();
        $this->withoutExceptionHandling();
        try {
            $this->startStudentBlitz($student, $assessment, $key);
            $this->fail('Mixed execution history must fail.');
        } catch (LogicException) {
            $this->assertSame($before, $this->historicalReplaySnapshot());
        }
    }

    public static function corruptLineages(): array
    {
        return [[['finalization_reason' => 'timeout_auto_submit']], [['finalization_reason' => 'task_closed_auto_finalize']],
            [['finalized_at' => '2026-09-17 12:00:02']], [['locked_at' => null]],
            [['submitted_at' => null]], [['finalization_reason' => null]],
            [['submitted_at' => '2026-09-17 12:10:00', 'finalized_at' => '2026-09-17 12:10:00', 'locked_at' => '2026-09-17 12:10:00']]];
    }

    public function test_historical_start_replay_keeps_current_authorization_and_exact_referenced_recipient(): void
    {
        [$student, $assessment, $attempt, $key, $typed, $fileAnswer] = $this->historicalReplayContext();
        $this->advanceHistoricalReplay($attempt, 'checked', 'student_submit', $typed, $fileAnswer);
        foreach ([$this->studentBlitzActor($student->institution), $this->studentBlitzActor()] as $other) {
            $this->startStudentBlitz($other, $assessment, $key)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $other = $this->studentBlitzActor($student->institution);
        $otherAttempt = $this->studentBlitzAttempt($assessment, $other);
        $attempt->update(['assessment_student_id' => $otherAttempt->assessment_student_id]);
        $before = $this->historicalReplaySnapshot();
        $this->startStudentBlitz($student, $assessment, $key)->assertStatus(500);
        $this->assertSame($before, $this->historicalReplaySnapshot());
        $attempt->update(['assessment_student_id' => $assessment->recipients()->where('student_id', $student->id)->sole()->id]);
        IdempotencyRecord::query()->where('idempotency_key', $key)->update(['result_resource_id' => $otherAttempt->id]);
        $before = $this->historicalReplaySnapshot();
        $this->startStudentBlitz($student, $assessment, $key)->assertStatus(500);
        $this->assertSame($before, $this->historicalReplaySnapshot());
    }

    public function test_new_keys_and_client_projection_flags_cannot_enable_historical_mode(): void
    {
        [$student, $assessment, $attempt, , $typed, $fileAnswer] = $this->historicalReplayContext();
        $this->advanceHistoricalReplay($attempt, 'checked', 'student_submit', $typed, $fileAnswer);
        $before = $this->historicalReplaySnapshot();
        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'attempts_exhausted');
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id)
            ->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/blitz/'.$assessment->id.'/attempts', '{"intent":"start_normal","historical_read":true}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/blitz/'.$assessment->id.'/attempts?historical_read=true', '{"intent":"start_normal"}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $this->historicalReplaySnapshot());
    }
}
