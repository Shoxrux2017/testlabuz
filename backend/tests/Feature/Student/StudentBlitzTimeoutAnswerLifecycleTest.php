<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Models\AssessmentAttempt;
use App\Support\Files\PrivateFileStorage;
use Closure;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzTimeoutAnswerLifecycleTest extends TestCase
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

    #[DataProvider('deadlineBoundaries')]
    public function test_typed_write_committed_before_deadline_is_frozen_when_an_expired_replacement_reconciles(string $mode, int $delay): void
    {
        [$student, $blitz, $attempt] = $this->answerContext($mode);
        $question = $this->answerQuestion($blitz, 'short_written');
        $this->answerQuestion($blitz, 'open_written', 2);
        $this->travelTo($attempt->deadline_at->copy()->subSecond());
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => "  Last eligible answer\n"])
            ->assertOk()->assertJsonPath('data.answer.text', "  Last eligible answer\n");
        $answersBefore = $this->answerSnapshot();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->travelTo($attempt->deadline_at->copy()->addSeconds($delay));

        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'Expired replacement'])
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $this->assertTimeoutPreservesExecutionInputs($attempt, $attemptBefore);
        $this->assertSame($answersBefore, $this->answerSnapshot());
        $this->assertDatabaseCount('attempt_answers', 1);
        $frozen = $attempt->fresh()->getAttributes();
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => ''])
            ->assertConflict()->assertJsonPath('code', 'attempt_not_editable');
        $this->assertSame($answersBefore, $this->answerSnapshot());
        $this->assertSame($frozen, $attempt->fresh()->getAttributes());
    }

    #[DataProvider('deadlineBoundaries')]
    public function test_file_expiry_after_staging_compensates_new_blob_before_reconciliation_and_preserves_current_file(string $mode, int $delay): void
    {
        [$student, $blitz, $attempt] = $this->answerContext($mode);
        $question = $this->answerQuestion($blitz, 'file_based');
        $this->answerQuestion($blitz, 'open_written', 2);
        $originalContent = "%PDF-1.7\nFrozen original content";
        [, , $file] = $this->savedFileAnswer($attempt, $question, $originalContent);
        $answersBefore = $this->fileAnswerSnapshot();
        $attemptBefore = $attempt->getAttributes();
        $this->travelTo($attempt->deadline_at->copy()->subSecond());
        $storage = new class(fn () => $this->travelTo($attempt->deadline_at->copy()->addSeconds($delay)), $attempt->id) extends PrivateFileStorage
        {
            public array $stored = [];

            public array $deleted = [];

            public ?AssessmentAttemptStatus $statusAtCleanup = null;

            public function __construct(private readonly Closure $afterStore, private readonly string $attemptId) {}

            public function store(UploadedFile $upload, string $storageKey): string
            {
                $disk = parent::store($upload, $storageKey);
                $this->stored[] = [$disk, $storageKey];
                ($this->afterStore)();

                return $disk;
            }

            public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
            {
                $this->deleted[] = [$diskName, $storageKey];
                $this->statusAtCleanup = AssessmentAttempt::query()->findOrFail($this->attemptId)->status;

                return parent::deleteBestEffort($diskName, $storageKey, $operation, $fileId);
            }
        };
        $this->app->instance(PrivateFileStorage::class, $storage);

        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload('replacement.pdf', "%PDF-1.7\nLate replacement"))
            ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');

        $this->assertCount(1, $storage->stored);
        $this->assertSame($storage->stored, $storage->deleted);
        $this->assertSame(AssessmentAttemptStatus::InProgress, $storage->statusAtCleanup);
        Storage::disk('local')->assertMissing($storage->stored[0][1]);
        $this->assertSame([$file->storage_key], Storage::disk('local')->allFiles());
        $this->assertSame($originalContent, Storage::disk('local')->get($file->storage_key));
        $this->assertSame($answersBefore, $this->fileAnswerSnapshot());
        $this->assertTimeoutPreservesExecutionInputs($attempt, $attemptBefore);
        $this->assertDatabaseCount('files', 1);
        $this->assertDatabaseCount('attempt_answers', 1);
    }

    public static function deadlineBoundaries(): array
    {
        return [['individual', 0], ['individual', 180], ['synchronized', 0], ['synchronized', 180]];
    }

    private function assertTimeoutPreservesExecutionInputs(AssessmentAttempt $attempt, array $before): void
    {
        $current = $attempt->fresh();
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $current->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::TimeoutAutoSubmit, $current->finalization_reason);
        $this->assertNull($current->submitted_at);
        $this->assertTrue($attempt->deadline_at->equalTo($current->finalized_at));
        $this->assertTrue($attempt->deadline_at->equalTo($current->locked_at));
        foreach (['started_at', 'deadline_at', 'attempt_number', 'assessment_student_id', 'student_id',
            'official_score_eligible', 'possible_points', 'earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertSame($before[$field], $current->getAttributes()[$field], $field);
        }
    }
}
