<?php

namespace Tests\Feature\Files;

use App\Actions\Files\DownloadLearningMaterialFile;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Models\AnswerFile;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\GroupStudentMembership;
use App\Models\Institution;
use App\Models\User;
use App\Support\Files\ProtectedFileDownload;
use App\Support\Files\ProtectedStudentSubmissionAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkAnswerContext;
use Tests\TestCase;

class ProtectedStudentSubmissionDownloadApiTest extends TestCase
{
    use BuildsStudentHomeworkAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
        Storage::fake('local');
    }

    public function test_owner_downloads_stored_bytes_with_canonical_mime_attachment_and_private_headers(): void
    {
        [$student, , , , $file, $bytes] = $this->submission();
        $file->update(['original_name' => 'Мой ответ.PDF']);
        $before = $file->fresh()->getAttributes();
        $transactionLevel = DB::transactionLevel();

        $response = $this->answerHttp($student, 'GET', $this->uri($file->id))
            ->assertOk()->assertHeader('Content-Type', 'application/pdf')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertStreamedContent($bytes);

        $this->assertSame($transactionLevel, DB::transactionLevel());
        $this->assertSame($before, $file->fresh()->getAttributes());
        $this->assertStringContainsString('private', $response->headers->get('Cache-Control'));
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $this->assertStringStartsWith('attachment;', $response->headers->get('Content-Disposition'));
        $this->assertStringContainsString("filename*=utf-8''", $response->headers->get('Content-Disposition'));
        $headers = json_encode($response->headers->all(), JSON_THROW_ON_ERROR);
        foreach ([$file->storage_key, 'storage_disk', 'storage_key', 'checksum_sha256', 'uploaded_by_user_id'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $headers);
        }
    }

    public function test_owner_can_download_after_finalization_deadline_and_ending_group_membership(): void
    {
        [$student, $homework, $attempt, , $file, $bytes] = $this->submission();
        $assessment = $homework->assessment()->firstOrFail();
        $topic = $assessment->topic()->firstOrFail();
        $membership = GroupStudentMembership::factory()->create([
            'institution_id' => $student->institution_id,
            'group_id' => $topic->group_id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $assessment->teacher_id,
            'started_at' => now()->subDay(),
        ]);
        $attempt->update([
            'status' => AssessmentAttemptStatus::Submitted,
            'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
        ]);
        $membership->update(['ended_at' => now()]);
        $homework->update(['deadline_at' => now()->subSecond()]);

        foreach (['active', 'closed', 'archived'] as $status) {
            $homework->update(['status' => $status, 'closed_at' => $status === 'active' ? null : now(),
                'archived_at' => $status === 'archived' ? now() : null]);
            $this->answerHttp($student, 'GET', $this->uri($file->id))->assertOk()->assertStreamedContent($bytes);
        }
    }

    public function test_other_student_foreign_student_and_teacher_receive_privacy_safe_not_found(): void
    {
        [$student, $homework, , , $file] = $this->submission();
        $otherStudent = User::factory()->student($student->institution)->create(['must_change_password' => false]);
        $foreignStudent = User::factory()->student(Institution::factory()->create())->create(['must_change_password' => false]);
        $teacher = $homework->assessment()->firstOrFail()->teacher()->firstOrFail();
        $teacher->update(['must_change_password' => false]);

        foreach ([$otherStudent, $foreignStudent, $teacher] as $actor) {
            $response = $this->answerHttp($actor, 'GET', $this->uri($file->id))
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertStringNotContainsString($file->id, $response->getContent());
            $this->assertStringNotContainsString($file->storage_key, $response->getContent());
        }
    }

    public function test_attempt_ownership_does_not_authorize_a_file_uploaded_by_another_student(): void
    {
        [$student, , , , $file] = $this->submission();
        $otherStudent = User::factory()->student($student->institution)->create(['must_change_password' => false]);
        $file->update(['uploaded_by_user_id' => $otherStudent->id]);

        foreach ([$student, $otherStudent] as $actor) {
            $this->answerHttp($actor, 'GET', $this->uri($file->id))
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_unlinked_removed_and_non_homework_file_chains_are_not_found(): void
    {
        [$student, $homework, , $link, $file] = $this->submission();
        $orphan = File::factory()->studentSubmission()->create([
            'institution_id' => $student->institution_id, 'uploaded_by_user_id' => $student->id,
        ]);
        $this->answerHttp($student, 'GET', $this->uri($orphan->id))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');

        $file->update(['removed_at' => now()]);
        $this->answerHttp($student, 'GET', $this->uri($file->id))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $file->update(['removed_at' => null]);
        $homework->update(['status' => 'draft', 'activated_at' => null]);
        $this->answerHttp($student, 'GET', $this->uri($file->id))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $homework->update(['status' => 'active', 'activated_at' => now()]);
        $link->answer->question->update(['type' => 'open_written']);
        $this->answerHttp($student, 'GET', $this->uri($file->id))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
    }

    #[DataProvider('brokenLinkCases')]
    public function test_broken_answer_file_chain_is_not_found_without_repair_or_storage_disclosure(string $corruption): void
    {
        [$student, , $attempt, $link, $file, $bytes] = $this->submission();
        $foreignInstitution = Institution::factory()->create();
        DB::beginTransaction();

        try {
            // The savepoint rollback restores both fixture rows and any locally dropped constraints.
            if ($corruption === 'institution') {
                DB::statement('alter table answer_files drop constraint answer_files_answer_tenant_foreign');
                DB::statement('alter table answer_files drop constraint answer_files_file_tenant_foreign');
                DB::table('answer_files')->where('id', $link->id)->update(['institution_id' => $foreignInstitution->id]);
            } elseif ($corruption === 'answer') {
                DB::statement('alter table answer_files drop constraint answer_files_answer_tenant_foreign');
                DB::table('answer_files')->where('id', $link->id)->update(['answer_id' => (string) Str::uuid()]);
            } elseif ($corruption === 'file') {
                DB::statement('alter table answer_files drop constraint answer_files_file_tenant_foreign');
                DB::table('answer_files')->where('id', $link->id)->update(['file_id' => (string) Str::uuid()]);
            } elseif ($corruption === 'missing_file') {
                DB::statement('alter table answer_files drop constraint answer_files_file_tenant_foreign');
                DB::table('files')->where('id', $file->id)->delete();
            } else {
                $link->delete();
            }

            $before = $this->downloadSnapshot();
            $response = $this->answerHttp($student, 'GET', $this->uri($file->id))
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertSame($before, $this->downloadSnapshot());
            $this->assertSame($bytes, Storage::disk('local')->get($file->storage_key));
            foreach ([$attempt->id, $link->id, $file->id, $file->storage_key, 'storage_disk', 'storage_key'] as $hidden) {
                $this->assertStringNotContainsString($hidden, $response->getContent());
            }
        } finally {
            DB::rollBack();
        }
    }

    public static function brokenLinkCases(): array
    {
        return ['wrong institution' => ['institution'], 'missing parent answer' => ['answer'],
            'wrong linked file' => ['file'], 'missing linked file' => ['missing_file'], 'missing answer file' => ['missing_link']];
    }

    public function test_learning_material_category_dispatches_to_existing_download_action(): void
    {
        [$student, , , , $file] = $this->submission();
        $file->update(['category' => FileCategory::LearningMaterial]);
        $stream = fopen('php://temp', 'w+b');
        $this->assertIsResource($stream);
        fwrite($stream, 'learning-material-action');
        rewind($stream);
        $action = $this->createMock(DownloadLearningMaterialFile::class);
        $action->expects($this->once())->method('__invoke')
            ->with($this->callback(fn (User $actor): bool => $actor->id === $student->id), $file->id)
            ->willReturn(new ProtectedFileDownload($stream, 'application/pdf', 'material.pdf', 'pdf'));
        $this->app->instance(DownloadLearningMaterialFile::class, $action);

        $this->answerHttp($student, 'GET', $this->uri($file->id))
            ->assertOk()->assertStreamedContent('learning-material-action');
    }

    public function test_authorized_missing_blob_returns_exact_safe_file_not_available(): void
    {
        [$student, , , , $file] = $this->submission();
        Storage::disk('local')->delete($file->storage_key);

        $this->answerHttp($student, 'GET', $this->uri($file->id))->assertStatus(500)->assertExactJson([
            'message' => 'The requested file is currently unavailable.',
            'code' => 'file_not_available', 'errors' => [],
        ]);
    }

    public function test_malformed_uuid_query_and_body_preserve_download_validation(): void
    {
        [$student, , , , $file] = $this->submission();
        $this->answerHttp($student, 'GET', $this->uri('not-a-uuid'))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->answerHttp($student, 'GET', $this->uri($file->id).'?unexpected=value')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed')->assertJsonValidationErrors(['unexpected']);
        $this->answerHttp($student, 'GET', $this->uri($file->id), '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed')->assertJsonValidationErrors(['body']);
    }

    public function test_shared_lock_reverifies_the_same_authorized_file_chain(): void
    {
        [$student, , , $link, $file] = $this->submission();
        $access = $this->app->make(ProtectedStudentSubmissionAccess::class);
        $target = $access->resolve($student, $file->id);
        $link->delete();

        $this->expectException(NotFoundHttpException::class);
        DB::transaction(fn () => $access->lock($student, $target));
    }

    private function submission(): array
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'file_based');
        $answer = AttemptAnswer::factory()->create([
            'institution_id' => $student->institution_id, 'attempt_id' => $attempt->id, 'question_id' => $question->id,
        ]);
        $bytes = "%PDF-1.7\nStudent answer\n%%EOF\n";
        $file = File::factory()->studentSubmission()->create([
            'institution_id' => $student->institution_id, 'uploaded_by_user_id' => $student->id,
            'original_name' => 'answer.pdf', 'extension' => FileExtension::Pdf, 'mime_type' => 'application/pdf',
            'storage_disk' => 'local', 'storage_key' => 'student-submissions/'.$student->institution_id.'/'.$attempt->id.'/'.$question->id.'/'.Str::uuid().'.pdf',
            'size_bytes' => strlen($bytes), 'checksum_sha256' => hash('sha256', $bytes), 'removed_at' => null,
        ]);
        $link = AnswerFile::factory()->create([
            'institution_id' => $student->institution_id, 'answer_id' => $answer->id, 'file_id' => $file->id,
        ]);
        Storage::disk('local')->put($file->storage_key, $bytes);

        return [$student, $homework, $attempt, $link, $file, $bytes];
    }

    private function downloadSnapshot(): array
    {
        $snapshot = [];
        foreach (['assessment_attempts', 'attempt_answers', 'answer_files', 'files'] as $table) {
            $snapshot[$table] = DB::table($table)->orderBy('id')->get()->map(fn (object $row): array => (array) $row)->all();
        }

        return $snapshot;
    }

    private function uri(string $fileId): string
    {
        return '/api/v1/files/'.$fileId.'/download';
    }
}
