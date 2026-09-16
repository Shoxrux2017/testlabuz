<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\TestCase;

class TeacherBlitzScheduleArchiveApiTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use RefreshDatabase;

    private const URI = '/api/v1/teacher/blitz';

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-16 08:00:00 UTC'));
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        parent::tearDown();
    }

    #[DataProvider('scheduleSourceStates')]
    public function test_schedule_sets_one_transition_instant_without_starting_execution(
        BlitzStatus $status,
        ?string $preparedSchedule,
    ): void {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        InstitutionSetting::query()->whereKey($institution->id)->update(['blitz_timer_start_mode' => null]);
        $assessment = $this->persistedBlitz(
            $institution, $teacher, $topic, status: $status,
            assessmentAttributes: ['total_possible_points' => '0.000000'],
            blitzAttributes: ['scheduled_at' => $preparedSchedule],
        );
        $this->travelTo(CarbonImmutable::parse('2026-09-16 08:30:00 UTC'));

        $this->schedule($teacher, $assessment, '2026-09-16T14:00:00+05:00')
            ->assertOk()
            ->assertJsonPath('message', 'Blitz task scheduled successfully.')
            ->assertJsonPath('data.status', 'scheduled')
            ->assertJsonPath('data.scheduled_at', '2026-09-16T09:00:00Z')
            ->assertJsonPath('data.institution_timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.updated_at', '2026-09-16T08:30:00Z')
            ->assertJsonPath('data.questions', [])
            ->assertJsonPath('data.student_ids', []);

        $blitz = $assessment->blitzTask()->firstOrFail();
        foreach ([
            'timer_start_mode_snapshot', 'activated_at', 'synchronized_ends_at',
            'closed_at', 'archived_at', 'activated_by_user_id',
        ] as $field) {
            $this->assertNull($blitz->{$field}, $field);
        }
        $this->assertTrue($blitz->updated_at->equalTo($assessment->fresh()->updated_at));
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    public static function scheduleSourceStates(): array
    {
        return [
            'draft without prepared date' => [BlitzStatus::Draft, null],
            'draft with prepared date' => [BlitzStatus::Draft, '2026-09-16 09:00:00+00:00'],
            'reschedule scheduled task' => [BlitzStatus::Scheduled, '2026-09-16 10:00:00+00:00'],
        ];
    }

    public function test_scheduling_the_same_instant_preserves_all_timestamps_and_recipients(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz(
            $institution, $teacher, $topic, AssessmentAssignmentMode::SelectedStudents, BlitzStatus::Scheduled,
            blitzAttributes: ['scheduled_at' => '2026-09-16 09:00:00+00:00'],
        );
        $recipient = $this->blitzRecipient($assessment, $student, $teacher);
        $before = [$assessment->fresh()->getAttributes(), $assessment->blitzTask->getAttributes(), $recipient->fresh()->getAttributes()];
        $this->travelTo(CarbonImmutable::parse('2026-09-16 08:30:00 UTC'));

        $this->schedule($teacher, $assessment, '2026-09-16T14:00:00+05:00')->assertOk();

        $this->assertSame($before, [
            $assessment->fresh()->getAttributes(),
            $assessment->blitzTask()->firstOrFail()->getAttributes(),
            $recipient->fresh()->getAttributes(),
        ]);
    }

    #[DataProvider('exactScheduledInstants')]
    public function test_repeating_the_exact_scheduled_instant_is_a_write_free_no_op(
        string $scheduledAt,
        string $expectedUtc,
    ): void {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $this->schedule($teacher, $assessment, $scheduledAt)->assertOk()
            ->assertJsonPath('data.status', 'scheduled')
            ->assertJsonPath('data.scheduled_at', $expectedUtc);
        $assessmentBefore = $assessment->fresh()->getAttributes();
        $reloadedBlitz = $assessment->blitzTask()->firstOrFail();
        $blitzBefore = $reloadedBlitz->getAttributes();
        $this->assertTrue($reloadedBlitz->scheduled_at->equalTo(CarbonImmutable::parse($scheduledAt)));
        $this->travelTo(CarbonImmutable::parse('2026-09-16 08:30:00 UTC'));
        $this->actingAs($teacher, 'sanctum');

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $this->postJson(self::URI.'/'.$assessment->id.'/schedule', ['scheduled_at' => $scheduledAt])
                ->assertOk()->assertJsonPath('data.scheduled_at', $expectedUtc)
                ->assertJsonPath('data.updated_at', '2026-09-16T08:00:00Z');
            $writes = array_filter(DB::getQueryLog(), fn (array $query): bool => preg_match('/^\s*(insert|update|delete)\b/i', $query['query']) === 1);
            $this->assertSame([], array_values($writes), 'An identical schedule must not write any database rows.');
        } finally {
            DB::disableQueryLog();
            DB::flushQueryLog();
        }

        $reloadedAssessment = $assessment->fresh();
        $blitz = $assessment->blitzTask()->firstOrFail();
        $this->assertSame($assessmentBefore['updated_at'], $reloadedAssessment->getRawOriginal('updated_at'));
        $this->assertSame($blitzBefore['updated_at'], $blitz->getRawOriginal('updated_at'));
        $this->assertSame($assessmentBefore, $reloadedAssessment->getAttributes());
        $this->assertSame($blitzBefore, $blitz->getAttributes());
        $this->assertTrue($blitz->scheduled_at->equalTo(CarbonImmutable::parse($scheduledAt)));
    }

    public static function exactScheduledInstants(): array
    {
        return [
            'whole second' => ['2026-09-17T10:00:00+05:00', '2026-09-17T05:00:00Z'],
            'explicit zero microseconds' => ['2026-09-17T10:00:00.000000+05:00', '2026-09-17T05:00:00Z'],
            'one fractional digit' => ['2026-09-17T10:00:00.2+05:00', '2026-09-17T05:00:00.200000Z'],
            'two fractional digits' => ['2026-09-17T10:00:00.25+05:00', '2026-09-17T05:00:00.250000Z'],
            'three fractional digits' => ['2026-09-17T10:00:00.251+05:00', '2026-09-17T05:00:00.251000Z'],
            'four fractional digits' => ['2026-09-17T10:00:00.2512+05:00', '2026-09-17T05:00:00.251200Z'],
            'five fractional digits' => ['2026-09-17T10:00:00.25123+05:00', '2026-09-17T05:00:00.251230Z'],
            'six fractional digits' => ['2026-09-17T10:00:00.251234+05:00', '2026-09-17T05:00:00.251234Z'],
            'trailing fractional zeroes' => ['2026-09-17T10:00:00.250000+05:00', '2026-09-17T05:00:00.250000Z'],
            'one microsecond' => ['2026-09-17T10:00:00.000001+05:00', '2026-09-17T05:00:00.000001Z'],
        ];
    }

    public function test_distinct_fractional_instants_within_the_same_second_reschedule_both_parents(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $this->schedule($teacher, $assessment, '2026-09-17T10:00:00.250000+05:00')
            ->assertOk()->assertJsonPath('data.scheduled_at', '2026-09-17T05:00:00.250000Z');
        $this->travelTo(CarbonImmutable::parse('2026-09-16 08:30:00 UTC'));

        $this->schedule($teacher, $assessment, '2026-09-17T10:00:00.250001+05:00')->assertOk()
            ->assertJsonPath('data.status', 'scheduled')
            ->assertJsonPath('data.scheduled_at', '2026-09-17T05:00:00.250001Z')
            ->assertJsonPath('data.updated_at', '2026-09-16T08:30:00Z');

        $blitz = $assessment->blitzTask()->firstOrFail();
        $this->assertSame('2026-09-17T05:00:00.250001Z', $blitz->scheduled_at->utc()->format('Y-m-d\TH:i:s.u\Z'));
        $this->assertTrue($assessment->fresh()->updated_at->equalTo(now()));
        $this->assertTrue($blitz->updated_at->equalTo(now()));
    }

    #[DataProvider('invalidScheduledInstants')]
    public function test_schedule_rejects_invalid_institution_local_times_without_mutation(mixed $scheduledAt): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $before = [$assessment->fresh()->getAttributes(), $assessment->blitzTask->getAttributes()];

        $this->blitzJson($teacher, 'POST', self::URI.'/'.$assessment->id.'/schedule', ['scheduled_at' => $scheduledAt])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $this->assertSame($before, [$assessment->fresh()->getAttributes(), $assessment->blitzTask()->firstOrFail()->getAttributes()]);
    }

    public static function invalidScheduledInstants(): array
    {
        return [
            'wrong institution offset' => ['2026-09-16T14:00:00+04:00'],
            'UTC Z is not a numeric offset' => ['2026-09-16T09:00:00Z'],
            'missing offset' => ['2026-09-16T14:00:00'],
            'invalid calendar date' => ['2027-02-30T14:00:00+05:00'],
            'unparseable' => ['tomorrow'],
            'past' => ['2026-09-16T12:59:59+05:00'],
            'equal to server clock' => ['2026-09-16T13:00:00+05:00'],
            'null' => [null],
            'integer' => [123],
            'array' => [[]],
        ];
    }

    public function test_schedule_rejects_a_nonexistent_institution_daylight_saving_local_time(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        InstitutionSetting::query()->whereKey($institution->id)->update(['timezone' => 'Europe/Berlin']);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);

        $this->schedule($teacher, $assessment, '2027-03-28T02:30:00+01:00')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    #[DataProvider('nonEditableBlitzStates')]
    public function test_schedule_rejects_non_preparation_lifecycle_states(BlitzStatus $status, string $code): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
        $before = $assessment->blitzTask->getAttributes();

        $this->schedule($teacher, $assessment, '2026-09-16T14:00:00+05:00')
            ->assertConflict()->assertJsonPath('code', $code);

        $this->assertSame($before, $assessment->blitzTask()->firstOrFail()->getAttributes());
    }

    public static function nonEditableBlitzStates(): array
    {
        return [
            'active' => [BlitzStatus::Active, 'business_conflict'],
            'closed' => [BlitzStatus::Closed, 'task_closed'],
            'archived' => [BlitzStatus::Archived, 'task_archived'],
        ];
    }

    #[DataProvider('historicalTopicStates')]
    public function test_historical_topics_block_schedule_but_allow_practice_archive(TopicStatus $status): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext($status);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);

        $this->schedule($teacher, $assessment, '2026-09-16T14:00:00+05:00')
            ->assertConflict()->assertJsonPath('code', 'topic_not_editable');
        $this->archive($teacher, $assessment)->assertOk()->assertJsonPath('data.status', 'archived');
    }

    public static function historicalTopicStates(): array
    {
        return [[TopicStatus::Closed], [TopicStatus::Archived]];
    }

    #[DataProvider('preparationStates')]
    public function test_unexpected_attempts_block_schedule_and_archive_without_repair(BlitzStatus $status): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
        $attempt = $this->blitzAttempt($assessment, $student, $teacher);
        $before = [$assessment->blitzTask->getAttributes(), $attempt->fresh()->getAttributes()];

        $this->schedule($teacher, $assessment, '2026-09-16T14:00:00+05:00')
            ->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->archive($teacher, $assessment)->assertConflict()->assertJsonPath('code', 'business_conflict');

        $this->assertSame($before, [$assessment->blitzTask()->firstOrFail()->getAttributes(), $attempt->fresh()->getAttributes()]);
    }

    public static function preparationStates(): array
    {
        return [[BlitzStatus::Draft], [BlitzStatus::Scheduled]];
    }

    #[DataProvider('archivableStates')]
    public function test_archive_preserves_recipients_question_configuration_and_valid_lifecycle_history(BlitzStatus $status): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        InstitutionSetting::query()->whereKey($institution->id)->update(['blitz_timer_start_mode' => null]);
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, AssessmentAssignmentMode::SelectedStudents, $status);
        $recipient = $this->blitzRecipient($assessment, $student, $teacher);
        $question = Question::factory()->trueFalse()->create(['assessment_id' => $assessment->id, 'institution_id' => $institution->id]);
        $answer = QuestionTrueFalseAnswer::factory()->create(['question_id' => $question->id, 'institution_id' => $institution->id]);
        $blitzBefore = $assessment->blitzTask->getAttributes();
        $historyBefore = [$recipient->fresh()->getAttributes(), $question->fresh()->getAttributes(), $answer->fresh()->getAttributes()];
        $this->travelTo(CarbonImmutable::parse('2026-09-16 08:30:00 UTC'));

        $this->archive($teacher, $assessment)->assertOk()
            ->assertJsonPath('message', 'Blitz task archived successfully.')
            ->assertJsonPath('data.status', 'archived')
            ->assertJsonPath('data.archived_at', '2026-09-16T08:30:00Z')
            ->assertJsonPath('data.updated_at', '2026-09-16T08:30:00Z');

        $blitz = $assessment->blitzTask()->firstOrFail();
        $this->assertSame(
            collect($blitzBefore)->except(['status', 'archived_at', 'updated_at'])->all(),
            collect($blitz->getAttributes())->except(['status', 'archived_at', 'updated_at'])->all(),
        );
        $this->assertSame($historyBefore, [$recipient->fresh()->getAttributes(), $question->fresh()->getAttributes(), $answer->fresh()->getAttributes()]);
        $this->assertTrue($blitz->updated_at->equalTo($assessment->fresh()->updated_at));
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    public static function archivableStates(): array
    {
        return [[BlitzStatus::Draft], [BlitzStatus::Scheduled], [BlitzStatus::Closed]];
    }

    public function test_repeat_archive_is_a_timestamp_stable_no_op(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $this->archive($teacher, $assessment)->assertOk();
        $before = [$assessment->fresh()->getAttributes(), $assessment->blitzTask()->firstOrFail()->getAttributes()];
        $this->travelTo(CarbonImmutable::parse('2026-09-16 09:00:00 UTC'));

        $this->archive($teacher, $assessment)->assertOk()->assertJsonPath('data.archived_at', '2026-09-16T08:00:00Z');

        $this->assertSame($before, [$assessment->fresh()->getAttributes(), $assessment->blitzTask()->firstOrFail()->getAttributes()]);
    }

    public function test_archive_does_not_close_active_blitz_or_finalize_its_attempt(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Active);
        $attempt = $this->blitzAttempt($assessment, $student, $teacher);
        $before = [$assessment->blitzTask->getAttributes(), $attempt->fresh()->getAttributes()];

        $this->archive($teacher, $assessment)->assertConflict()->assertJsonPath('code', 'business_conflict');

        $this->assertSame($before, [$assessment->blitzTask()->firstOrFail()->getAttributes(), $attempt->fresh()->getAttributes()]);
    }

    #[DataProvider('preparationStates')]
    public function test_pre_activation_official_blitz_cannot_archive_or_clear_its_pair(BlitzStatus $status): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
        $pair = $this->officialBlitzPair($assessment, $teacher);
        $before = [$assessment->blitzTask->getAttributes(), $pair->fresh()->getAttributes()];

        $this->archive($teacher, $assessment)->assertConflict()->assertJsonPath('code', 'business_conflict');

        $this->assertSame($before, [$assessment->blitzTask()->firstOrFail()->getAttributes(), $pair->fresh()->getAttributes()]);
    }

    public function test_closed_official_blitz_archives_without_mutating_pair_or_finalized_attempt(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Closed);
        $pair = $this->officialBlitzPair($assessment, $teacher, locked: true);
        $attempt = $this->blitzAttempt($assessment, $student, $teacher, [
            'status' => AssessmentAttemptStatus::Submitted,
            'submitted_at' => now(),
            'finalized_at' => now(),
            'locked_at' => now(),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
        ]);
        $before = [$pair->fresh()->getAttributes(), $attempt->fresh()->getAttributes()];

        $this->archive($teacher, $assessment)->assertOk()->assertJsonPath('data.status', 'archived');

        $this->assertSame($before, [$pair->fresh()->getAttributes(), $attempt->fresh()->getAttributes()]);
    }

    public function test_closed_blitz_with_in_progress_attempt_cannot_archive_or_finalize(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Closed);
        $attempt = $this->blitzAttempt($assessment, $student, $teacher);
        $before = [$assessment->blitzTask->getAttributes(), $attempt->fresh()->getAttributes()];

        $this->archive($teacher, $assessment)->assertConflict()->assertJsonPath('code', 'business_conflict');

        $this->assertSame($before, [$assessment->blitzTask()->firstOrFail()->getAttributes(), $attempt->fresh()->getAttributes()]);
    }

    public function test_schedule_and_archive_enforce_their_exact_request_shapes(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $scheduleUri = self::URI.'/'.$assessment->id.'/schedule';
        foreach (['', '{}', '[]', 'null', '{', '{"scheduled_at":"2026-09-16T14:00:00+05:00","status":"active"}'] as $body) {
            $this->blitzRaw($teacher, 'POST', $scheduleUri, $body)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->blitzJson($teacher, 'POST', $scheduleUri, ['scheduled_at' => '2026-09-16T14:00:00+05:00'], ['unknown' => 'value'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->blitzRaw($teacher, 'POST', $scheduleUri, '{"scheduled_at":"2026-09-16T14:00:00+05:00"}', contentType: 'text/plain')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $archiveUri = self::URI.'/'.$assessment->id.'/archive';
        foreach (['[]', 'null', '{', '{"status":"archived"}'] as $body) {
            $this->blitzRaw($teacher, 'POST', $archiveUri, $body)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->blitzRaw($teacher, 'POST', $archiveUri, '{}', ['unknown' => 'value'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->blitzRaw($teacher, 'POST', $archiveUri, '{}')->assertOk();
        $this->blitzRaw($teacher, 'POST', $archiveUri, '')->assertOk();
    }

    private function schedule(User $teacher, Assessment $assessment, string $scheduledAt): TestResponse
    {
        return $this->blitzJson($teacher, 'POST', self::URI.'/'.$assessment->id.'/schedule', ['scheduled_at' => $scheduledAt]);
    }

    private function archive(User $teacher, Assessment $assessment): TestResponse
    {
        return $this->blitzRaw($teacher, 'POST', self::URI.'/'.$assessment->id.'/archive', '{}');
    }
}
