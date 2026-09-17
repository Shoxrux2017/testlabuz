<?php

namespace Tests\Feature\Student;

use App\Enums\IdempotencyOperation;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\IdempotencyRecord;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzContext;
use Tests\TestCase;

class StudentBlitzAttemptStartIdempotencyTest extends TestCase
{
    use BuildsStudentBlitzContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_start_replay_preserves_original_status_resource_fingerprint_and_all_persistence(): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $key = (string) Str::uuid();
        $attemptId = $this->startStudentBlitz($student, $assessment, strtoupper($key))->assertCreated()->json('data.id');
        $attempt = AssessmentAttempt::query()->sole();
        $record = IdempotencyRecord::query()->sole();
        $this->assertSame('student.blitz.attempt.start', IdempotencyOperation::StudentBlitzAttemptStart->value);
        $this->assertSame(IdempotencyOperation::StudentBlitzAttemptStart, $record->operation);
        $this->assertSame($key, $record->idempotency_key);
        $this->assertSame($student->institution_id, $record->institution_id);
        $this->assertSame($student->id, $record->user_id);
        $this->assertSame('assessment_attempt', $record->result_resource_type);
        $this->assertSame($attemptId, $record->result_resource_id);
        $this->assertSame(201, $record->response_status);
        $this->assertNotNull($record->completed_at);
        $canonical = ['body' => ['intent' => 'start_normal'], 'institution_id' => strtolower($student->institution_id),
            'operation' => 'student.blitz.attempt.start', 'route' => ['blitz_id' => strtolower($assessment->id)], 'user_id' => strtolower($student->id)];
        $this->assertSame(hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION)), $record->request_fingerprint);
        $before = [$attempt->getAttributes(), $record->getAttributes(), $pair->fresh()->getAttributes()];
        $this->travel(1)->minutes();
        $this->startStudentBlitz($student, $assessment, $key)->assertCreated()->assertJsonPath('data.id', $attemptId);
        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $pair->fresh()->getAttributes()]);
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public function test_each_resume_key_replays_exact_attempt_with_original_200_without_timestamp_mutation(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $this->startStudentBlitz($student, $assessment)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $before = $attempt->getAttributes();
        $this->travel(1)->minutes();
        foreach (['resume', 'resume', 'start_normal'] as $intent) {
            $key = (string) Str::uuid();
            $target = $intent === 'resume' ? $attempt->id : null;
            $this->startStudentBlitz($student, $assessment, $key, $intent, $target)->assertOk()->assertJsonPath('data.id', $attempt->id);
            $record = IdempotencyRecord::query()->where('idempotency_key', $key)->sole();
            $recordBefore = $record->getAttributes();
            $this->assertSame(200, $record->response_status);
            $this->assertSame('assessment_attempt', $record->result_resource_type);
            $this->assertSame($attempt->id, $record->result_resource_id);
            $this->travel(1)->minutes();
            $this->startStudentBlitz($student, $assessment, $key, $intent, $target)->assertOk()->assertJsonPath('data.id', $attempt->id);
            $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        }
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 4);
    }

    public function test_semantically_different_requests_cannot_reuse_a_completed_key(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $otherBlitz = $this->studentBlitz($student);
        $normalKey = (string) Str::uuid();
        $attemptId = $this->startStudentBlitz($student, $assessment, $normalKey)->assertCreated()->json('data.id');
        $this->startStudentBlitz($student, $otherBlitz, $normalKey)->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->startStudentBlitz($student, $assessment, $normalKey, 'resume', $attemptId)->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $resumeKey = (string) Str::uuid();
        $this->startStudentBlitz($student, $assessment, $resumeKey, 'resume', $attemptId)->assertOk();
        $this->startStudentBlitz($student, $assessment, $resumeKey, 'resume', (string) Str::uuid())->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->startStudentBlitz($student, $assessment, $resumeKey)->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 2);
    }

    public function test_authorization_precedes_replay_and_other_students_cannot_replay_its_resource(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $key = (string) Str::uuid();
        $original = $this->startStudentBlitz($student, $assessment, $key)->assertCreated()->json('data.id');
        $other = $this->studentBlitzActor($student->institution);
        $foreign = $this->studentBlitzActor();
        foreach ([$other, $foreign] as $actor) {
            $response = $this->startStudentBlitz($actor, $assessment, $key)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertStringNotContainsString($original, $response->getContent());
        }
        $this->blitzRecipient($assessment, $other, $assessment->teacher);
        $second = $this->startStudentBlitz($other, $assessment, $key)->assertCreated()->json('data.id');
        $this->assertNotSame($original, $second);
        foreach ([$this->studentBlitz($student, assigned: false), $this->studentBlitz($foreign)] as $private) {
            $this->startStudentBlitz($student, $private, $key)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->assertDatabaseCount('idempotency_records', 2);
    }

    #[DataProvider('replayCorruptions')]
    public function test_corrupted_completed_metadata_never_restarts_or_repairs_the_attempt(string $corruption): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $key = (string) Str::uuid();
        $this->startStudentBlitz($student, $assessment, $key)->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $record = IdempotencyRecord::query()->sole();
        if ($corruption === 'recipient') {
            $otherAssessment = $this->studentBlitz($student);
            $attempt->update(['assessment_student_id' => AssessmentStudent::query()->where('assessment_id', $otherAssessment->id)->sole()->id]);
        } elseif ($corruption === 'other student') {
            $other = $this->studentBlitzActor($student->institution);
            $otherAttempt = $this->studentBlitzAttempt($assessment, $other);
            $record->update(['result_resource_id' => $otherAttempt->id]);
        } else {
            $record->update(match ($corruption) {
                'resource type' => ['result_resource_type' => 'blitz_task'],
                'response status' => ['response_status' => 202],
                'missing result' => ['result_resource_id' => (string) Str::uuid()],
            });
        }
        $attemptsBefore = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $before = $record->fresh()->getAttributes();
        $this->withoutExceptionHandling();
        try {
            $this->startStudentBlitz($student, $assessment, $key);
            $this->fail('Invalid completed metadata must not become a new Start.');
        } catch (LogicException) {
            $this->assertSame($before, $record->fresh()->getAttributes());
            $this->assertSame($attemptsBefore, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
        } finally {
            $this->withExceptionHandling();
        }
        $response = $this->startStudentBlitz($student, $assessment, $key)->assertStatus(500);
        foreach (['LogicException', 'SQLSTATE', 'result_resource_id', 'assessment_student_id', $attempt->id] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public function test_failed_completion_rolls_back_pair_lock_attempt_and_claim_atomically(): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $pairBefore = $pair->fresh()->getAttributes();
        $observedWrites = false;
        $dispatcher = IdempotencyRecord::getEventDispatcher();
        IdempotencyRecord::setEventDispatcher(clone $dispatcher);
        IdempotencyRecord::updating(function (IdempotencyRecord $record) use (&$observedWrites, $pair): void {
            if ($record->completed_at !== null) {
                $observedWrites = $pair->fresh()->locked_at !== null && AssessmentAttempt::query()->whereKey($record->result_resource_id)->exists();
                throw new RuntimeException('Injected Blitz completion failure.');
            }
        });
        $this->withoutExceptionHandling();
        try {
            $this->startStudentBlitz($student, $assessment);
            $this->fail('Injected completion failure must roll back the transaction.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected Blitz completion failure.', $exception->getMessage());
        } finally {
            IdempotencyRecord::setEventDispatcher($dispatcher);
        }
        $this->assertTrue($observedWrites);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function replayCorruptions(): array
    {
        return [['resource type'], ['response status'], ['missing result'], ['recipient'], ['other student']];
    }
}
