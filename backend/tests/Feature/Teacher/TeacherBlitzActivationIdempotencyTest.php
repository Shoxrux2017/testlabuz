<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\ActivateTeacherBlitz;
use App\Enums\IdempotencyOperation;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\GroupTeacherMembership;
use App\Models\IdempotencyRecord;
use App\Models\InstitutionSetting;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzActivationContext;
use Tests\TestCase;

class TeacherBlitzActivationIdempotencyTest extends TestCase
{
    use BuildsTeacherBlitzActivationContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-17 12:00:00 UTC'));
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        parent::tearDown();
    }

    public function test_same_key_replay_preserves_every_domain_timestamp_and_completed_record(): void
    {
        [$institution, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $pair = $this->activationPair($assessment, $teacher);
        $key = (string) Str::uuid();
        $first = $this->activateBlitz($teacher, $assessment->id, strtoupper($key))->assertOk();
        $record = IdempotencyRecord::query()->sole();
        $this->assertSame(IdempotencyOperation::TeacherBlitzActivate, $record->operation);
        $this->assertSame($teacher->institution_id, $record->institution_id);
        $this->assertSame($teacher->id, $record->user_id);
        $this->assertSame($key, $record->idempotency_key);
        $this->assertSame('blitz', $record->result_resource_type);
        $this->assertSame($assessment->id, $record->result_resource_id);
        $this->assertSame(200, $record->response_status);
        $this->assertNotNull($record->completed_at);
        $canonical = ['body' => (object) [], 'institution_id' => strtolower($institution->id),
            'operation' => 'teacher.blitz.activate', 'route' => ['blitz_id' => strtolower($assessment->id)],
            'user_id' => strtolower($teacher->id)];
        $this->assertSame(hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION)), $record->request_fingerprint);
        $before = $this->activationSnapshot($assessment, $pair);
        $recordBefore = $record->getAttributes();
        $this->travel(10)->minutes();
        InstitutionSetting::query()->whereKey($institution->id)->update(['blitz_timer_start_mode' => 'individual']);

        $this->activateBlitz($teacher, $assessment->id, $key, '')->assertOk()->assertJsonPath('data', $first->json('data'));
        $this->assertSame($before, $this->activationSnapshot($assessment, $pair));
        $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->assertDatabaseCount('assessment_students', 1);
    }

    public function test_same_actor_key_for_another_authorized_blitz_conflicts_without_new_writes(): void
    {
        [$institution, $teacher, , , $topic, , $assessment] = $this->readyBlitzActivation();
        $other = $this->persistedBlitz($institution, $teacher, $topic);
        $this->activationQuestion($other);
        $key = (string) Str::uuid();
        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();
        $before = $this->activationSnapshot($other);
        $recordBefore = IdempotencyRecord::query()->sole()->getAttributes();

        $response = $this->activateBlitz($teacher, $other->id, $key)->assertConflict()->assertExactJson([
            'message' => 'The Idempotency-Key has already been used for a different request.',
            'code' => 'idempotency_key_reused', 'errors' => [],
        ]);
        $this->assertIsObject(json_decode($response->getContent(), false, flags: JSON_THROW_ON_ERROR)->errors);
        $this->assertSame($before, $this->activationSnapshot($other));
        $this->assertSame($recordBefore, IdempotencyRecord::query()->sole()->getAttributes());
    }

    public function test_different_teacher_can_use_the_same_key_in_the_same_institution(): void
    {
        [$institution, $teacher, $admin, $group, , , $assessment] = $this->readyBlitzActivation();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id, 'teacher_id' => $otherTeacher->id,
            'group_id' => $group->id, 'assigned_by_user_id' => $admin->id,
        ]);
        $topic = Topic::factory()->active()->create([
            'institution_id' => $institution->id, 'teacher_id' => $otherTeacher->id, 'group_id' => $group->id,
        ]);
        $other = $this->persistedBlitz($institution, $otherTeacher, $topic);
        $this->activationQuestion($other);
        $key = (string) Str::uuid();

        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();
        $this->activateBlitz($otherTeacher, $other->id, $key)->assertOk();
        $this->assertDatabaseCount('idempotency_records', 2);
        $this->assertSame(2, IdempotencyRecord::query()->where('idempotency_key', $key)->whereNotNull('completed_at')->count());
    }

    public function test_new_key_on_active_blitz_completes_another_claim_without_restarting_or_revalidating_settings(): void
    {
        [$institution, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $pair = $this->activationPair($assessment, $teacher);
        $first = $this->activateBlitz($teacher, $assessment->id)->assertOk();
        $before = $this->activationSnapshot($assessment, $pair);
        $this->travel(10)->minutes();
        InstitutionSetting::query()->whereKey($institution->id)->update(['blitz_timer_start_mode' => null]);

        $this->activateBlitz($teacher, $assessment->id)->assertOk()->assertJsonPath('data', $first->json('data'));
        $this->assertSame($before, $this->activationSnapshot($assessment, $pair));
        $this->assertSame(2, IdempotencyRecord::query()->where('result_resource_id', $assessment->id)->whereNotNull('completed_at')->count());
    }

    #[DataProvider('laterLifecycleStates')]
    public function test_completed_activation_replays_current_lifecycle_without_reactivating(string $status): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $key = (string) Str::uuid();
        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();
        $this->travel(2)->minutes();
        $blitz = BlitzTask::query()->findOrFail($assessment->id);
        $blitz->update(['status' => $status, 'closed_at' => now(), 'archived_at' => $status === 'archived' ? now() : null]);
        $before = $this->activationSnapshot($assessment);
        $recordBefore = IdempotencyRecord::query()->sole()->getAttributes();
        $this->travel(2)->minutes();

        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk()->assertJsonPath('data.status', $status);
        $this->assertSame($before, $this->activationSnapshot($assessment));
        $this->assertSame($recordBefore, IdempotencyRecord::query()->sole()->getAttributes());
        $this->activateBlitz($teacher, $assessment->id)->assertConflict()->assertJsonPath('code', 'task_'.$status);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public static function laterLifecycleStates(): array
    {
        return [['closed'], ['archived']];
    }

    #[DataProvider('invalidReplayMetadata')]
    public function test_completed_replay_metadata_is_validated_without_repair(string $attribute, mixed $value): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $key = (string) Str::uuid();
        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();
        $record = IdempotencyRecord::query()->sole();
        $record->update([$attribute => $value]);
        $recordBefore = $record->fresh()->getAttributes();
        $before = $this->activationSnapshot($assessment);

        try {
            app(ActivateTeacherBlitz::class)($teacher, $assessment->id, $key);
            $this->fail('A corrupted completed replay must fail as an invariant.');
        } catch (LogicException) {
            $this->assertSame($before, $this->activationSnapshot($assessment));
            $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        }
    }

    #[DataProvider('impossibleReplayLifecycles')]
    public function test_completed_replay_fails_closed_when_the_blitz_lacks_activation_history(array $lifecycle): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $key = (string) Str::uuid();
        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();
        BlitzTask::query()->whereKey($assessment->id)->update(array_merge([
            'timer_start_mode_snapshot' => null, 'activated_at' => null, 'synchronized_ends_at' => null,
            'closed_at' => null, 'archived_at' => null, 'activated_by_user_id' => null,
        ], $lifecycle));
        $recordBefore = IdempotencyRecord::query()->sole()->getAttributes();
        $before = $this->activationSnapshot($assessment);

        try {
            app(ActivateTeacherBlitz::class)($teacher, $assessment->id, $key);
            $this->fail('A completed activation must not replay over a Blitz without activation history.');
        } catch (LogicException $exception) {
            $this->assertSame('Completed Blitz activation requires persisted activation history.', $exception->getMessage());
            $this->assertSame($before, $this->activationSnapshot($assessment));
            $this->assertSame($recordBefore, IdempotencyRecord::query()->sole()->getAttributes());
        }
    }

    public static function impossibleReplayLifecycles(): array
    {
        return [
            'draft' => [['status' => 'draft']],
            'scheduled' => [['status' => 'scheduled', 'scheduled_at' => '2026-09-18 09:00:00']],
            'archived without activation' => [['status' => 'archived', 'archived_at' => '2026-09-17 12:05:00']],
        ];
    }

    public static function invalidReplayMetadata(): array
    {
        return [
            ['result_resource_type', 'assessment_attempt'], ['response_status', 201],
            ['result_resource_id', '00000000-0000-0000-0000-000000000099'],
        ];
    }

    public function test_completion_failure_rolls_back_activation_cohort_recipients_and_claim_and_same_key_can_retry(): void
    {
        [, $teacher, , , , , $assessment] = $this->readyBlitzActivation();
        $pair = $this->activationPair($assessment, $teacher);
        $before = $this->activationSnapshot($assessment, $pair);
        $key = (string) Str::uuid();
        $observedActivation = false;
        $dispatcher = IdempotencyRecord::getEventDispatcher();
        IdempotencyRecord::setEventDispatcher(clone $dispatcher);
        IdempotencyRecord::updating(function (IdempotencyRecord $record) use (&$observedActivation, $assessment, $pair): void {
            if ($record->completed_at !== null) {
                $observedActivation = BlitzTask::query()->findOrFail($assessment->id)->status->value === 'active'
                    && AssessmentStudent::query()->where('assessment_id', $assessment->id)->exists()
                    && $pair->fresh()->cohort_snapshotted_at !== null;
                throw new RuntimeException('Injected activation completion failure.');
            }
        });
        try {
            app(ActivateTeacherBlitz::class)($teacher, $assessment->id, $key);
            $this->fail('The completion failure must roll back the complete activation.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected activation completion failure.', $exception->getMessage());
        } finally {
            IdempotencyRecord::setEventDispatcher($dispatcher);
        }
        $this->assertTrue($observedActivation);
        $this->assertSame($before, $this->activationSnapshot($assessment, $pair));
        $this->assertDatabaseCount('idempotency_records', 0);
        $this->activateBlitz($teacher, $assessment->id, $key)->assertOk();
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->assertDatabaseCount('assessment_students', 1);
    }
}
