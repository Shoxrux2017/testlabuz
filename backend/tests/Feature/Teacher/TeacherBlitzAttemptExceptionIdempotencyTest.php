<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\GrantTeacherBlitzAttemptException;
use App\Enums\BlitzStatus;
use App\Enums\IdempotencyOperation;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\GroupTeacherMembership;
use App\Models\IdempotencyRecord;
use App\Models\Topic;
use App\Models\User;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\TestCase;

class TeacherBlitzAttemptExceptionIdempotencyTest extends TestCase
{
    use BuildsBlitzExceptionContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('replayStates')]
    public function test_completed_replay_retains_identity_and_projects_current_availability(string $state): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext();
        $key = (string) Str::uuid();
        $first = $this->grantException($teacher, $assessment, $student, $key)->assertCreated();
        $record = IdempotencyRecord::query()->sole();
        $this->assertSame(IdempotencyOperation::TeacherBlitzAttemptExceptionGrant, $record->operation);
        $this->assertSame('teacher.blitz.attempt_exception.grant', $record->operation->value);
        $this->assertSame('blitz_attempt_exception', $record->result_resource_type);
        $this->assertSame($first->json('data.id'), $record->result_resource_id);
        $this->assertSame(201, $record->response_status);
        $this->assertNotNull($record->completed_at);
        $this->assertSame(app(IdempotencyRequestFingerprint::class)->make($teacher, $record->operation,
            ['blitz_id' => $assessment->id, 'student_id' => $student->id],
            ['reason_type' => 'technical', 'reason' => 'Device interruption.']), $record->request_fingerprint);
        $replacementId = null;
        if (in_array($state, ['replacement', 'terminal replacement'], true)) {
            $replacementId = $this->startStudentBlitz($student, $assessment, intent: 'start_replacement')->assertCreated()->json('data.id');
            if ($state === 'terminal replacement') {
                $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$replacementId.'/submit')->assertOk();
            }
        } elseif ($state !== 'active') {
            BlitzTask::query()->whereKey($assessment->id)->update(['status' => $state, 'closed_at' => now(), 'archived_at' => $state === 'archived' ? now() : null]);
        }
        $before = BlitzAttemptException::query()->sole()->getAttributes();
        $this->grantException($teacher, $assessment, $student, $key, ['reason_type' => 'technical', 'reason' => ' Device interruption. '])
            ->assertCreated()->assertJsonPath('data.id', $first->json('data.id'))
            ->assertJsonPath('data.replacement_attempt_id', $replacementId)
            ->assertJsonPath('data.replacement_attempt_available', $state === 'active');
        $this->assertSame($before, BlitzAttemptException::query()->sole()->getAttributes());
        $this->assertSame($record->getAttributes(), $record->fresh()->getAttributes());
        $this->assertFalse($normal->fresh()->official_score_eligible);
    }

    public static function replayStates(): array
    {
        return [['active'], ['closed'], ['archived'], ['replacement'], ['terminal replacement']];
    }

    #[DataProvider('changedIdentities')]
    public function test_same_key_with_different_semantic_identity_is_rejected(string $changed): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $key = (string) Str::uuid();
        $this->grantException($teacher, $assessment, $student, $key)->assertCreated();
        $body = ['reason_type' => 'technical', 'reason' => 'Device interruption.'];
        if ($changed === 'reason') {
            $body['reason'] = 'Another reason.';
        } elseif ($changed === 'type') {
            $body['reason_type'] = 'other_valid';
        } elseif ($changed === 'student') {
            $student = $this->studentBlitzActor($student->institution);
            $this->blitzRecipient($assessment, $student, $teacher);
        } else {
            $assessment = $this->persistedBlitz($student->institution, $teacher, $assessment->topic);
            $this->blitzRecipient($assessment, $student, $teacher);
        }
        $this->grantException($teacher, $assessment, $student, $key, $body)->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->assertDatabaseCount('blitz_attempt_exceptions', 1);
    }

    public static function changedIdentities(): array
    {
        return [['reason'], ['type'], ['student'], ['blitz']];
    }

    public function test_completion_failure_rolls_back_timeout_invalidation_exception_and_claim(): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext(terminal: false);
        $this->travelTo($normal->deadline_at);
        $before = $normal->getAttributes();
        $dispatcher = IdempotencyRecord::getEventDispatcher();
        IdempotencyRecord::setEventDispatcher(clone $dispatcher);
        IdempotencyRecord::updating(function ($record): void {
            if ($record->completed_at !== null) {
                throw new RuntimeException('Injected completion failure.');
            }
        });
        try {
            app(GrantTeacherBlitzAttemptException::class)($teacher, $assessment->id, $student->id, (string) Str::uuid(),
                ['reason_type' => 'technical', 'reason' => 'Device interruption.']);
            $this->fail('Completion failure must escape.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected completion failure.', $exception->getMessage());
            $this->assertSame($before, $normal->fresh()->getAttributes());
            $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
            $this->assertDatabaseCount('idempotency_records', 0);
        } finally {
            IdempotencyRecord::setEventDispatcher($dispatcher);
        }
        $this->grantException($teacher, $assessment, $student)->assertCreated();
    }

    public function test_same_student_has_independent_blitz_exceptions_and_same_key_is_scoped_to_teacher(): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $key = (string) Str::uuid();
        $this->grantException($teacher, $assessment, $student, $key)->assertCreated();
        $otherTeacher = User::factory()->teacher($student->institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create(['institution_id' => $student->institution_id,
            'group_id' => $assessment->topic->group_id, 'teacher_id' => $otherTeacher->id, 'assigned_by_user_id' => $teacher->id]);
        $otherTopic = Topic::factory()->active()->create(['institution_id' => $student->institution_id,
            'group_id' => $assessment->topic->group_id, 'teacher_id' => $otherTeacher->id]);
        $otherBlitz = $this->persistedBlitz($student->institution, $otherTeacher, $otherTopic, status: BlitzStatus::Active,
            assessmentAttributes: ['total_possible_points' => '5.000000']);
        $this->terminateStudentBlitzAttempt($this->studentBlitzAttempt($otherBlitz, $student));
        $this->grantException($otherTeacher, $otherBlitz, $student, $key)->assertCreated();
        $this->assertDatabaseCount('blitz_attempt_exceptions', 2);
        $this->assertDatabaseCount('idempotency_records', 2);
        $this->assertSame(2, IdempotencyRecord::query()->where('idempotency_key', $key)->count());
    }

    #[DataProvider('corruptMetadata')]
    public function test_corrupt_completed_metadata_is_not_repaired(string $field, mixed $value): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $key = (string) Str::uuid();
        $this->grantException($teacher, $assessment, $student, $key)->assertCreated();
        IdempotencyRecord::query()->sole()->update([$field => $value]);
        $this->expectException(LogicException::class);
        app(GrantTeacherBlitzAttemptException::class)($teacher, $assessment->id, $student->id, $key,
            ['reason_type' => 'technical', 'reason' => 'Device interruption.']);
    }

    public static function corruptMetadata(): array
    {
        return [['result_resource_type', 'assessment_attempt'], ['response_status', 200], ['result_resource_id', '00000000-0000-4000-8000-000000000099']];
    }
}
