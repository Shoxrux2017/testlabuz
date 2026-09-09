<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AnswerBooleanValue;
use App\Models\AnswerFile;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\GroupStudentMembership;
use App\Models\HomeworkAssignment;
use App\Models\IdempotencyRecord;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use Closure;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentHomeworkFileAnswerLifecycleTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
        Storage::fake('local');
    }

    public function test_preliminary_privacy_denial_never_stores_a_blob(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [$foreignStudent, , $foreignAttempt, $foreignQuestion] = $this->fileAnswerContext();
        $otherStudent = User::factory()->student($student->institution)->create(['must_change_password' => false]);
        $storage = $this->trackedStorage();
        $before = $this->fileAnswerSnapshot();

        $this->fileAnswerRequest($otherStudent, $attempt, $question, $this->fileAnswerUpload())
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->fileAnswerRequest($student, $foreignAttempt, $foreignQuestion, $this->fileAnswerUpload())
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->fileAnswerRequest($foreignStudent, $attempt, $question, $this->fileAnswerUpload())
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');

        $this->assertSame([], $storage->stored);
        $this->assertSame([], Storage::disk('local')->allFiles());
        $this->assertSame($before, $this->fileAnswerSnapshot());
    }

    public function test_assigned_own_attempt_remains_editable_after_current_group_membership_ends(): void
    {
        [$student, $homework, $attempt, $question] = $this->fileAnswerContext();
        GroupStudentMembership::factory()->ended()->create([
            'institution_id' => $student->institution_id, 'student_id' => $student->id,
            'group_id' => $homework->assessment->topic->group_id,
        ]);
        $before = $attempt->getAttributes();

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload())->assertOk();

        $this->assertSame($before, $attempt->fresh()->getAttributes());
    }

    #[DataProvider('terminalStatuses')]
    public function test_valid_terminal_homework_attempt_rejects_replacement_and_cleans_new_blob(string $status): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $attempt->update($this->terminalAttributes($status));
        $before = $this->fileAnswerSnapshot();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $storage = $this->trackedStorage();

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload('replacement.pdf'))
            ->assertConflict()->assertJsonPath('code', 'attempt_not_editable');

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function terminalStatuses(): array
    {
        return array_combine(['submitted', 'waiting_for_teacher_review', 'checked'], [
            ['submitted'], ['waiting_for_teacher_review'], ['checked'],
        ]);
    }

    #[DataProvider('attemptCorruptions')]
    public function test_corrupt_locked_homework_attempt_causes_safe_server_failure_and_compensates(string $corruption): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $changes = match ($corruption) {
            'deadline' => ['deadline_at' => now()->addHour()],
            'Blitz status' => ['status' => 'timed_out_finalized'],
            'Blitz reason' => array_replace($this->terminalAttributes('submitted'), ['finalization_reason' => 'timeout_auto_submit']),
            'submitted timestamp' => ['submitted_at' => now()],
            'finalized timestamp' => ['finalized_at' => now()],
            'locked timestamp' => ['locked_at' => now()],
            'finalization reason' => ['finalization_reason' => 'student_submit'],
        };
        $attempt->update($changes);
        $before = $this->fileAnswerSnapshot();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $storage = $this->trackedStorage();

        $response = $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload());

        $this->assertSafeServerError($response);
        $this->assertRejectedUpload($storage, $before, $file->storage_key);
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function attemptCorruptions(): array
    {
        return array_map(fn (string $case): array => [$case], [
            'deadline', 'Blitz status', 'Blitz reason', 'submitted timestamp', 'finalized timestamp',
            'locked timestamp', 'finalization reason',
        ]);
    }

    #[DataProvider('attemptIdentityCorruptions')]
    public function test_attempt_identity_corruption_after_preliminary_storage_fails_as_an_invariant(string $field): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $replacementId = match ($field) {
            'institution_id' => Institution::factory()->create()->id,
            'student_id' => User::factory()->student($student->institution)->create()->id,
            'assessment_id' => Assessment::factory()->homework()->create(['institution_id' => $student->institution_id])->id,
            'assessment_student_id' => AssessmentStudent::factory()->create([
                'assessment_id' => $attempt->assessment_id,
                'student_id' => User::factory()->student($student->institution)->create()->id,
            ])->id,
        };
        if ($field === 'institution_id') {
            // These fixture-only DDL changes are restored by the surrounding RefreshDatabase transaction.
            foreach (['assessment_attempts_assessment_tenant_foreign', 'assessment_attempts_recipient_tenant_foreign',
                'assessment_attempts_student_tenant_foreign'] as $constraint) {
                DB::statement('alter table assessment_attempts drop constraint '.$constraint);
            }
            DB::statement('alter table attempt_answers drop constraint attempt_answers_attempt_tenant_foreign');
        }
        $before = $this->fileAnswerSnapshot();
        $corruptAttempt = null;
        $storage = $this->trackedStorage(function () use ($attempt, $field, $replacementId, &$corruptAttempt): void {
            DB::table('assessment_attempts')->where('id', $attempt->id)->update([$field => $replacementId]);
            $corruptAttempt = $attempt->fresh()->getAttributes();
        });

        $this->assertSafeServerError($this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload()));

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
        $this->assertNotNull($corruptAttempt);
        $this->assertSame($corruptAttempt, $attempt->fresh()->getAttributes());
    }

    public static function attemptIdentityCorruptions(): array
    {
        return [['institution_id'], ['student_id'], ['assessment_id'], ['assessment_student_id']];
    }

    #[DataProvider('lifecycleRejections')]
    public function test_final_lifecycle_precedence_compensates_even_with_a_terminal_attempt(string $state, bool $inactiveTopic, string $code): void
    {
        [$student, $homework, $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $attempt->update($this->terminalAttributes('submitted'));
        $before = $this->fileAnswerSnapshot();
        // Change lifecycle after preliminary authorization and physical storage.
        $storage = $this->trackedStorage(function () use ($homework, $state, $inactiveTopic): void {
            $homework->update(match ($state) {
                'closed' => ['status' => 'closed', 'closed_at' => now(), 'deadline_at' => now()],
                'archived' => ['status' => 'archived', 'closed_at' => now(), 'archived_at' => now(), 'deadline_at' => now()],
                'draft' => ['status' => 'draft', 'activated_at' => null, 'deadline_at' => now()],
                default => ['deadline_at' => now()],
            });
            if ($inactiveTopic) {
                $homework->assessment->topic->update(['status' => 'closed', 'closed_at' => now()]);
            }
        });

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload())
            ->assertConflict()->assertJsonPath('code', $code);

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
    }

    public static function lifecycleRejections(): array
    {
        return [
            'closed before deadline and terminal' => ['closed', false, 'task_closed'],
            'archived before deadline and terminal' => ['archived', false, 'task_archived'],
            'closed before inactive Topic' => ['closed', true, 'task_closed'],
            'archived before inactive Topic' => ['archived', true, 'task_archived'],
            'draft' => ['draft', false, 'task_not_active'],
            'inactive Topic before deadline' => ['active', true, 'task_not_active'],
            'deadline before terminal' => ['active', false, 'deadline_passed'],
        ];
    }

    #[DataProvider('deadlineBoundaries')]
    public function test_exact_and_past_deadlines_preserve_saved_file_and_reconcile_attempt(int $offset): void
    {
        [$student, $homework, $attempt, $question] = $this->fileAnswerContext();
        $attempt->update(['started_at' => now()->subHour()]);
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $deadline = now()->addSeconds($offset);
        $homework->update(['deadline_at' => $deadline]);
        $before = $this->fileAnswerSnapshot();
        $storage = $this->trackedStorage();

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload())
            ->assertConflict()->assertJsonPath('code', 'deadline_passed');

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
        $attempt->refresh();
        $this->assertSame(AssessmentAttemptStatus::Submitted, $attempt->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $attempt->finalization_reason);
        $this->assertTrue($deadline->equalTo($attempt->finalized_at));
        $this->assertTrue($deadline->equalTo($attempt->locked_at));
        $this->assertNull($attempt->submitted_at);
        $this->assertNull($attempt->earned_points);
        $this->assertNull($attempt->normalized_score);
        $this->assertNull($attempt->scoring_completed_at);
    }

    public static function deadlineBoundaries(): array
    {
        return ['exact' => [0], 'after' => [-1]];
    }

    public function test_setting_reduction_after_early_pass_rejects_from_final_locked_limit_and_compensates(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        InstitutionSetting::query()->where('institution_id', $student->institution_id)->update(['student_submission_max_mb' => 2]);
        $before = $this->fileAnswerSnapshot();
        $storage = $this->trackedStorage(fn () => InstitutionSetting::query()->where('institution_id', $student->institution_id)
            ->update(['student_submission_max_mb' => 1]));

        $this->fileAnswerRequest($student, $attempt, $question,
            $this->fileAnswerUpload(content: "%PDF-1.7\n".str_repeat('x', 1_048_576)))
            ->assertUnprocessable()->assertJsonPath('code', 'file_too_large');

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
    }

    #[DataProvider('mutationKinds')]
    public function test_database_failure_rolls_back_all_answer_graph_writes_and_compensates(bool $replacement): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $file = $replacement ? $this->savedFileAnswer($attempt, $question)[2] : null;
        $before = $this->fileAnswerSnapshot();
        $storage = $this->trackedStorage();
        // RefreshDatabase rolls back this test-only trigger and its function with the fixture.
        DB::unprepared(<<<'SQL'
            create function reject_student_file_answer_test_write() returns trigger language plpgsql as $$
            begin raise exception 'Controlled file persistence failure' using errcode = '23514'; end;
            $$;
            create trigger reject_student_file_answer_test_write before insert or update on files
            for each row execute function reject_student_file_answer_test_write();
        SQL);

        $this->assertSafeServerError($this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload('replacement.pdf')));

        $this->assertRejectedUpload($storage, $before, $file?->storage_key);
    }

    public static function mutationKinds(): array
    {
        return ['first upload' => [false], 'replacement' => [true]];
    }

    #[DataProvider('corruptGraphs')]
    public function test_corrupt_persisted_file_graph_is_never_compared_replaced_serialized_or_repaired(string $corruption, string $surface): void
    {
        [$student, $homework, $attempt, $question] = $this->fileAnswerContext();
        [$answer, $answerFile, $file] = $this->savedFileAnswer($attempt, $question);
        $originalStorageKey = $file->storage_key;
        $this->corruptFileGraph($corruption, $answer, $answerFile, $file, $student);
        $before = $this->fileAnswerSnapshot();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $storage = $this->trackedStorage();
        $isUpload = in_array($surface, ['identical upload', 'replacement'], true);
        $response = $isUpload
            ? $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload(
                content: $surface === 'replacement' ? "%PDF-1.7\nChanged submission" : null))
            : $this->readAttempt($student, $homework, $attempt, $surface === 'Start');

        if ($isUpload) {
            $response->assertConflict()->assertJsonPath('code', 'business_conflict');
            $this->assertRejectedUpload($storage, $before, $originalStorageKey);
        } else {
            $this->assertSafeServerError($response);
            $this->assertSame([], $storage->stored);
            $this->assertSame([], $storage->deleted);
            $this->assertSame($before, $this->fileAnswerSnapshot());
            $this->assertDatabaseCount('idempotency_records', 0);
        }
        foreach ([$file->id, $answerFile->id, $originalStorageKey, 'checksum_sha256', 'storage_disk', 'storage_key'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        Storage::disk('local')->assertExists($originalStorageKey);
    }

    public static function corruptGraphs(): array
    {
        $cases = [];
        foreach ([
            'AnswerFile Institution', 'AnswerFile answer linkage', 'AnswerFile file linkage', 'File Institution',
            'uploader', 'category', 'removed', 'null checksum', 'uppercase checksum', 'short checksum', 'nonhex checksum',
            'MIME', 'extension', 'zero size', 'over platform size', 'empty filename', 'long filename', 'filename extension',
            'empty disk', 'empty key', 'mixed family', 'missing File', 'missing AnswerFile',
            'checking status', 'awarded points', 'feedback', 'checker', 'checked at',
        ] as $corruption) {
            foreach (['identical upload', 'replacement', 'GET', 'Start'] as $surface) {
                $cases[$surface.' '.$corruption] = [$corruption, $surface];
            }
        }

        return $cases;
    }

    public function test_get_and_resume_use_canonical_metadata_and_preserve_historical_file_after_limit_reduction(): void
    {
        [$student, $homework, $attempt, $question] = $this->fileAnswerContext();
        InstitutionSetting::query()->where('institution_id', $student->institution_id)->update(['student_submission_max_mb' => 2]);
        $this->fileAnswerRequest($student, $attempt, $question,
            $this->fileAnswerUpload(content: "%PDF-1.7\n".str_repeat('x', 1_048_576)))->assertOk();
        $answer = AttemptAnswer::query()->sole();
        $answerFile = AnswerFile::query()->sole();
        $file = File::query()->sole();
        $unanswered = $this->answerQuestion($homework, 'file_based', 2);
        InstitutionSetting::query()->where('institution_id', $student->institution_id)->update(['student_submission_max_mb' => 1]);
        $before = $this->fileAnswerSnapshot();

        foreach ([false, true] as $resume) {
            $response = $this->readAttempt($student, $homework, $attempt, $resume)->assertOk()
                ->assertJsonCount(1, 'data.answers')->assertJsonPath('data.answers.0.question_id', $question->id)
                ->assertJsonPath('data.answers.0.type', 'file_based')
                ->assertJsonPath('data.answers.0.answer', ['file' => [
                    'id' => $file->id, 'original_name' => 'answer.pdf', 'extension' => 'pdf', 'size_bytes' => $file->size_bytes,
                ]]);
            $this->assertNotContains($unanswered->id, array_column($response->json('data.answers'), 'question_id'));
            $this->assertNoFileAnswerSecrets($response->json());
            $this->assertStringNotContainsString('%PDF', $response->getContent());
            $this->assertSame($before, $this->fileAnswerSnapshot());
        }

        $this->fileAnswerRequest($student, $attempt, $question,
            $this->fileAnswerUpload(content: "%PDF-1.7\n".str_repeat('x', 1_048_576)))
            ->assertUnprocessable()->assertJsonPath('code', 'file_too_large');
        $this->assertSame($before, $this->fileAnswerSnapshot());
        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload())->assertOk();
        $this->assertSame($answer->id, AttemptAnswer::query()->sole()->id);
        $this->assertSame($answerFile->id, AnswerFile::query()->sole()->id);
        $this->assertSame($file->id, File::query()->sole()->id);
    }

    public function test_fixed_new_start_key_rolls_back_on_corruption_then_completes_after_fixture_repair_and_replays_without_churn(): void
    {
        [$student, $homework, $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $validState = $this->fileAnswerSnapshot();
        DB::table('files')->where('id', $file->id)->update(['checksum_sha256' => null]);
        $corruptState = $this->fileAnswerSnapshot();
        $attemptBefore = $attempt->getAttributes();
        $key = '83103811-f114-4942-a6f8-160fda035e60';

        for ($retry = 0; $retry < 2; $retry++) {
            $this->travel(1)->minutes();
            $this->assertSafeServerError($this->readAttempt($student, $homework, $attempt, true, $key));
            $this->assertDatabaseMissing('idempotency_records', ['idempotency_key' => $key]);
            $this->assertSame($corruptState, $this->fileAnswerSnapshot());
            $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        }
        DB::table('files')->where('id', $file->id)->update(['checksum_sha256' => $file->checksum_sha256]);
        $this->assertSame($validState, $this->fileAnswerSnapshot());
        $response = $this->readAttempt($student, $homework, $attempt, true, $key)->assertOk()
            ->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.answers.0.answer.file.id', $file->id);
        $this->assertNoFileAnswerSecrets($response->json());
        $record = IdempotencyRecord::query()->where('idempotency_key', $key)->sole();
        $this->assertSame('student.homework.attempt.start', $record->operation->value);
        $this->assertSame($student->institution_id, $record->institution_id);
        $this->assertSame($student->id, $record->user_id);
        $this->assertSame($attempt->id, $record->result_resource_id);
        $this->assertSame(200, $record->response_status);
        $this->assertNotNull($record->completed_at);
        $recordBefore = $record->getAttributes();
        $this->travel(1)->minutes();

        $this->readAttempt($student, $homework, $attempt, true, $key)->assertOk()
            ->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.answers', $response->json('data.answers'));

        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
        $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        $this->assertSame($validState, $this->fileAnswerSnapshot());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());

        DB::table('files')->where('id', $file->id)->update(['checksum_sha256' => null]);
        $this->assertSafeServerError($this->readAttempt($student, $homework, $attempt, true, $key));
        $this->assertSame($recordBefore, $record->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    private function corruptFileGraph(string $corruption, AttemptAnswer $answer, AnswerFile $answerFile, File $file, User $student): void
    {
        // PostgreSQL DDL is transactional: RefreshDatabase restores every changed constraint/type.
        $drop = fn (string $table, string $constraint) => DB::statement('alter table '.$table.' drop constraint '.$constraint);
        if ($corruption === 'AnswerFile Institution') {
            $drop('answer_files', 'answer_files_answer_tenant_foreign');
            $drop('answer_files', 'answer_files_file_tenant_foreign');
            DB::table('answer_files')->where('id', $answerFile->id)->update(['institution_id' => Institution::factory()->create()->id]);
        } elseif ($corruption === 'AnswerFile answer linkage') {
            $drop('answer_files', 'answer_files_answer_tenant_foreign');
            DB::table('answer_files')->where('id', $answerFile->id)->update(['answer_id' => (string) Str::uuid()]);
        } elseif ($corruption === 'AnswerFile file linkage') {
            $drop('answer_files', 'answer_files_file_tenant_foreign');
            DB::table('answer_files')->where('id', $answerFile->id)->update(['file_id' => (string) Str::uuid()]);
        } elseif ($corruption === 'missing File') {
            $drop('answer_files', 'answer_files_file_tenant_foreign');
            DB::table('files')->where('id', $file->id)->delete();
        } elseif ($corruption === 'missing AnswerFile') {
            $answerFile->delete();
        } elseif ($corruption === 'mixed family') {
            AnswerBooleanValue::factory()->create(['answer_id' => $answer->id]);
        } elseif (in_array($corruption, ['checking status', 'awarded points', 'feedback', 'checker', 'checked at'], true)) {
            DB::table('attempt_answers')->where('id', $answer->id)->update(match ($corruption) {
                'checking status' => ['checking_status' => 'waiting_for_teacher_review'],
                'awarded points' => ['awarded_points' => '0'],
                'feedback' => ['feedback' => 'Private review feedback'],
                'checker' => ['checked_by_user_id' => $student->id],
                'checked at' => ['checked_at' => now()],
            });
        } else {
            foreach (match ($corruption) {
                'File Institution' => [['files', 'files_uploader_tenant_foreign'], ['answer_files', 'answer_files_file_tenant_foreign']],
                'short checksum', 'nonhex checksum' => [['files', 'files_checksum_sha256_check']],
                'extension' => [['files', 'files_extension_check']],
                'zero size' => [['files', 'files_size_positive_check']],
                'over platform size' => [['files', 'files_category_size_limit_check']],
                'empty filename' => [['files', 'files_original_name_not_empty_check']],
                'empty disk' => [['files', 'files_storage_disk_not_empty_check']],
                'empty key' => [['files', 'files_storage_key_not_empty_check']],
                default => [],
            } as [$table, $constraint]) {
                $drop($table, $constraint);
            }
            if ($corruption === 'long filename') {
                DB::statement('alter table files alter column original_name type text');
            }
            DB::table('files')->where('id', $file->id)->update(match ($corruption) {
                'File Institution' => ['institution_id' => Institution::factory()->create()->id],
                'uploader' => ['uploaded_by_user_id' => User::factory()->student($student->institution)->create()->id],
                'category' => ['category' => 'learning_material'],
                'removed' => ['removed_at' => now()],
                'null checksum' => ['checksum_sha256' => null],
                'uppercase checksum' => ['checksum_sha256' => strtoupper($file->checksum_sha256)],
                'short checksum' => ['checksum_sha256' => 'abc'],
                'nonhex checksum' => ['checksum_sha256' => str_repeat('z', 64)],
                'MIME' => ['mime_type' => 'application/octet-stream'],
                'extension' => ['extension' => 'zip'],
                'zero size' => ['size_bytes' => 0],
                'over platform size' => ['size_bytes' => 15_728_641],
                'empty filename' => ['original_name' => ''],
                'long filename' => ['original_name' => str_repeat('ж', 497).'.pdf'],
                'filename extension' => ['original_name' => 'answer.docx'],
                'empty disk' => ['storage_disk' => ''],
                'empty key' => ['storage_key' => ''],
            });
        }
    }

    private function terminalAttributes(string $status): array
    {
        return ['status' => $status, 'submitted_at' => now(), 'finalized_at' => now(),
            'locked_at' => now(), 'finalization_reason' => 'student_submit'];
    }

    private function readAttempt(User $student, HomeworkAssignment $homework, AssessmentAttempt $attempt, bool $resume, ?string $key = null): TestResponse
    {
        return $this->answerHttp($student, $resume ? 'POST' : 'GET', $resume
            ? '/api/v1/student/homework/'.$homework->assessment_id.'/attempts'
            : '/api/v1/student/attempts/'.$attempt->id, headers: $resume ? ['HTTP_IDEMPOTENCY_KEY' => $key ?? (string) Str::uuid()] : []);
    }

    private function trackedStorage(?Closure $afterStore = null): PrivateFileStorage
    {
        $storage = new class($afterStore) extends PrivateFileStorage
        {
            public array $stored = [];

            public array $deleted = [];

            public function __construct(private readonly ?Closure $afterStore) {}

            public function store(UploadedFile $upload, string $storageKey): string
            {
                $disk = parent::store($upload, $storageKey);
                $this->stored[] = [$disk, $storageKey];
                ($this->afterStore)?->__invoke();

                return $disk;
            }

            public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
            {
                $this->deleted[] = [$diskName, $storageKey];

                return parent::deleteBestEffort($diskName, $storageKey, $operation, $fileId);
            }
        };
        $this->app->instance(PrivateFileStorage::class, $storage);

        return $storage;
    }

    private function assertRejectedUpload(PrivateFileStorage $storage, array $before, ?string $originalStorageKey = null): void
    {
        $this->assertCount(1, $storage->stored);
        $this->assertSame($storage->stored, $storage->deleted, 'Every rejected new blob must receive exactly one cleanup attempt.');
        Storage::disk($storage->stored[0][0])->assertMissing($storage->stored[0][1]);
        $this->assertSame($before, $this->fileAnswerSnapshot());
        if ($originalStorageKey !== null) {
            Storage::disk('local')->assertExists($originalStorageKey);
        }
    }

    private function assertSafeServerError(TestResponse $response): void
    {
        $response->assertStatus(500)->assertExactJson([
            'message' => 'An unexpected server error occurred.', 'code' => 'server_error', 'errors' => [],
        ]);
    }
}
