<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Models\InstitutionSetting;
use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use Closure;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzFileAnswerLifecycleTest extends TestCase
{
    use BuildsStudentBlitzAnswerContext, BuildsStudentHomeworkFileAnswerContext, RefreshDatabase {
        BuildsStudentBlitzAnswerContext::answerContext insteadof BuildsStudentHomeworkFileAnswerContext;
    }

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
        config(['filesystems.private_files_disk' => 'local']);
    }

    public function test_foreign_or_unowned_attempt_never_stages_a_blob(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [$foreign, , $foreignAttempt, $foreignQuestion] = $this->fileAnswerContext();
        $other = User::factory()->student($student->institution)->create(['must_change_password' => false]);
        $storage = $this->trackedStorage();
        $before = $this->fileAnswerSnapshot();

        foreach ([[$other, $attempt, $question], [$student, $foreignAttempt, $foreignQuestion], [$foreign, $attempt, $question]] as [$actor, $target, $targetQuestion]) {
            $this->fileAnswerRequest($actor, $target, $targetQuestion, $this->fileAnswerUpload())
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertSame([], $storage->stored);
        $this->assertSame([], Storage::disk('local')->allFiles());
        $this->assertSame($before, $this->fileAnswerSnapshot());
    }

    public function test_active_file_write_preserves_the_attempt_and_does_not_finalize_or_score(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $before = $attempt->getAttributes();

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload())->assertOk();

        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('attempt_answers', 1);
        $this->assertDatabaseCount('files', 1);
    }

    #[DataProvider('rejections')]
    public function test_locked_current_state_rejects_a_staged_replacement_and_keeps_previous_file(string $state, string $expectedCode): void
    {
        [$student, $blitz, $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $before = $this->fileAnswerSnapshot();
        $attemptAfterChange = null;
        $storage = $this->trackedStorage(function () use ($state, $blitz, $attempt, &$attemptAfterChange): void {
            if ($state === 'terminal' || $state === 'terminal after deadline') {
                $this->terminateStudentBlitzAttempt($attempt);
            }
            if (in_array($state, ['closed', 'archived', 'draft', 'scheduled'], true)) {
                $blitz->update(match ($state) {
                    'closed' => ['status' => 'closed', 'closed_at' => now()],
                    'archived' => ['status' => 'archived', 'closed_at' => now(), 'archived_at' => now()],
                    'draft', 'scheduled' => ['status' => $state, 'activated_at' => null, 'activated_by_user_id' => null,
                        'timer_start_mode_snapshot' => null, 'synchronized_ends_at' => null,
                        'scheduled_at' => $state === 'scheduled' ? now()->addHour() : null],
                });
            } elseif ($state === 'inactive Topic') {
                $blitz->assessment->topic->update(['status' => 'closed', 'closed_at' => now()]);
            }
            if (in_array($state, ['exact deadline', 'after deadline', 'terminal after deadline'], true)) {
                $this->travelTo($attempt->deadline_at->copy()->addSeconds($state === 'exact deadline' ? 0 : 1));
            }
            $attemptAfterChange = $attempt->fresh()->getAttributes();
        });

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload('replacement.pdf'))
            ->assertConflict()->assertJsonPath('code', $expectedCode);

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
        if (in_array($state, ['exact deadline', 'after deadline'], true)) {
            $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $attempt->fresh()->status);
            $this->assertTrue($attempt->deadline_at->equalTo($attempt->fresh()->finalized_at));
            $this->assertTrue($attempt->deadline_at->equalTo($attempt->fresh()->locked_at));
            $transitionFields = array_flip(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at']);
            $this->assertSame(array_diff_key($attemptAfterChange, $transitionFields), array_diff_key($attempt->fresh()->getAttributes(), $transitionFields));
        } else {
            $this->assertSame($attemptAfterChange, $attempt->fresh()->getAttributes());
        }
    }

    public static function rejections(): array
    {
        return [
            ['terminal', 'attempt_not_editable'], ['terminal after deadline', 'attempt_not_editable'],
            ['closed', 'blitz_not_active'], ['archived', 'blitz_not_active'],
            ['draft', 'blitz_not_active'], ['scheduled', 'blitz_not_active'],
            ['inactive Topic', 'blitz_not_active'],
            ['exact deadline', 'blitz_time_expired'], ['after deadline', 'blitz_time_expired'],
        ];
    }

    public function test_setting_lowered_after_staging_rejects_against_locked_current_limit(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        InstitutionSetting::query()->whereKey($student->institution_id)->update(['student_submission_max_mb' => 2]);
        $before = $this->fileAnswerSnapshot();
        $storage = $this->trackedStorage(fn () => InstitutionSetting::query()->whereKey($student->institution_id)
            ->update(['student_submission_max_mb' => 1]));

        $this->fileAnswerRequest($student, $attempt, $question,
            $this->fileAnswerUpload(content: "%PDF-1.7\n".str_repeat('x', 1_048_576)))
            ->assertUnprocessable()->assertJsonPath('code', 'file_too_large');

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
    }

    #[DataProvider('mutationKinds')]
    public function test_database_rollback_compensates_staged_blob_exactly_once(bool $replacement): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $file = $replacement ? $this->savedFileAnswer($attempt, $question)[2] : null;
        $before = $this->fileAnswerSnapshot();
        $storage = $this->trackedStorage();
        DB::unprepared(<<<'SQL'
            create function reject_blitz_file_answer_test_write() returns trigger language plpgsql as $$
            begin raise exception 'Controlled file persistence failure' using errcode = '23514'; end;
            $$;
            create trigger reject_blitz_file_answer_test_write before insert or update on files
            for each row execute function reject_blitz_file_answer_test_write();
        SQL);

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload('replacement.pdf'))
            ->assertStatus(500)->assertExactJson([
                'message' => 'An unexpected server error occurred.', 'code' => 'server_error', 'errors' => [],
            ]);

        $this->assertRejectedUpload($storage, $before, $file?->storage_key);
    }

    public static function mutationKinds(): array
    {
        return [[false], [true]];
    }

    public function test_corrupt_existing_file_is_not_repaired_and_the_staged_replacement_is_cleaned(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $file->update(['uploaded_by_user_id' => User::factory()->student($student->institution)->create()->id]);
        $before = $this->fileAnswerSnapshot();
        $storage = $this->trackedStorage();

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload('replacement.pdf'))
            ->assertConflict()->assertJsonPath('code', 'business_conflict');

        $this->assertRejectedUpload($storage, $before, $file->storage_key);
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

    private function assertRejectedUpload(PrivateFileStorage $storage, array $before, ?string $originalStorageKey): void
    {
        $this->assertCount(1, $storage->stored);
        $this->assertSame($storage->stored, $storage->deleted, 'A rejected new blob receives exactly one cleanup attempt.');
        Storage::disk($storage->stored[0][0])->assertMissing($storage->stored[0][1]);
        $this->assertSame($before, $this->fileAnswerSnapshot());
        if ($originalStorageKey !== null) {
            Storage::disk('local')->assertExists($originalStorageKey);
        }
    }
}
