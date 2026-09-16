<?php

namespace Tests\Feature\Persistence;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzAttemptExceptionReasonType;
use App\Enums\BlitzStatus;
use App\Enums\BlitzTimerStartMode;
use App\Enums\UserRole;
use App\Models\Assessment;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class BlitzFactoryModelTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-16 12:00:00 UTC'));
    }

    public function test_enums_expose_exact_persisted_machine_values(): void
    {
        $this->assertSame(['draft', 'scheduled', 'active', 'closed', 'archived'], BlitzStatus::values());
        $this->assertSame(['technical', 'other_valid'], BlitzAttemptExceptionReasonType::values());
        $this->assertSame(['synchronized', 'individual'], BlitzTimerStartMode::values());
    }

    public function test_blitz_task_preserves_assessment_identity_and_casts_its_writable_fields(): void
    {
        $blitz = BlitzTask::factory()->archivedAfterCloseSynchronized()->create([
            'duration_seconds' => '420',
            'scheduled_at' => now()->subHour(),
        ])->fresh();

        $this->assertSame('assessment_id', $blitz->getKeyName());
        $this->assertSame($blitz->assessment->id, $blitz->getKey());
        $this->assertTrue(Str::isUuid($blitz->getKey()));
        $this->assertFalse($blitz->getIncrementing());
        $this->assertSame('string', $blitz->getKeyType());
        $this->assertNotContains(HasUuids::class, class_uses_recursive(BlitzTask::class));
        $this->assertSame([
            'assessment_id',
            'institution_id',
            'status',
            'duration_seconds',
            'scheduled_at',
            'timer_start_mode_snapshot',
            'activated_at',
            'synchronized_ends_at',
            'closed_at',
            'archived_at',
            'activated_by_user_id',
        ], $blitz->getFillable());

        $this->assertSame(BlitzStatus::Archived, $blitz->status);
        $this->assertSame(420, $blitz->duration_seconds);
        $this->assertSame(BlitzTimerStartMode::Synchronized, $blitz->timer_start_mode_snapshot);

        foreach (['scheduled_at', 'activated_at', 'synchronized_ends_at', 'closed_at', 'archived_at'] as $field) {
            $this->assertInstanceOf(CarbonInterface::class, $blitz->{$field});
        }

        $this->assertTrue($blitz->synchronized_ends_at->equalTo($blitz->activated_at->copy()->addSeconds(420)));

        $assessment = $blitz->assessment;
        $institution = $blitz->institution;
        $activator = $blitz->activatedBy;

        $this->assertInstanceOf(BelongsTo::class, $blitz->assessment());
        $this->assertInstanceOf(BelongsTo::class, $blitz->institution());
        $this->assertInstanceOf(BelongsTo::class, $blitz->activatedBy());
        $this->assertInstanceOf(HasOne::class, $assessment->blitzTask());
        $this->assertInstanceOf(HasMany::class, $institution->blitzTasks());
        $this->assertInstanceOf(HasMany::class, $activator->activatedBlitzTasks());

        $this->assertTrue($assessment->institution->is($institution));
        $this->assertTrue($assessment->teacher->is($activator));
        $this->assertTrue($blitz->is($assessment->blitzTask));
        $this->assertSame([$blitz->getKey()], $institution->blitzTasks->modelKeys());
        $this->assertSame([$blitz->getKey()], $activator->activatedBlitzTasks->modelKeys());
    }

    public function test_default_blitz_task_factory_derives_its_institution_from_a_blitz_assessment(): void
    {
        $blitz = BlitzTask::factory()->create()->fresh();
        $assessment = Assessment::factory()->blitz()->create();
        $linkedBlitz = BlitzTask::factory()->create(['assessment_id' => $assessment])->fresh();

        foreach ([$blitz, $linkedBlitz] as $task) {
            $this->assertSame(AssessmentType::Blitz, $task->assessment->type);
            $this->assertSame($task->assessment->institution_id, $task->institution_id);
            $this->assertSame($task->institution_id, $task->assessment->teacher->institution_id);
            $this->assertSame($task->institution_id, $task->assessment->topic->institution_id);
            $this->assertSame(BlitzStatus::Draft, $task->status);
            $this->assertSame(600, $task->duration_seconds);

            foreach ([
                'scheduled_at',
                'timer_start_mode_snapshot',
                'activated_at',
                'synchronized_ends_at',
                'closed_at',
                'archived_at',
                'activated_by_user_id',
            ] as $field) {
                $this->assertNull($task->{$field}, $field);
            }
        }

        $this->assertSame($assessment->id, $linkedBlitz->assessment_id);
        $this->assertNull($blitz->activatedBy);
    }

    #[DataProvider('lifecycleStates')]
    public function test_lifecycle_factory_states_persist_valid_same_institution_shapes(
        string $state,
        BlitzStatus $status,
        ?BlitzTimerStartMode $timerMode,
        array $presentTimestamps,
    ): void {
        $blitz = BlitzTask::factory()->{$state}()->create()->fresh();

        $this->assertSame($status, $blitz->status);
        $this->assertSame($timerMode, $blitz->timer_start_mode_snapshot);
        $this->assertSame(AssessmentType::Blitz, $blitz->assessment->type);
        $this->assertSame($blitz->assessment->institution_id, $blitz->institution_id);

        foreach (['scheduled_at', 'activated_at', 'synchronized_ends_at', 'closed_at', 'archived_at'] as $field) {
            if (in_array($field, $presentTimestamps, true)) {
                $this->assertInstanceOf(CarbonInterface::class, $blitz->{$field}, $field);
            } else {
                $this->assertNull($blitz->{$field}, $field);
            }
        }

        if ($timerMode === null) {
            $this->assertNull($blitz->activated_by_user_id);
            $this->assertNull($blitz->activatedBy);
        } else {
            $this->assertTrue($blitz->activated_at->greaterThanOrEqualTo($blitz->created_at));
            $this->assertSame($blitz->institution_id, $blitz->activatedBy->institution_id);
            $this->assertSame(UserRole::Teacher, $blitz->activatedBy->role);
        }

        if ($timerMode === BlitzTimerStartMode::Synchronized) {
            $this->assertTrue($blitz->synchronized_ends_at->equalTo(
                $blitz->activated_at->copy()->addSeconds($blitz->duration_seconds),
            ));
        }

        if ($blitz->closed_at !== null) {
            $this->assertTrue($blitz->closed_at->greaterThanOrEqualTo($blitz->activated_at));
        }

        if ($blitz->archived_at !== null) {
            $this->assertTrue($blitz->archived_at->greaterThanOrEqualTo($blitz->created_at));

            if ($blitz->closed_at !== null) {
                $this->assertTrue($blitz->archived_at->greaterThanOrEqualTo($blitz->closed_at));
            }
        }
    }

    public static function lifecycleStates(): array
    {
        return [
            'draft' => ['draft', BlitzStatus::Draft, null, []],
            'scheduled' => ['scheduled', BlitzStatus::Scheduled, null, ['scheduled_at']],
            'active synchronized' => [
                'activeSynchronized', BlitzStatus::Active, BlitzTimerStartMode::Synchronized,
                ['activated_at', 'synchronized_ends_at'],
            ],
            'active individual' => [
                'activeIndividual', BlitzStatus::Active, BlitzTimerStartMode::Individual,
                ['activated_at'],
            ],
            'closed synchronized' => [
                'closedSynchronized', BlitzStatus::Closed, BlitzTimerStartMode::Synchronized,
                ['activated_at', 'synchronized_ends_at', 'closed_at'],
            ],
            'closed individual' => [
                'closedIndividual', BlitzStatus::Closed, BlitzTimerStartMode::Individual,
                ['activated_at', 'closed_at'],
            ],
            'archived from draft' => ['archivedFromDraft', BlitzStatus::Archived, null, ['archived_at']],
            'archived from scheduled' => [
                'archivedFromScheduled', BlitzStatus::Archived, null, ['scheduled_at', 'archived_at'],
            ],
            'archived after synchronized close' => [
                'archivedAfterCloseSynchronized', BlitzStatus::Archived, BlitzTimerStartMode::Synchronized,
                ['activated_at', 'synchronized_ends_at', 'closed_at', 'archived_at'],
            ],
            'archived after individual close' => [
                'archivedAfterCloseIndividual', BlitzStatus::Archived, BlitzTimerStartMode::Individual,
                ['activated_at', 'closed_at', 'archived_at'],
            ],
        ];
    }

    public function test_default_exception_factory_builds_one_historical_attempt_without_a_replacement(): void
    {
        $exception = BlitzAttemptException::factory()->create()->fresh();
        $invalidated = $exception->invalidatedAttempt;
        $recipient = $exception->assessmentStudent;
        $assessment = $exception->assessment;

        $this->assertSame(BlitzAttemptExceptionReasonType::Technical, $exception->reason_type);
        $this->assertNotSame('', trim($exception->reason));
        $this->assertSame(AssessmentType::Blitz, $assessment->type);
        $this->assertNotNull($assessment->blitzTask);
        $this->assertSame($assessment->id, $assessment->blitzTask->getKey());
        $this->assertSame($assessment->id, $recipient->assessment_id);
        $this->assertSame($assessment->id, $invalidated->assessment_id);
        $this->assertSame($recipient->id, $invalidated->assessment_student_id);
        $this->assertSame($exception->student_id, $recipient->student_id);
        $this->assertSame($exception->student_id, $invalidated->student_id);
        $this->assertSame(UserRole::Student, $exception->student->role);
        $this->assertSame(UserRole::Teacher, $exception->grantedBy->role);
        $this->assertSame(1, $invalidated->attempt_number);
        $this->assertNotSame(AssessmentAttemptStatus::InProgress, $invalidated->status);
        $this->assertInstanceOf(CarbonInterface::class, $invalidated->finalized_at);
        $this->assertInstanceOf(CarbonInterface::class, $invalidated->locked_at);
        $this->assertFalse($invalidated->official_score_eligible);
        $this->assertNull($exception->replacement_attempt_id);
        $this->assertNull($exception->replacementAttempt);
        $this->assertSame([$invalidated->id], $assessment->attempts->modelKeys());
        $this->assertSame([$recipient->id], $assessment->recipients->modelKeys());

        foreach ([
            $assessment,
            $assessment->blitzTask,
            $assessment->teacher,
            $assessment->topic,
            $recipient,
            $recipient->assignedBy,
            $exception->student,
            $invalidated,
            $exception->grantedBy,
        ] as $related) {
            $this->assertSame($exception->institution_id, $related->institution_id);
        }
    }

    public function test_exception_uuid_casts_and_all_relationships_preserve_their_distinct_keys(): void
    {
        $exception = BlitzAttemptException::factory()->withReplacementAttempt()->create([
            'reason_type' => BlitzAttemptExceptionReasonType::OtherValid,
        ])->fresh();
        $institution = $exception->institution;
        $assessment = $exception->assessment;
        $blitz = $assessment->blitzTask;
        $recipient = $exception->assessmentStudent;
        $student = $exception->student;
        $invalidated = $exception->invalidatedAttempt;
        $replacement = $exception->replacementAttempt;
        $grantor = $exception->grantedBy;

        $this->assertSame('id', $exception->getKeyName());
        $this->assertTrue(Str::isUuid($exception->getKey()));
        $this->assertFalse($exception->getIncrementing());
        $this->assertSame('string', $exception->getKeyType());
        $this->assertSame([
            'institution_id',
            'assessment_id',
            'assessment_student_id',
            'student_id',
            'invalidated_attempt_id',
            'replacement_attempt_id',
            'reason_type',
            'reason',
            'granted_by_user_id',
            'granted_at',
        ], $exception->getFillable());
        $this->assertSame(BlitzAttemptExceptionReasonType::OtherValid, $exception->reason_type);
        $this->assertInstanceOf(CarbonInterface::class, $exception->granted_at);

        foreach ([
            'institution', 'assessment', 'assessmentStudent', 'student',
            'invalidatedAttempt', 'replacementAttempt', 'grantedBy',
        ] as $relationship) {
            $this->assertInstanceOf(BelongsTo::class, $exception->{$relationship}());
        }

        foreach ([
            [$blitz, 'attemptExceptions'],
            [$assessment, 'blitzAttemptExceptions'],
            [$recipient, 'blitzAttemptExceptions'],
            [$institution, 'blitzAttemptExceptions'],
            [$student, 'blitzAttemptExceptions'],
            [$grantor, 'grantedBlitzAttemptExceptions'],
        ] as [$parent, $relationship]) {
            $this->assertInstanceOf(HasMany::class, $parent->{$relationship}());
            $this->assertSame([$exception->id], $parent->{$relationship}->modelKeys());
        }

        $this->assertInstanceOf(HasOne::class, $invalidated->invalidatingBlitzException());
        $this->assertInstanceOf(HasOne::class, $replacement->replacementBlitzException());
        $this->assertTrue($exception->is($invalidated->invalidatingBlitzException));
        $this->assertTrue($exception->is($replacement->replacementBlitzException));
        $this->assertNull($invalidated->replacementBlitzException);
        $this->assertNull($replacement->invalidatingBlitzException);
        $this->assertTrue($student->grantedBlitzAttemptExceptions->isEmpty());
        $this->assertTrue($grantor->blitzAttemptExceptions->isEmpty());

        $this->assertSame($institution->id, $exception->institution_id);
        $this->assertSame($assessment->id, $exception->assessment_id);
        $this->assertSame($recipient->id, $exception->assessment_student_id);
        $this->assertSame($student->id, $exception->student_id);
        $this->assertSame($invalidated->id, $exception->invalidated_attempt_id);
        $this->assertSame($replacement->id, $exception->replacement_attempt_id);
        $this->assertSame($grantor->id, $exception->granted_by_user_id);
        $this->assertNotSame($invalidated->id, $replacement->id);
        $this->assertSame(2, $replacement->attempt_number);
        $this->assertSame($assessment->id, $replacement->assessment_id);
        $this->assertSame($recipient->id, $replacement->assessment_student_id);
        $this->assertSame($student->id, $replacement->student_id);
        $this->assertSame($institution->id, $replacement->institution_id);
        $this->assertLessThanOrEqual(1, $assessment->attempts()->where('status', AssessmentAttemptStatus::InProgress)->count());
    }
}
