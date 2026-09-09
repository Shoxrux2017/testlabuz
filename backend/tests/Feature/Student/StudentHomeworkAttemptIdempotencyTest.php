<?php

namespace Tests\Feature\Student;

use App\Actions\Student\StartStudentHomeworkAttempt;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\IdempotencyOperation;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Idempotency\IdempotencyGuard;
use App\Support\Idempotency\IdempotencyRequestFingerprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

class StudentHomeworkAttemptIdempotencyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
    }

    public function test_create_replay_preserves_logical_attempt_status_and_all_persistence_timestamps(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $pair = TopicResultPair::factory()->create([
            'homework_assessment_id' => $homework->assessment_id,
            'designated_at' => now()->subMinutes(2), 'cohort_snapshotted_at' => now()->subMinute(),
        ]);
        $key = (string) Str::uuid();
        $first = $this->start($student, $homework, strtoupper($key), '{}')->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $record = IdempotencyRecord::query()->sole();
        $this->assertSame(IdempotencyOperation::StudentHomeworkAttemptStart, $record->operation);
        $this->assertSame($student->institution_id, $record->institution_id);
        $this->assertSame($student->id, $record->user_id);
        $this->assertSame($key, $record->idempotency_key);
        $this->assertSame('assessment_attempt', $record->result_resource_type);
        $this->assertSame($attempt->id, $record->result_resource_id);
        $this->assertSame(201, $record->response_status);
        $this->assertNotNull($record->completed_at);
        $this->assertSame($this->expectedFingerprint($student, $homework), $record->request_fingerprint);
        $before = [$attempt->getAttributes(), $pair->fresh()->getAttributes(), $record->getAttributes()];
        $this->travel(5)->minutes();

        $this->start($student, $homework, $key)->assertCreated()->assertJsonPath('data.id', $first->json('data.id'));

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $pair->fresh()->getAttributes(), $record->fresh()->getAttributes()]);
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public function test_resume_replay_keeps_original_200_and_one_attempt(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $this->start($student, $homework, (string) Str::uuid())->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();
        $before = $attempt->getAttributes();
        $key = (string) Str::uuid();
        $this->travel(1)->minutes();
        $this->start($student, $homework, $key)->assertOk()->assertJsonPath('data.id', $attempt->id);
        $record = IdempotencyRecord::query()->where('idempotency_key', $key)->sole();
        $recordBefore = $record->getAttributes();
        $this->travel(1)->minutes();
        $this->start($student, $homework, $key)->assertOk()->assertJsonPath('data.id', $attempt->id);
        $this->assertSame(200, $record->response_status);
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 2);
    }

    public function test_same_key_for_a_different_authorized_homework_conflicts_before_its_lifecycle_without_mutation(): void
    {
        $student = $this->student();
        $first = $this->homework($student);
        $second = $this->homework($student, 'closed');
        $key = (string) Str::uuid();
        $this->start($student, $first, $key)->assertCreated();
        $recordBefore = IdempotencyRecord::query()->sole()->getAttributes();
        $secondBefore = $second->fresh()->getAttributes();

        $this->start($student, $second, $key)->assertConflict()->assertJsonPath('code', 'idempotency_key_reused')
            ->assertJsonPath('message', 'The Idempotency-Key has already been used for a different request.');

        $this->assertSame($secondBefore, $second->fresh()->getAttributes());
        $this->assertSame($recordBefore, IdempotencyRecord::query()->sole()->getAttributes());
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $second->assessment_id]);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public function test_existing_key_never_discloses_unassigned_or_foreign_homework(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $key = (string) Str::uuid();
        $this->start($student, $homework, $key)->assertCreated();
        foreach ([$this->homework($this->student($student->institution)), $this->homework($this->student())] as $inaccessible) {
            $this->start($student, $inaccessible, $key)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public function test_same_key_is_independent_for_another_student_institution_and_operation(): void
    {
        $first = $this->student();
        $second = $this->student($first->institution);
        $foreign = $this->student();
        $homework = $this->homework($first);
        AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id, 'student_id' => $second->id]);
        $foreignHomework = $this->homework($foreign);
        $key = (string) Str::uuid();
        IdempotencyRecord::factory()->completed()->create([
            'institution_id' => $first->institution_id, 'user_id' => $first->id,
            'operation' => IdempotencyOperation::StudentHomeworkAttemptSubmit, 'idempotency_key' => $key,
        ]);
        $ids = [];
        foreach ([[$first, $homework], [$second, $homework], [$foreign, $foreignHomework]] as [$actor, $target]) {
            $ids[] = $this->start($actor, $target, $key)->assertCreated()->json('data.id');
        }
        $this->assertCount(3, array_unique($ids));
        $this->assertDatabaseCount('assessment_attempts', 3);
        $this->assertDatabaseCount('idempotency_records', 4);
    }

    #[DataProvider('replayCorruptions')]
    public function test_broken_or_foreign_replay_targets_fail_as_invariants_without_replacement_or_record_repair(string $corruption): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $key = (string) Str::uuid();
        $attemptId = $this->start($student, $homework, $key)->assertCreated()->json('data.id');
        $record = IdempotencyRecord::query()->sole();
        $attempt = AssessmentAttempt::query()->findOrFail($attemptId);
        if ($corruption === 'missing attempt') {
            $record->update(['result_resource_id' => (string) Str::uuid()]);
        } elseif (in_array($corruption, ['other student', 'other institution', 'other homework'], true)) {
            $other = match ($corruption) {
                'other student' => $this->student($student->institution),
                'other institution' => $this->student(),
                default => $student,
            };
            $otherHomework = $corruption === 'other student' ? $homework : $this->homework($other);
            if ($corruption === 'other student') {
                AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id, 'student_id' => $other->id]);
            }
            $otherAttemptId = $this->start($other, $otherHomework, (string) Str::uuid())->assertCreated()->json('data.id');
            $record->update(['result_resource_id' => $otherAttemptId]);
        } elseif ($corruption === 'recipient graph') {
            $otherHomework = $this->homework($student);
            $recipient = AssessmentStudent::query()->where('assessment_id', $otherHomework->assessment_id)->sole();
            $attempt->update(['assessment_student_id' => $recipient->id]);
        } elseif ($corruption === 'resource type') {
            $record->update(['result_resource_type' => 'homework_assignment']);
        } elseif ($corruption === 'response status') {
            $record->update(['response_status' => 202]);
        } else {
            $attempt->update(match ($corruption) {
                'attempt deadline' => ['deadline_at' => now()->addDay()],
                'blitz status' => ['status' => AssessmentAttemptStatus::TimedOutFinalized],
                'blitz reason' => ['finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit],
                'in progress finalized' => ['finalized_at' => now()],
            });
        }
        $attemptsBefore = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $recordsBefore = IdempotencyRecord::query()->orderBy('id')->get()->map->getAttributes()->all();
        $this->withoutExceptionHandling();
        try {
            $this->start($student, $homework, $key);
            $this->fail('Corrupted durable replay must fail as an internal invariant.');
        } catch (LogicException) {
            $this->assertSame($attemptsBefore, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
            $this->assertSame($recordsBefore, IdempotencyRecord::query()->orderBy('id')->get()->map->getAttributes()->all());
        } finally {
            $this->withExceptionHandling();
        }
        $response = $this->start($student, $homework, $key)->assertStatus(500);
        foreach (['assessment_student_id', 'result_resource_id', $attempt->id, 'SQLSTATE', 'LogicException'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public static function replayCorruptions(): array
    {
        return array_combine($cases = [
            'missing attempt', 'other student', 'other institution', 'other homework', 'recipient graph',
            'resource type', 'response status', 'attempt deadline', 'blitz status', 'blitz reason', 'in progress finalized',
        ], array_map(fn (string $case): array => [$case], $cases));
    }

    #[DataProvider('replayLifecycleChanges')]
    public function test_completed_replay_survives_current_lifecycle_and_deadline_changes_with_original_status(string $change): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $key = (string) Str::uuid();
        $attemptId = $this->start($student, $homework, $key)->assertCreated()->json('data.id');
        $attempt = AssessmentAttempt::query()->findOrFail($attemptId);
        $this->travel(1)->minutes();
        if ($change === 'deadline') {
            $homework->update(['deadline_at' => now()]);
            $this->getAs($student, '/api/v1/student/attempts/'.$attemptId)->assertOk()
                ->assertJsonPath('data.status', 'submitted')->assertJsonPath('data.finalization_reason', 'homework_deadline_auto_submit');
        } else {
            $homework->update(['status' => $change === 'closed' ? HomeworkStatus::Closed : HomeworkStatus::Archived,
                'closed_at' => now(), 'archived_at' => $change === 'archived' ? now() : null]);
            $attempt->update(['status' => AssessmentAttemptStatus::Submitted, 'finalized_at' => now(), 'locked_at' => now(),
                'finalization_reason' => AssessmentAttemptFinalizationReason::TaskClosedAutoFinalize]);
        }
        $attemptBefore = $attempt->fresh()->getAttributes();
        $recordBefore = IdempotencyRecord::query()->sole()->getAttributes();
        $this->travel(1)->minutes();
        $this->start($student, $homework, $key)->assertCreated()->assertJsonPath('data.id', $attemptId)->assertJsonPath('data.status', 'submitted');
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->assertSame($recordBefore, IdempotencyRecord::query()->sole()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public static function replayLifecycleChanges(): array
    {
        return ['closed' => ['closed'], 'archived' => ['archived'], 'deadline reconciled' => ['deadline']];
    }

    public function test_failed_zero_point_start_leaves_no_claim_and_the_same_key_can_retry_after_the_failure_is_resolved(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $homework->assessment->update(['total_possible_points' => '0.000000']);
        $key = (string) Str::uuid();
        $this->start($student, $homework, $key)->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
        $homework->assessment->update(['total_possible_points' => '3.000000']);
        $this->start($student, $homework, $key)->assertCreated();
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public function test_persisted_incomplete_claim_is_an_invariant_and_never_becomes_a_replacement_start(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $key = (string) Str::uuid();
        $record = IdempotencyRecord::factory()->create([
            'institution_id' => $student->institution_id, 'user_id' => $student->id,
            'idempotency_key' => $key, 'request_fingerprint' => $this->expectedFingerprint($student, $homework),
        ]);
        $before = $record->fresh()->getAttributes();
        $this->withoutExceptionHandling();
        try {
            $this->start($student, $homework, $key);
            $this->fail('A previously persisted incomplete claim cannot be adopted.');
        } catch (LogicException) {
            $this->assertSame($before, $record->fresh()->getAttributes());
            $this->assertDatabaseCount('assessment_attempts', 0);
            $this->assertDatabaseCount('idempotency_records', 1);
        }
    }

    public function test_idempotency_completion_failure_rolls_back_attempt_pair_and_new_claim_together(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $pair = TopicResultPair::factory()->create(['homework_assessment_id' => $homework->assessment_id, 'cohort_snapshotted_at' => now()]);
        $pairBefore = $pair->fresh()->getAttributes();
        $observedAttempt = false;
        $dispatcher = IdempotencyRecord::getEventDispatcher();
        IdempotencyRecord::setEventDispatcher(clone $dispatcher);
        IdempotencyRecord::updating(function (IdempotencyRecord $record) use (&$observedAttempt, $pair): void {
            if ($record->completed_at !== null) {
                $observedAttempt = AssessmentAttempt::query()->whereKey($record->result_resource_id)->exists()
                    && $pair->fresh()->locked_at !== null;
                throw new RuntimeException('Injected idempotency completion failure.');
            }
        });
        try {
            app(StartStudentHomeworkAttempt::class)($student, $homework->assessment_id, (string) Str::uuid());
            $this->fail('The injected completion failure must escape and roll back the transaction.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected idempotency completion failure.', $exception->getMessage());
        } finally {
            IdempotencyRecord::setEventDispatcher($dispatcher);
        }
        $this->assertTrue($observedAttempt);
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_fingerprint_sorts_objects_recursively_preserves_list_order_and_scalar_types(): void
    {
        $actor = $this->student();
        $fingerprints = app(IdempotencyRequestFingerprint::class);
        $operation = IdempotencyOperation::StudentHomeworkAttemptStart;
        $first = $fingerprints->make($actor, $operation, ['z' => 2, 'a' => ['z' => false, 'a' => null]], ['list' => [1, '1', true], 'number' => 1.0]);
        $same = $fingerprints->make($actor, $operation, ['a' => ['a' => null, 'z' => false], 'z' => 2], ['number' => 1.0, 'list' => [1, '1', true]]);
        $this->assertSame($first, $same);
        $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', $first);
        $this->assertNotSame($first, $fingerprints->make($actor, $operation, ['z' => 2, 'a' => ['z' => false, 'a' => null]], ['list' => ['1', 1, true], 'number' => 1.0]));
        $this->assertNotSame($first, $fingerprints->make($actor, $operation, ['z' => 2, 'a' => ['z' => false, 'a' => null]], ['list' => [1, '1', true], 'number' => 1]));
        $this->assertNotSame($first, $fingerprints->make($actor, IdempotencyOperation::StudentHomeworkAttemptSubmit, ['z' => 2, 'a' => ['z' => false, 'a' => null]], ['list' => [1, '1', true], 'number' => 1.0]));
    }

    public function test_guard_only_completes_or_abandons_new_incomplete_claims_and_never_mutates_completed_records(): void
    {
        $actor = $this->student();
        $guard = app(IdempotencyGuard::class);
        $operation = IdempotencyOperation::StudentHomeworkAttemptStart;
        $fingerprint = hash('sha256', 'guard semantic request');
        $key = (string) Str::uuid();
        DB::transaction(function () use ($actor, $guard, $operation, $fingerprint, $key): void {
            $this->assertNull($guard->completedReplay($actor, $operation, $key, $fingerprint));
            $claim = $guard->claim($actor, $operation, $key, $fingerprint);
            $this->assertTrue($claim->new);
            $this->assertNull($claim->record->completed_at);
            try {
                $guard->complete($claim, 'assessment_attempt', (string) Str::uuid(), 409);
                $this->fail('A failure HTTP status cannot complete a protected operation.');
            } catch (LogicException) {
                $this->assertNull($claim->record->fresh()->completed_at);
            }
            $guard->abandon($claim);
            $this->assertDatabaseCount('idempotency_records', 0);
            $claim = $guard->claim($actor, $operation, $key, $fingerprint);
            $guard->complete($claim, 'assessment_attempt', (string) Str::uuid(), 201);
            $before = $claim->record->fresh()->getAttributes();
            $replay = $guard->claim($actor, $operation, $key, $fingerprint);
            $this->assertFalse($replay->new);
            $this->assertSame($claim->record->id, $guard->completedReplay($actor, $operation, $key, $fingerprint)->id);
            foreach ([fn () => $guard->abandon($claim), fn () => $guard->abandon($replay),
                fn () => $guard->complete($claim, 'assessment_attempt', (string) Str::uuid(), 200),
                fn () => $guard->complete($replay, 'assessment_attempt', (string) Str::uuid(), 200)] as $mutation) {
                try {
                    $mutation();
                    $this->fail('Completed idempotency records are immutable.');
                } catch (LogicException) {
                    $this->assertSame($before, $claim->record->fresh()->getAttributes());
                }
            }
        });
    }

    private function student(?Institution $institution = null): User
    {
        if ($institution === null) {
            $institution = Institution::factory()->create();
            InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        }

        return User::factory()->student($institution)->create(['must_change_password' => false]);
    }

    private function homework(User $student, string $state = 'active'): HomeworkAssignment
    {
        $topic = Topic::factory()->active()->create(['institution_id' => $student->institution_id]);
        $assessment = Assessment::factory()->homework()->create([
            'institution_id' => $student->institution_id, 'topic_id' => $topic->id,
            'teacher_id' => $topic->teacher_id, 'total_possible_points' => '3.000000',
        ]);
        $homework = HomeworkAssignment::factory()->{$state}()->create(['assessment_id' => $assessment->id]);
        AssessmentStudent::factory()->create(['assessment_id' => $assessment->id, 'student_id' => $student->id, 'assigned_by_user_id' => $assessment->teacher_id]);

        return $homework;
    }

    private function expectedFingerprint(User $actor, HomeworkAssignment $homework): string
    {
        $canonical = ['body' => (object) [], 'institution_id' => strtolower($actor->institution_id),
            'operation' => 'student.homework.attempt.start', 'route' => ['homework_id' => strtolower($homework->assessment_id)],
            'user_id' => strtolower($actor->id)];

        return hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION));
    }

    private function start(User $student, HomeworkAssignment $homework, string $key, string $body = ''): TestResponse
    {
        return $this->requestAs($student, 'POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts', $key, $body);
    }

    private function getAs(User $student, string $uri): TestResponse
    {
        return $this->requestAs($student, 'GET', $uri, (string) Str::uuid());
    }

    private function requestAs(User $student, string $method, string $uri, string $key, string $body = ''): TestResponse
    {
        try {
            return $this->call($method, $uri, [], [], [], [
                'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json', 'HTTP_IDEMPOTENCY_KEY' => $key,
                'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('homework-idempotency-test')->plainTextToken,
            ], $body);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }
}
