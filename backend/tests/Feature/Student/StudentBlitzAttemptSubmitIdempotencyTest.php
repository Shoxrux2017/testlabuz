<?php

namespace Tests\Feature\Student;

use App\Actions\Student\SubmitStudentBlitzAttempt;
use App\Actions\Teacher\ArchiveTeacherBlitz;
use App\Actions\Teacher\CloseTeacherBlitz;
use App\Enums\IdempotencyOperation;
use App\Models\AssessmentAttempt;
use App\Models\GroupTeacherMembership;
use App\Models\IdempotencyRecord;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzAttemptSubmitIdempotencyTest extends TestCase
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

    public function test_success_records_exact_canonical_fingerprint_and_replays_same_logical_result_without_domain_churn(): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $first = $this->submit($student, $attempt, strtoupper($key), '{}')->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $before = [$attempt->fresh()->getAttributes(), $record->getAttributes(), $this->fileAnswerSnapshot()];
        $this->travel(1)->minutes();

        $replay = $this->submit($student, $attempt, $key)->assertOk()
            ->assertJsonPath('message', 'Blitz attempt submitted successfully.')
            ->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.timing.remaining_seconds', 0);

        $firstJson = $first->json();
        $replayJson = $replay->json();
        unset($firstJson['data']['timing']['server_now'], $replayJson['data']['timing']['server_now']);
        $this->assertSame($firstJson, $replayJson);
        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->fileAnswerSnapshot()]);
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->submit($student, $attempt, (string) Str::uuid())->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    #[DataProvider('laterLifecycleChanges')]
    public function test_replay_after_teacher_close_archive_or_deadline_preserves_original_success(string $change): void
    {
        [$student, $blitz, $attempt] = $this->savedAnswerContext();
        $teacher = $blitz->assessment->teacher;
        GroupTeacherMembership::factory()->create([
            'institution_id' => $student->institution_id, 'group_id' => $blitz->assessment->topic->group_id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $teacher->id,
        ]);
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $before = [$attempt->fresh()->getAttributes(), $record->getAttributes(), $this->fileAnswerSnapshot()];
        if ($change === 'deadline') {
            $this->travelTo($attempt->deadline_at->copy()->addMinute());
        } else {
            $this->travel(1)->minutes();
            app(CloseTeacherBlitz::class)($teacher, $blitz->assessment_id);
            if ($change === 'archived') {
                $this->travel(1)->minutes();
                app(ArchiveTeacherBlitz::class)($teacher, $blitz->assessment_id);
            }
            $this->assertSame($change, $blitz->fresh()->status->value);
        }

        $this->submit($student, $attempt, $key)->assertOk()->assertJsonPath('data.id', $attempt->id)
            ->assertJsonPath('data.finalization_reason', 'student_submit')->assertJsonPath('data.submitted_at', '2026-09-17T12:00:00Z');

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->fileAnswerSnapshot()]);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public static function laterLifecycleChanges(): array
    {
        return [['closed'], ['archived'], ['deadline']];
    }

    public function test_same_key_against_another_own_attempt_is_reused_and_cannot_change_the_original_result(): void
    {
        [$student, , $first] = $this->answerContext();
        $secondAssessment = $this->studentBlitz($student);
        $second = $this->studentBlitzAttempt($secondAssessment, $student);
        $key = (string) Str::uuid();
        $this->submit($student, $first, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $first, $key);
        $before = [$first->fresh()->getAttributes(), $second->getAttributes(), $record->getAttributes()];
        $this->travel(1)->minutes();

        $this->submit($student, $second, $key)->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->submit($student, $first, $key)->assertOk()->assertJsonPath('data.id', $first->id);

        $this->assertSame($before, [$first->fresh()->getAttributes(), $second->fresh()->getAttributes(), $record->fresh()->getAttributes()]);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public function test_same_key_is_independent_for_other_students_and_tenants(): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $other = $this->studentBlitzActor($student->institution);
        $otherAttempt = $this->studentBlitzAttempt($blitz->assessment, $other);
        [$foreign, , $foreignAttempt] = $this->answerContext();
        $key = (string) Str::uuid();
        $records = [];
        foreach ([[$student, $attempt], [$other, $otherAttempt], [$foreign, $foreignAttempt]] as [$actor, $target]) {
            $this->submit($actor, $target, $key)->assertOk()->assertJsonPath('data.id', $target->id);
            $records[] = $this->assertCompletedRecord($actor, $target, $key)->id;
        }
        $this->assertCount(3, array_unique($records));
        $this->assertDatabaseCount('idempotency_records', 3);
    }

    public function test_start_and_submit_use_the_same_uuid_independently_by_operation(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $key = (string) Str::uuid();
        $this->startStudentBlitz($student, $assessment, $key)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $startRecord = IdempotencyRecord::query()->sole();
        $before = $startRecord->getAttributes();

        $this->submit($student, $attempt, $key)->assertOk();

        $submitRecord = $this->assertCompletedRecord($student, $attempt, $key);
        $this->assertNotSame($startRecord->id, $submitRecord->id);
        $this->assertNotSame($startRecord->request_fingerprint, $submitRecord->request_fingerprint);
        $this->assertSame($before, $startRecord->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 2);
    }

    public function test_current_student_and_recipient_authorization_precedes_completed_replay(): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $recordBefore = $record->getAttributes();
        $other = $this->studentBlitzActor($student->institution);
        foreach ([$other, $this->studentBlitzActor()] as $actor) {
            $response = $this->submit($actor, $attempt, $key)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertStringNotContainsString($attempt->id, $response->getContent());
        }
        $otherRecipient = $this->blitzRecipient($blitz->assessment, $other, $blitz->assessment->teacher);
        $attempt->update(['assessment_student_id' => $otherRecipient->id]);
        $before = $attempt->fresh()->getAttributes();
        $this->submit($student, $attempt, $key)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    #[DataProvider('corruptMetadata')]
    public function test_corrupt_completed_result_metadata_fails_without_repair_or_new_claim(string $field, mixed $value): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $record->update([$field => $value]);
        $before = [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->fileAnswerSnapshot()];

        $this->assertSafeServerError($this->submit($student, $attempt, $key));

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->fileAnswerSnapshot()]);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public static function corruptMetadata(): array
    {
        return [
            ['result_resource_type', 'blitz_task'],
            ['result_resource_id', '3f8e3eab-f872-4224-a894-63b016a1de6b'],
            ['response_status', 201],
        ];
    }

    #[DataProvider('contradictoryLineages')]
    public function test_completed_submit_never_replays_timeout_close_or_mixed_execution_history(string $corruption): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $attempt->refresh()->update(match ($corruption) {
            'in progress' => ['status' => 'in_progress', 'submitted_at' => null, 'finalized_at' => null, 'locked_at' => null, 'finalization_reason' => null],
            'timeout' => ['status' => 'timed_out_finalized', 'submitted_at' => null, 'finalization_reason' => 'timeout_auto_submit',
                'finalized_at' => $attempt->deadline_at, 'locked_at' => $attempt->deadline_at],
            'close' => ['submitted_at' => null, 'finalization_reason' => 'task_closed_auto_finalize'],
            'finalized time' => ['finalized_at' => $attempt->finalized_at->copy()->addSecond()],
            'locked time' => ['locked_at' => $attempt->locked_at->copy()->addSecond()],
            'deadline equality' => ['deadline_at' => $attempt->finalized_at],
        });
        $before = [$attempt->fresh()->getAttributes(), $record->getAttributes(), $this->fileAnswerSnapshot()];

        $this->assertSafeServerError($this->submit($student, $attempt, $key));

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->fileAnswerSnapshot()]);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public static function contradictoryLineages(): array
    {
        return array_map(fn (string $state): array => [$state], ['in progress', 'timeout', 'close', 'finalized time', 'locked time', 'deadline equality']);
    }

    public function test_injected_completion_failure_rolls_back_attempt_and_claim_and_same_key_can_retry(): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $before = [$attempt->getAttributes(), $this->fileAnswerSnapshot()];
        $observedSubmitted = false;
        $dispatcher = IdempotencyRecord::getEventDispatcher();
        IdempotencyRecord::setEventDispatcher(clone $dispatcher);
        IdempotencyRecord::updating(function (IdempotencyRecord $record) use (&$observedSubmitted): void {
            if ($record->operation === IdempotencyOperation::StudentBlitzAttemptSubmit && $record->completed_at !== null) {
                $observedSubmitted = AssessmentAttempt::query()->whereKey($record->result_resource_id)
                    ->where('status', 'submitted')->where('finalization_reason', 'student_submit')->exists();
                throw new RuntimeException('Injected Blitz Submit completion failure.');
            }
        });
        try {
            app(SubmitStudentBlitzAttempt::class)($student, $attempt->id, $key);
            $this->fail('A completion failure must roll back the Attempt and claim.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected Blitz Submit completion failure.', $exception->getMessage());
        } finally {
            IdempotencyRecord::setEventDispatcher($dispatcher);
        }
        $this->assertTrue($observedSubmitted);
        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $this->fileAnswerSnapshot()]);
        $this->assertDatabaseCount('idempotency_records', 0);
        $this->answerRequest($student, $attempt, $attempt->assessment->questions()->where('type', 'open_written')->sole(), ['type' => 'open_written', 'text' => 'Still editable after rollback'])->assertOk();
        $this->submit($student, $attempt, $key)->assertOk();
        $this->assertCompletedRecord($student, $attempt, $key);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public function test_submitted_replay_keeps_pending_answer_integrity_and_preserves_completed_metadata_on_failure(): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        DB::table('attempt_answers')->where('attempt_id', $attempt->id)->update(['feedback' => 'Not permitted while submitted']);
        $before = [$attempt->fresh()->getAttributes(), $record->getAttributes(), $this->fileAnswerSnapshot()];

        $this->assertSafeServerError($this->submit($student, $attempt, $key));

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->fileAnswerSnapshot()]);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    private function savedAnswerContext(): array
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($blitz, 'open_written');
        $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        $this->savedFileAnswer($attempt, $this->answerQuestion($blitz, 'file_based', 2));

        return [$student, $blitz, $attempt];
    }

    private function assertCompletedRecord(User $student, AssessmentAttempt $attempt, string $key): IdempotencyRecord
    {
        $record = IdempotencyRecord::query()->where('institution_id', $student->institution_id)->where('user_id', $student->id)
            ->where('operation', IdempotencyOperation::StudentBlitzAttemptSubmit->value)->where('idempotency_key', $key)->sole();
        $this->assertSame('student.blitz.attempt.submit', IdempotencyOperation::StudentBlitzAttemptSubmit->value);
        $this->assertSame(IdempotencyOperation::StudentBlitzAttemptSubmit, $record->operation);
        $this->assertSame('assessment_attempt', $record->result_resource_type);
        $this->assertSame($attempt->id, $record->result_resource_id);
        $this->assertSame(200, $record->response_status);
        $this->assertNotNull($record->completed_at);
        $canonical = ['body' => (object) [], 'institution_id' => strtolower($student->institution_id),
            'operation' => 'student.blitz.attempt.submit', 'route' => ['attempt_id' => strtolower($attempt->id)],
            'user_id' => strtolower($student->id)];
        $this->assertSame(hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION)), $record->request_fingerprint);

        return $record;
    }

    private function assertSafeServerError(TestResponse $response): void
    {
        $response->assertStatus(500)->assertJsonPath('code', 'server_error');
        foreach (['LogicException', 'SQLSTATE', 'result_resource_id', 'student-submissions/', 'Not permitted while submitted'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    private function submit(User $student, AssessmentAttempt $attempt, string $key, string $body = ''): TestResponse
    {
        return $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', $body, $key);
    }
}
