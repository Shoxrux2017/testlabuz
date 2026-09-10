<?php

namespace Tests\Feature\Student;

use App\Actions\Student\SubmitStudentHomeworkAttempt;
use App\Actions\Teacher\ArchiveTeacherHomework;
use App\Actions\Teacher\CloseTeacherHomework;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\IdempotencyOperation;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\GroupTeacherMembership;
use App\Models\IdempotencyRecord;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentHomeworkAttemptSubmitIdempotencyTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
        Storage::fake('local');
    }

    public function test_same_key_and_attempt_replay_has_exact_scoped_metadata_and_no_timestamp_or_answer_churn(): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = '6f115db9-3a55-4074-bbdd-f5c8d50a8b63';
        $answersBefore = $this->savedState();
        $this->travel(1)->minutes();

        $first = $this->submit($student, $attempt, strtoupper($key), '{}')->assertOk()
            ->assertJsonPath('message', 'Homework submitted successfully.');
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $before = [$attempt->fresh()->getAttributes(), $record->getAttributes()];
        $this->assertSame($answersBefore, $this->savedState());
        $this->travel(10)->minutes();

        $this->submit($student, $attempt, $key)->assertOk()->assertExactJson($first->json());

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes()]);
        $this->assertSame($answersBefore, $this->savedState());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    #[DataProvider('laterLifecycleChanges')]
    public function test_completed_replay_survives_teacher_close_archive_and_deadline_without_resubmitting(string $change): void
    {
        [$student, $homework, $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $before = [$attempt->fresh()->getAttributes(), $record->getAttributes(), $this->savedState()];
        if ($change === 'deadline') {
            $this->travelTo($homework->deadline_at->copy()->addMinute());
        } else {
            $topic = $homework->assessment->topic;
            $teacher = User::query()->findOrFail($topic->teacher_id);
            GroupTeacherMembership::factory()->create([
                'institution_id' => $teacher->institution_id, 'group_id' => $topic->group_id, 'teacher_id' => $teacher->id,
            ]);
            $this->travel(1)->minutes();
            app(CloseTeacherHomework::class)($teacher, $homework->assessment_id);
            if ($change === 'archived') {
                $this->travel(1)->minutes();
                app(ArchiveTeacherHomework::class)($teacher, $homework->assessment_id);
            }
            $this->assertSame($change, $homework->fresh()->status->value);
        }

        $this->submit($student, $attempt, $key)->assertOk()->assertJsonPath('data.id', $attempt->id)
            ->assertJsonPath('data.finalization_reason', 'student_submit')->assertJsonPath('message', 'Homework submitted successfully.');

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->savedState()]);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public static function laterLifecycleChanges(): array
    {
        return ['Teacher closed' => ['closed'], 'Teacher archived' => ['archived'], 'deadline passed' => ['deadline']];
    }

    #[DataProvider('laterTerminalStatuses')]
    public function test_replay_returns_later_terminal_attempt_status_with_answers_still_in_valid_stage_seven_pending_state(string $status): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $recordBefore = $record->getAttributes();
        $originalFinalization = array_intersect_key($attempt->fresh()->getAttributes(), array_flip([
            'submitted_at', 'finalized_at', 'locked_at', 'finalization_reason',
        ]));
        $answersBefore = $this->savedState();
        $this->travel(1)->minutes();
        $attempt->update(['status' => $status]);
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->travel(1)->minutes();

        $this->submit($student, $attempt, $key)->assertOk()->assertJsonPath('data.id', $attempt->id)
            ->assertJsonPath('data.status', $status)->assertJsonPath('data.finalization_reason', 'student_submit');

        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->assertSame($originalFinalization, array_intersect_key($attemptBefore, $originalFinalization));
        $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        $this->assertSame($answersBefore, $this->savedState());
        foreach (AttemptAnswer::query()->get() as $answer) {
            $this->assertSame('pending', $answer->getRawOriginal('checking_status'));
            foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
                $this->assertNull($answer->getAttribute($field));
            }
        }
    }

    public static function laterTerminalStatuses(): array
    {
        return ['waiting for Teacher review' => ['waiting_for_teacher_review'], 'checked Attempt with pending Answers' => ['checked']];
    }

    public function test_fixed_key_non_file_corruption_rolls_back_twice_then_recovers_and_replays_without_churn(): void
    {
        $this->assertFixedKeyCorruptionRecovery('non-file', '9f3a915f-d559-493a-9ba7-cf1511ad5ba8');
    }

    public function test_fixed_key_file_corruption_rolls_back_twice_then_recovers_and_replays_without_churn(): void
    {
        $this->assertFixedKeyCorruptionRecovery('file', 'd56cb4db-8891-49e1-9eb1-d6d8fc48991d');
    }

    #[DataProvider('corruptedSavedFamilies')]
    public function test_repeated_projection_failure_after_historical_success_preserves_completed_record_attempt_answers_and_file_bytes(string $family): void
    {
        [$student, , $attempt, $writtenAnswer, $file] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $before = [$attempt->fresh()->getAttributes(), $record->getAttributes()];
        $this->changeSavedFixtureIntegrity($family, $writtenAnswer, $file, false);
        $corruptState = $this->savedState();

        for ($retry = 0; $retry < 2; $retry++) {
            $this->travel(1)->minutes();
            $this->assertSafeServerError($this->submit($student, $attempt, $key));
            $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes()]);
            $this->assertSame($corruptState, $this->savedState());
            $this->assertDatabaseCount('idempotency_records', 1);
        }
    }

    public static function corruptedSavedFamilies(): array
    {
        return ['non-file Answer corruption' => ['non-file'], 'file Answer corruption' => ['file']];
    }

    public function test_same_key_for_another_authorized_attempt_conflicts_and_original_key_replays_after_a_later_start(): void
    {
        [$student, $homework, $firstAttempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $firstAttempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $firstAttempt, $key);
        $recordBefore = $record->getAttributes();
        $firstBefore = $firstAttempt->fresh()->getAttributes();
        $secondId = $this->answerHttp($student, 'POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts', headers: [
            'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
        ])->assertCreated()->assertJsonPath('data.attempt_number', 2)->json('data.id');
        $second = AssessmentAttempt::query()->findOrFail($secondId);
        $secondBefore = $second->getAttributes();
        $answersBefore = $this->savedState();
        $this->travel(1)->minutes();

        $this->submit($student, $second, $key)->assertConflict()->assertJsonPath('code', 'idempotency_key_reused');
        $this->assertSame($secondBefore, $second->fresh()->getAttributes());
        $this->submit($student, $firstAttempt, $key)->assertOk()->assertJsonPath('data.id', $firstAttempt->id);

        $this->assertSame($firstBefore, $firstAttempt->fresh()->getAttributes());
        $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        $this->assertSame($answersBefore, $this->savedState());
        $this->assertSame(1, IdempotencyRecord::query()->where('operation', IdempotencyOperation::StudentHomeworkAttemptSubmit->value)->count());
    }

    public function test_prior_start_and_submit_use_the_same_uuid_independently_by_operation(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $key = (string) Str::uuid();
        $this->answerHttp($student, 'POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts', headers: [
            'HTTP_IDEMPOTENCY_KEY' => $key,
        ])->assertOk()->assertJsonPath('data.id', $attempt->id);
        $startRecord = IdempotencyRecord::query()->sole();
        $startBefore = $startRecord->getAttributes();
        $this->assertSame(IdempotencyOperation::StudentHomeworkAttemptStart, $startRecord->operation);

        $this->submit($student, $attempt, $key)->assertOk()->assertJsonPath('data.id', $attempt->id);

        $submitRecord = $this->assertCompletedRecord($student, $attempt, $key);
        $this->assertNotSame($startRecord->id, $submitRecord->id);
        $this->assertNotSame($startRecord->request_fingerprint, $submitRecord->request_fingerprint);
        $this->assertSame($startBefore, $startRecord->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 2);
    }

    public function test_same_key_can_independently_submit_for_another_student_and_institution(): void
    {
        [$first, $homework, $firstAttempt] = $this->answerContext();
        $second = User::factory()->student($first->institution)->create(['must_change_password' => false]);
        $recipient = AssessmentStudent::factory()->create([
            'assessment_id' => $homework->assessment_id, 'student_id' => $second->id,
        ]);
        $secondAttempt = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id]);
        [$foreign, , $foreignAttempt] = $this->answerContext();
        $key = (string) Str::uuid();
        $recordIds = [];

        foreach ([[$first, $firstAttempt], [$second, $secondAttempt], [$foreign, $foreignAttempt]] as [$actor, $attempt]) {
            $this->submit($actor, $attempt, $key)->assertOk()->assertJsonPath('data.id', $attempt->id);
            $recordIds[] = $this->assertCompletedRecord($actor, $attempt, $key)->id;
        }

        $this->assertCount(3, array_unique($recordIds));
        $this->assertDatabaseCount('idempotency_records', 3);
        $this->assertDatabaseCount('assessment_attempts', 3);
    }

    #[DataProvider('corruptReplayMetadata')]
    public function test_inconsistent_completed_replay_metadata_is_a_safe_invariant_failure_and_is_never_repaired(string $field, mixed $value): void
    {
        [$student, , $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $record->update([$field => $value]);
        $before = [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->savedState()];

        $this->assertSafeServerError($this->submit($student, $attempt, $key));

        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes(), $this->savedState()]);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public static function corruptReplayMetadata(): array
    {
        return [
            'wrong resource type' => ['result_resource_type', 'homework_assignment'],
            'wrong result Attempt' => ['result_resource_id', '329e8380-e177-4f68-a105-daf70716da80'],
            'wrong success status' => ['response_status', 201],
        ];
    }

    #[DataProvider('corruptReplayAttemptStates')]
    public function test_completed_replay_checks_locked_attempt_invariants_after_lifecycle_changes_and_preserves_historical_metadata(string $corruption): void
    {
        [$student, $homework, $attempt] = $this->savedAnswerContext();
        $key = (string) Str::uuid();
        $this->submit($student, $attempt, $key)->assertOk();
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $recordBefore = $record->getAttributes();
        $homework->update(['status' => 'closed', 'closed_at' => now()]);
        $this->travelTo($homework->deadline_at->copy()->addMinute());

        $attempt->refresh()->update(match ($corruption) {
            'Attempt deadline' => ['deadline_at' => now()],
            'Blitz status' => ['status' => 'timed_out_finalized'],
            'Blitz reason' => ['finalization_reason' => 'timeout_auto_submit'],
            default => array_replace([
                'status' => 'in_progress', 'submitted_at' => null, 'finalized_at' => null,
                'locked_at' => null, 'finalization_reason' => null,
            ], [$corruption => $corruption === 'finalization_reason' ? 'student_submit' : now()]),
        });
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->savedState();

        try {
            app(SubmitStudentHomeworkAttempt::class)($student, $attempt->id, $key);
            $this->fail('Completed replay must validate the locked Attempt before returning action success.');
        } catch (LogicException) {
            $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
            $this->assertSame($recordBefore, $record->fresh()->getAttributes());
            $this->assertSame($answersBefore, $this->savedState());
        }
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    public static function corruptReplayAttemptStates(): array
    {
        $states = ['Attempt deadline', 'Blitz status', 'Blitz reason',
            'submitted_at', 'finalized_at', 'locked_at', 'finalization_reason'];

        return array_combine($states, array_map(fn (string $state): array => [$state], $states));
    }

    public function test_completion_failure_rolls_back_explicit_finalization_and_new_claim_while_preserving_answers_and_result_pair(): void
    {
        [$student, $homework, $attempt] = $this->savedAnswerContext();
        $pair = TopicResultPair::factory()->create([
            'homework_assessment_id' => $homework->assessment_id, 'cohort_snapshotted_at' => now(), 'locked_at' => now(),
        ]);
        $before = [$attempt->fresh()->getAttributes(), $pair->fresh()->getAttributes(), $this->savedState()];
        $observedSubmittedAttempt = false;
        $dispatcher = IdempotencyRecord::getEventDispatcher();
        IdempotencyRecord::setEventDispatcher(clone $dispatcher);
        IdempotencyRecord::updating(function (IdempotencyRecord $record) use (&$observedSubmittedAttempt): void {
            if ($record->operation === IdempotencyOperation::StudentHomeworkAttemptSubmit && $record->completed_at !== null) {
                $observedSubmittedAttempt = AssessmentAttempt::query()->whereKey($record->result_resource_id)
                    ->where('status', 'submitted')->where('finalization_reason', 'student_submit')->exists();
                throw new RuntimeException('Injected Submit completion failure.');
            }
        });

        try {
            app(SubmitStudentHomeworkAttempt::class)($student, $attempt->id, (string) Str::uuid());
            $this->fail('The injected completion failure must roll back finalization and the claim.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Injected Submit completion failure.', $exception->getMessage());
        } finally {
            IdempotencyRecord::setEventDispatcher($dispatcher);
        }

        $this->assertTrue($observedSubmittedAttempt);
        $this->assertSame($before, [$attempt->fresh()->getAttributes(), $pair->fresh()->getAttributes(), $this->savedState()]);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    private function assertFixedKeyCorruptionRecovery(string $family, string $key): void
    {
        [$student, , $attempt, $writtenAnswer, $file] = $this->savedAnswerContext();
        $validState = $this->savedState();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->changeSavedFixtureIntegrity($family, $writtenAnswer, $file, false);
        $corruptState = $this->savedState();

        for ($retry = 0; $retry < 2; $retry++) {
            $this->travel(1)->minutes();
            $this->assertSafeServerError($this->submit($student, $attempt, $key));
            $this->assertSame(AssessmentAttemptStatus::InProgress, $attempt->fresh()->status);
            $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
            $this->assertSame($corruptState, $this->savedState());
            $this->assertDatabaseCount('idempotency_records', 0);
        }

        $this->changeSavedFixtureIntegrity($family, $writtenAnswer, $file, true);
        $this->assertSame($validState, $this->savedState());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->travel(1)->minutes();
        $first = $this->submit($student, $attempt, $key)->assertOk()->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.finalization_reason', 'student_submit');
        $record = $this->assertCompletedRecord($student, $attempt, $key);
        $this->assertSame($validState, $this->savedState());
        $this->assertDatabaseCount('idempotency_records', 1);
        foreach (['submitted_at', 'finalized_at', 'locked_at', 'updated_at'] as $field) {
            $this->assertTrue($attempt->fresh()->getAttribute($field)->equalTo(now()));
        }
        $completedBefore = [$attempt->fresh()->getAttributes(), $record->getAttributes()];
        $this->travel(1)->minutes();

        $this->submit($student, $attempt, $key)->assertOk()->assertExactJson($first->json());

        $this->assertSame($completedBefore, [$attempt->fresh()->getAttributes(), $record->fresh()->getAttributes()]);
        $this->assertSame($validState, $this->savedState());
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    private function savedAnswerContext(): array
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $written = $this->answerQuestion($homework, 'open_written');
        $this->answerRequest($student, $attempt, $written, $this->answerPayload($written))->assertOk();
        $writtenAnswer = AttemptAnswer::query()->where('question_id', $written->id)->sole();
        [, , $file] = $this->savedFileAnswer($attempt, $this->answerQuestion($homework, 'file_based', 2));

        return [$student, $homework, $attempt, $writtenAnswer, $file];
    }

    private function changeSavedFixtureIntegrity(string $family, AttemptAnswer $writtenAnswer, File $file, bool $valid): void
    {
        if ($family === 'non-file') {
            DB::table('attempt_answers')->where('id', $writtenAnswer->id)->update(['feedback' => $valid ? null : 'corrupt persisted feedback']);
        } else {
            DB::table('files')->where('id', $file->id)->update(['checksum_sha256' => $valid ? $file->checksum_sha256 : null]);
        }
    }

    private function savedState(): array
    {
        $contents = [];
        foreach (File::query()->orderBy('id')->get() as $file) {
            $contents[$file->storage_key] = Storage::disk($file->storage_disk)->get($file->storage_key);
        }

        return $this->fileAnswerSnapshot() + ['file_contents' => $contents];
    }

    private function assertCompletedRecord(User $student, AssessmentAttempt $attempt, string $key): IdempotencyRecord
    {
        $record = IdempotencyRecord::query()->where('institution_id', $student->institution_id)->where('user_id', $student->id)
            ->where('operation', IdempotencyOperation::StudentHomeworkAttemptSubmit->value)->where('idempotency_key', $key)->sole();
        $this->assertSame(IdempotencyOperation::StudentHomeworkAttemptSubmit, $record->operation);
        $this->assertSame('assessment_attempt', $record->result_resource_type);
        $this->assertSame($attempt->id, $record->result_resource_id);
        $this->assertSame(200, $record->response_status);
        $this->assertNotNull($record->completed_at);
        $canonical = ['body' => (object) [], 'institution_id' => strtolower($student->institution_id),
            'operation' => 'student.homework.attempt.submit', 'route' => ['attempt_id' => strtolower($attempt->id)],
            'user_id' => strtolower($student->id)];
        $this->assertSame(hash('sha256', json_encode($canonical, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION)), $record->request_fingerprint);

        return $record;
    }

    private function assertSafeServerError(TestResponse $response): void
    {
        $response->assertStatus(500)->assertJsonPath('code', 'server_error');
        foreach (['LogicException', 'SQLSTATE', 'checksum_sha256', 'result_resource_id', 'corrupt persisted feedback', 'student-submissions/'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    private function submit(User $student, AssessmentAttempt $attempt, string $key, string $body = ''): TestResponse
    {
        return $this->answerHttp($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', $body, headers: [
            'HTTP_IDEMPOTENCY_KEY' => $key,
        ]);
    }
}
