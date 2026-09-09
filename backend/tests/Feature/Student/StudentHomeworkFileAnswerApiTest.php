<?php

namespace Tests\Feature\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\FileCategory;
use App\Exceptions\Files\FileUploadFailedException;
use App\Models\AnswerFile;
use App\Models\Assessment;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Support\Files\PrivateFileStorage;
use App\Support\Files\StudentSubmissionUploadPolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;
use ZipArchive;

class StudentHomeworkFileAnswerApiTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext, RefreshDatabase;

    private array $temporaryFiles = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
        Storage::fake('local');
        config(['filesystems.private_files_disk' => 'local']);
    }

    protected function tearDown(): void
    {
        foreach ($this->temporaryFiles as $path) {
            if (is_file($path)) {
                unlink($path);
            }
        }
        parent::tearDown();
    }

    #[DataProvider('formats')]
    public function test_each_real_binary_format_creates_one_private_pending_answer_and_resumes_only_safe_metadata(string $extension, string $mime): void
    {
        [$student, $homework, $attempt, $question] = $this->fileAnswerContext();
        $attemptBefore = $attempt->getAttributes();
        $upload = $this->formatUpload($extension);
        $response = $this->fileAnswerRequest($student, $attempt, $question, $upload)->assertOk();
        $answer = AttemptAnswer::query()->sole();
        $answerFile = AnswerFile::query()->sole();
        $file = File::query()->sole();
        $canonical = ['file' => ['id' => $file->id, 'original_name' => $upload->getClientOriginalName(),
            'extension' => $extension, 'size_bytes' => $upload->getSize()]];

        $response->assertExactJson(['data' => ['question_id' => $question->id, 'type' => 'file_based',
            'answer' => $canonical, 'updated_at' => '2026-09-09T12:00:00Z']]);
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->checking_status);
        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
            $this->assertNull($answer->{$field});
        }
        $this->assertSame([$student->institution_id, $attempt->id, $question->id],
            [$answer->institution_id, $answer->attempt_id, $answer->question_id]);
        $this->assertSame([$student->institution_id, $answer->id, $file->id],
            [$answerFile->institution_id, $answerFile->answer_id, $answerFile->file_id]);
        $this->assertSame([$student->institution_id, $student->id, FileCategory::StudentSubmission],
            [$file->institution_id, $file->uploaded_by_user_id, $file->category]);
        $this->assertNull($file->removed_at);
        $this->assertSame($mime, $file->mime_type);
        $this->assertSame(hash_file('sha256', $upload->getPathname()), $file->checksum_sha256);
        $prefix = 'student-submissions/'.$student->institution_id.'/'.$attempt->id.'/'.$question->id.'/';
        $this->assertStringStartsWith($prefix, $file->storage_key);
        $this->assertTrue(Str::isUuid(pathinfo(substr($file->storage_key, strlen($prefix)), PATHINFO_FILENAME)));
        $this->assertSame('local', $file->storage_disk);
        $this->assertSame(file_get_contents($upload->getPathname()), Storage::disk('local')->get($file->storage_key));
        foreach ([$answer->created_at, $answer->updated_at, $answerFile->created_at, $file->created_at, $file->updated_at] as $timestamp) {
            $this->assertTrue($timestamp->equalTo(now()));
        }
        $get = $this->answerHttp($student, 'GET', '/api/v1/student/attempts/'.$attempt->id)
            ->assertOk()->assertJsonPath('data.answers', [$response->json('data')]);
        $start = $this->answerHttp($student, 'POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts',
            headers: ['HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid()])->assertOk()
            ->assertJsonPath('data.answers', [$response->json('data')]);
        foreach ([$response->json(), $get->json('data.answers'), $start->json('data.answers')] as $payload) {
            $this->assertNoFileAnswerSecrets($payload);
        }
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function formats(): array
    {
        return [
            ['pdf', 'application/pdf'],
            ['docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
            ['ppt', 'application/vnd.ms-powerpoint'],
            ['pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
        ];
    }

    public function test_content_mismatch_invalid_binary_and_unsupported_extension_leave_no_rows_or_blobs(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        foreach ([
            $this->fileAnswerUpload('spoof.docx'),
            $this->formatUpload('docx', 'spoof.pdf'),
            $this->fileAnswerUpload('invalid.pdf', 'arbitrary bytes'),
            $this->fileAnswerUpload('unsupported.txt'),
        ] as $upload) {
            $this->fileAnswerRequest($student, $attempt, $question, $upload)
                ->assertUnprocessable()->assertJsonPath('code', 'unsupported_file_type');
        }
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertDatabaseCount('answer_files', 0);
        $this->assertDatabaseCount('files', 0);
        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    #[DataProvider('invalidMultipart')]
    public function test_strict_multipart_rejects_invalid_shape_without_clearing_an_existing_answer(string $case): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $this->savedFileAnswer($attempt, $question);
        $snapshot = $this->fileAnswerSnapshot();
        $blobs = Storage::disk('local')->allFiles();
        $parameters = ['type' => 'file_based'];
        $files = ['file' => $this->fileAnswerUpload()];
        $contentType = 'multipart/form-data';
        $query = '';
        match ($case) {
            'missing file' => $files = [],
            'empty file' => $files = ['file' => $this->fileAnswerUpload(content: '')],
            'missing type' => $parameters = [],
            'non-file type' => $parameters = ['type' => 'true_false'],
            'array type' => $parameters = ['type' => ['file_based']],
            'unknown field' => $parameters['storage_key'] = 'untrusted',
            'unknown file' => $files['extra'] = $this->fileAnswerUpload(),
            'file array' => $files = ['file' => [$this->fileAnswerUpload()]],
            'query' => $query = '?unexpected=value',
            'wrong transport' => $contentType = 'application/x-www-form-urlencoded',
            'long Unicode filename' => $files = ['file' => $this->fileAnswerUpload(str_repeat('я', 497).'.pdf')],
            'failed upload' => $files = ['file' => new UploadedFile($this->fileAnswerUpload()->getPathname(), 'failed.pdf', 'application/pdf', UPLOAD_ERR_PARTIAL, true)],
        };
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('strict-file-answer')->plainTextToken];
        $this->call('PUT', '/api/v1/student/attempts/'.$attempt->id.'/answers/'.$question->id.$query,
            $parameters, [], $files, $server)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($snapshot, $this->fileAnswerSnapshot());
        $this->assertSame($blobs, Storage::disk('local')->allFiles());
    }

    public static function invalidMultipart(): array
    {
        return array_map(fn (string $case): array => [$case], ['missing file', 'empty file', 'missing type', 'non-file type',
            'array type', 'unknown field', 'unknown file', 'file array', 'query', 'wrong transport', 'long Unicode filename', 'failed upload']);
    }

    public function test_json_file_answer_is_rejected_and_a_500_code_point_unicode_filename_is_valid(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $this->answerRequest($student, $attempt, $question, ['type' => 'file_based', 'file' => 'answer.pdf'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $name = str_repeat('я', 496).'.PDF';
        $this->assertSame(500, mb_strlen($name, 'UTF-8'));
        $this->assertGreaterThan(500, strlen($name));
        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload($name))
            ->assertOk()->assertJsonPath('data.answer.file.original_name', $name);
    }

    public function test_question_type_and_scope_failures_happen_before_blob_storage(): void
    {
        [$student, $homework, $attempt] = $this->fileAnswerContext();
        $nonFile = $this->answerQuestion($homework, 'true_false', 2);
        $this->fileAnswerRequest($student, $attempt, $nonFile, $this->fileAnswerUpload())
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed')->assertJsonStructure(['errors' => ['type']]);
        [, , , $foreignQuestion] = $this->fileAnswerContext();
        $this->fileAnswerRequest($student, $attempt, $foreignQuestion, $this->fileAnswerUpload())->assertNotFound();
        $otherAssessment = Assessment::factory()->homework()->create(['institution_id' => $student->institution_id]);
        $otherQuestion = Question::factory()->fileBased()->create(['assessment_id' => $otherAssessment->id]);
        $this->fileAnswerRequest($student, $attempt, $otherQuestion, $this->fileAnswerUpload())->assertNotFound();
        $this->assertDatabaseCount('files', 0);
        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    public function test_actual_effective_and_platform_size_boundaries_and_early_inspection_gate(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        foreach ([1 => 1_048_576, 15 => 15_728_640] as $settingMb => $limit) {
            InstitutionSetting::query()->whereKey($student->institution_id)->update(['student_submission_max_mb' => $settingMb]);
            $this->fileAnswerRequest($student, $attempt, $question, $this->sizedPdf($limit))
                ->assertOk()->assertJsonPath('data.answer.file.size_bytes', $limit);
            $snapshot = $this->fileAnswerSnapshot();
            $this->fileAnswerRequest($student, $attempt, $question, $this->sizedPdf($limit + 1))
                ->assertUnprocessable()->assertJsonPath('code', 'file_too_large')
                ->assertJsonPath('errors.file.0', 'The file must not exceed '.$limit.' bytes ('.$settingMb.' MiB).');
            // Invalid bytes would fail the inspector; reported oversized bytes must fail the earlier size gate.
            $oversizedInvalid = $this->fileAnswerUpload('invalid.bin', 'not a supported binary')->size(intdiv($limit, 1024) + 1);
            $this->fileAnswerRequest($student, $attempt, $question, $oversizedInvalid)
                ->assertUnprocessable()->assertJsonPath('code', 'file_too_large');
            $this->assertSame($snapshot, $this->fileAnswerSnapshot());
            $this->assertCount(1, Storage::disk('local')->allFiles());
        }
        $policy = new StudentSubmissionUploadPolicy;
        $this->assertSame(15_728_640, $policy->maxSizeBytes(new InstitutionSetting(['student_submission_max_mb' => 30])));
    }

    public function test_inspected_size_must_match_server_observed_upload_size_before_storage(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $upload = $this->fileAnswerUpload()->size(1);
        $this->fileAnswerRequest($student, $attempt, $question, $upload)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseCount('files', 0);
        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    public function test_replacement_preserves_ids_and_creation_times_and_noop_changes_no_rows(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $attemptBefore = $attempt->getAttributes();
        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload())->assertOk();
        $answer = AttemptAnswer::query()->sole();
        $answerFileBefore = AnswerFile::query()->sole()->getAttributes();
        $file = File::query()->sole();
        $identities = [$answer->id, $answer->getRawOriginal('created_at'), $file->id, $file->getRawOriginal('created_at')];
        $oldKey = $file->storage_key;
        $before = $this->fileAnswerSnapshot();
        $this->travel(1)->seconds();
        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload())->assertOk();
        $this->assertSame($before, $this->fileAnswerSnapshot());
        $this->assertSame([$oldKey], Storage::disk('local')->allFiles());

        foreach ([['replacement.pdf', "%PDF-1.7\nReplacement bytes"], ['renamed.pdf', "%PDF-1.7\nReplacement bytes"]] as [$name, $content]) {
            $this->travel(1)->seconds();
            $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload($name, $content))
                ->assertOk()->assertJsonPath('data.answer.file.id', $file->id)->assertJsonPath('data.answer.file.original_name', $name);
            $answer->refresh();
            $file->refresh();
            $this->assertSame($identities, [$answer->id, $answer->getRawOriginal('created_at'), $file->id, $file->getRawOriginal('created_at')]);
            $this->assertSame($answerFileBefore, AnswerFile::query()->sole()->getAttributes());
            $this->assertTrue($answer->updated_at->equalTo(now()));
            $this->assertTrue($file->updated_at->equalTo(now()));
            $this->assertSame(hash('sha256', $content), $file->checksum_sha256);
            $this->assertSame($content, Storage::disk('local')->get($file->storage_key));
            Storage::disk('local')->assertMissing($oldKey);
            $oldKey = $file->storage_key;
        }
        $this->assertDatabaseCount('files', 1);
        $this->assertDatabaseCount('answer_files', 1);
        $this->assertDatabaseCount('attempt_answers', 1);
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public function test_storage_write_failure_keeps_existing_answer_unchanged_and_returns_safe_error(): void
    {
        [$student, , $attempt, $question] = $this->fileAnswerContext();
        $this->savedFileAnswer($attempt, $question);
        $snapshot = $this->fileAnswerSnapshot();
        $blobs = Storage::disk('local')->allFiles();
        $storage = $this->createMock(PrivateFileStorage::class);
        $storage->expects($this->once())->method('store')->willThrowException(new FileUploadFailedException);
        $this->app->instance(PrivateFileStorage::class, $storage);
        $this->fileAnswerRequest($student, $attempt, $question, $this->fileAnswerUpload('replacement.pdf'))
            ->assertStatus(500)->assertJsonPath('code', 'file_upload_failed');
        $this->assertSame($snapshot, $this->fileAnswerSnapshot());
        $this->assertSame($blobs, Storage::disk('local')->allFiles());
    }

    private function sizedPdf(int $size): UploadedFile
    {
        $path = $this->temporaryPath();
        $stream = fopen($path, 'wb');
        fwrite($stream, "%PDF-1.7\n");
        ftruncate($stream, $size);
        fclose($stream);

        return new UploadedFile($path, 'sized.pdf', 'text/plain', UPLOAD_ERR_OK, true);
    }

    private function formatUpload(string $extension, ?string $name = null): UploadedFile
    {
        $name ??= 'answer.'.$extension;
        if ($extension === 'pdf') {
            return $this->fileAnswerUpload($name);
        }
        $path = $this->temporaryPath();
        if (in_array($extension, ['docx', 'pptx'], true)) {
            $part = $extension === 'docx' ? 'word/document.xml' : 'ppt/presentation.xml';
            $mime = $extension === 'docx'
                ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'
                : 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml';
            $zip = new ZipArchive;
            $this->assertTrue($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE));
            $zip->addFromString('[Content_Types].xml', '<Types><Override PartName="/'.$part.'" ContentType="'.$mime.'"/></Types>');
            $zip->addFromString($part, '<root/>');
            $zip->close();
        } else {
            $header = str_repeat("\0", 512);
            $header = substr_replace($header, "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1", 0, 8);
            $header = substr_replace($header, pack('v', 9), 30, 2);
            $header = substr_replace($header, pack('V', 1), 44, 4);
            $header = substr_replace($header, pack('V', 0), 48, 4);
            $header = substr_replace($header, pack('V', 0xFFFFFFFE), 68, 4);
            $header = substr_replace($header, pack('V', 0), 72, 4);
            $header = substr_replace($header, pack('V', 1), 76, 4);
            for ($offset = 80; $offset < 512; $offset += 4) {
                $header = substr_replace($header, pack('V', 0xFFFFFFFF), $offset, 4);
            }
            $directory = str_repeat("\0", 512);
            $encoded = mb_convert_encoding('PowerPoint Document', 'UTF-16LE', 'UTF-8')."\0\0";
            $directory = substr_replace($directory, $encoded, 0, strlen($encoded));
            $directory = substr_replace($directory, pack('v', strlen($encoded)), 64, 2);
            $directory[66] = chr(2);
            $fat = str_repeat(pack('V', 0xFFFFFFFF), 128);
            $fat = substr_replace($fat, pack('V', 0xFFFFFFFE), 0, 4);
            $fat = substr_replace($fat, pack('V', 0xFFFFFFFD), 4, 4);
            file_put_contents($path, $header.$directory.$fat);
        }

        return new UploadedFile($path, $name, 'text/plain', UPLOAD_ERR_OK, true);
    }

    private function temporaryPath(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's07_be006_api_');
        $this->assertIsString($path);
        $this->temporaryFiles[] = $path;

        return $path;
    }
}
