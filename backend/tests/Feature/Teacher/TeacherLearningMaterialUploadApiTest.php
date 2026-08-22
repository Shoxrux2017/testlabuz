<?php

namespace Tests\Feature\Teacher;

use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Exceptions\Files\FileUploadFailedException;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use App\Support\Files\PrivateFileStorage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;
use ZipArchive;

class TeacherLearningMaterialUploadApiTest extends TestCase
{
    use RefreshDatabase;

    /** @var list<string> */
    private array $temporaryFiles = [];

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    protected function tearDown(): void
    {
        foreach ($this->temporaryFiles as $path) {
            if (file_exists($path)) {
                unlink($path);
            }
        }

        parent::tearDown();
    }

    public function test_upload_accepts_all_detected_formats_and_persists_canonical_private_metadata(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $uploads = [
            ['lesson.PDF', $this->pdf('lesson.PDF'), FileExtension::Pdf, 'application/pdf'],
            ['lesson.docx', $this->ooxml('lesson.docx', 'docx'), FileExtension::Docx, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
            ['lesson.ppt', $this->ppt('lesson.ppt'), FileExtension::Ppt, 'application/vnd.ms-powerpoint'],
            ['lesson.pptx', $this->ooxml('lesson.pptx', 'pptx'), FileExtension::Pptx, 'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
        ];

        foreach ($uploads as [$originalName, $upload, $extension, $mimeType]) {
            $response = $this->multipart($teacher, 'POST', $this->uri($topic), ['title' => '  Lesson title  '], $upload);
            $response->assertCreated();
            $this->assertSame(['data'], array_keys($response->json()));
            $this->assertSame('Lesson title', $response->json('data.title'));
            $this->assertSame($originalName, $response->json('data.file.original_name'));
            $this->assertSame($extension->value, $response->json('data.file.extension'));
            $this->assertSame($mimeType, $response->json('data.file.mime_type'));
            $this->assertStringNotContainsString('storage_', $response->getContent());
            $this->assertStringNotContainsString('checksum', $response->getContent());

            $material = LearningMaterial::query()->findOrFail($response->json('data.id'));
            $file = File::query()->findOrFail($material->file_id);
            $this->assertSame($institution->id, $material->institution_id);
            $this->assertSame($topic->id, $material->topic_id);
            $this->assertSame($teacher->id, $material->teacher_id);
            $this->assertSame($institution->id, $file->institution_id);
            $this->assertSame($teacher->id, $file->uploaded_by_user_id);
            $this->assertSame(FileCategory::LearningMaterial, $file->category);
            $this->assertSame($extension, $file->extension);
            $this->assertSame($mimeType, $file->mime_type);
            $this->assertMatchesRegularExpression('/^[a-f0-9]{64}$/', $file->checksum_sha256);
            $this->assertSame(hash('sha256', file_get_contents($upload->getPathname())), $file->checksum_sha256);
            $this->assertMatchesRegularExpression(
                '#^learning-materials/'.preg_quote($institution->id, '#').'/'.preg_quote($topic->id, '#').'/[0-9a-f-]{36}\\.'.$extension->value.'$#',
                $file->storage_key,
            );
            Storage::disk('local')->assertExists($file->storage_key);
            Storage::disk('public')->assertMissing($file->storage_key);
        }

        $this->assertSame([0, 1, 2, 3], LearningMaterial::query()->where('topic_id', $topic->id)->orderBy('position')->pluck('position')->all());
        $this->assertCount(4, LearningMaterial::query()->where('topic_id', $topic->id)->get());
    }

    public function test_configured_private_disk_and_server_generated_key_ignore_original_filename_as_path_authority(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        config([
            'filesystems.private_files_disk' => 'materials-private',
            'filesystems.disks.materials-private' => [
                'driver' => 'local',
                'root' => storage_path('framework/testing/disks/materials-private'),
                'throw' => false,
            ],
        ]);
        Storage::fake('materials-private');

        $response = $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->pdf('../unsafe.pdf'));
        $response->assertCreated();
        $file = File::query()->findOrFail($response->json('data.file.id'));

        $this->assertSame('materials-private', $file->storage_disk);
        $this->assertStringNotContainsString('unsafe', $file->storage_key);
        $this->assertStringNotContainsString('..', $file->storage_key);
        $this->assertStringStartsWith("learning-materials/{$institution->id}/{$topic->id}/", $file->storage_key);
        Storage::disk('materials-private')->assertExists($file->storage_key);
        $this->assertStringNotContainsString('materials-private', $response->getContent());
        $this->assertStringNotContainsString($file->storage_key, $response->getContent());
    }

    public function test_content_detection_rejects_generic_archives_spoofing_mismatches_and_arbitrary_ole(): void
    {
        [, $teacher, , , $topic] = $this->context();
        $invalidUploads = [
            $this->zip('archive.zip', ['notes.txt' => 'generic']),
            $this->ooxml('renamed.pptx', 'docx'),
            $this->ooxml('renamed.docx', 'pptx'),
            UploadedFile::fake()->createWithContent('arbitrary.ppt', "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1".str_repeat("\0", 1024)),
            UploadedFile::fake()->createWithContent('arbitrary.pdf', 'not a pdf'),
            $this->pdf('archive.zip'),
        ];

        foreach ($invalidUploads as $upload) {
            $this->multipart($teacher, 'POST', $this->uri($topic), [], $upload)
                ->assertUnprocessable()
                ->assertJsonPath('code', 'unsupported_file_type')
                ->assertJsonPath('message', 'The uploaded file type is not supported.');
        }

        $this->assertDatabaseCount('files', 0);
        $this->assertDatabaseCount('learning_materials', 0);
        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    public function test_upload_strictly_validates_multipart_shape_file_and_title(): void
    {
        [, $teacher, , , $topic] = $this->context();

        $this->multipart($teacher, 'POST', $this->uri($topic))->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->multipart($teacher, 'POST', $this->uri($topic), [], UploadedFile::fake()->createWithContent('empty.pdf', ''))
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $failedPath = $this->temporaryPath();
        file_put_contents($failedPath, '%PDF-1.7');
        $failedUpload = new UploadedFile($failedPath, 'failed.pdf', 'application/pdf', UPLOAD_ERR_PARTIAL, true);
        $this->multipart($teacher, 'POST', $this->uri($topic), [], $failedUpload)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        foreach ([
            ['title' => '   '],
            ['title' => str_repeat('x', 256)],
            ['position' => 9],
            ['storage_key' => 'public/path'],
            ['institution_id' => '00000000-0000-0000-0000-000000000001'],
        ] as $parameters) {
            $response = $this->multipart($teacher, 'POST', $this->uri($topic), $parameters, $this->pdf('lesson.pdf'));
            $this->assertSame(422, $response->getStatusCode(), 'Unexpected validation result for '.json_encode($parameters));
            $response->assertJsonPath('code', 'validation_failed');
        }

        $this->multipart($teacher, 'POST', $this->uri($topic).'?unexpected=x', [], $this->pdf('lesson.pdf'))
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->jsonRequest($teacher, 'POST', $this->uri($topic), ['file' => 'lesson.pdf'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $this->multipart($teacher, 'POST', $this->uri($topic), ['title' => null], $this->pdf('null.pdf'))->assertCreated();
        $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->pdf('omitted.pdf'))->assertCreated();
        $this->assertNull(LearningMaterial::query()->latest('created_at')->firstOrFail()->title);
    }

    public function test_effective_and_platform_limits_are_exact_actual_byte_boundaries(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        InstitutionSetting::query()->whereKey($institution->id)->update(['learning_material_max_mb' => 1]);

        $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->sizedPdf('exact.pdf', 1_048_576))
            ->assertCreated()->assertJsonPath('data.file.size_bytes', 1_048_576);
        $tooLarge = $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->sizedPdf('large.pdf', 1_048_577));
        $tooLarge->assertUnprocessable()->assertJsonPath('code', 'file_too_large');
        $this->assertSame('The file must not exceed 1048576 bytes (1 MiB).', $tooLarge->json('errors.file.0'));

        InstitutionSetting::query()->whereKey($institution->id)->update(['learning_material_max_mb' => 25]);
        $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->sizedPdf('platform.pdf', 26_214_400))
            ->assertCreated()->assertJsonPath('data.file.size_bytes', 26_214_400);
        $platformTooLarge = $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->sizedPdf('platform-large.pdf', 26_214_401));
        $platformTooLarge->assertUnprocessable()->assertJsonPath('code', 'file_too_large');
        $this->assertSame('The file must not exceed 26214400 bytes (25 MiB).', $platformTooLarge->json('errors.file.0'));
    }

    public function test_storage_write_failure_returns_exact_error_without_database_attachment(): void
    {
        [, $teacher, , , $topic] = $this->context();
        $storage = $this->createMock(PrivateFileStorage::class);
        $storage->expects($this->once())->method('store')->willThrowException(new FileUploadFailedException);
        $this->app->instance(PrivateFileStorage::class, $storage);

        $response = $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->pdf('lesson.pdf'));
        $response->assertStatus(500)->assertJsonPath('code', 'file_upload_failed');
        $this->assertSame([], $response->json('errors'));
        $this->assertDatabaseCount('files', 0);
        $this->assertDatabaseCount('learning_materials', 0);
    }

    public function test_scope_failure_after_blob_write_rolls_back_and_cleans_new_blob(): void
    {
        [, $teacher, , $group, $topic] = $this->context();
        $storage = new class($group->id, $teacher->id) extends PrivateFileStorage
        {
            public int $deleteAttempts = 0;

            public function __construct(private readonly string $groupId, private readonly string $teacherId) {}

            public function store(UploadedFile $upload, string $storageKey): string
            {
                $disk = parent::store($upload, $storageKey);
                GroupTeacherMembership::query()
                    ->where('group_id', $this->groupId)
                    ->where('teacher_id', $this->teacherId)
                    ->update(['ended_at' => now()]);

                return $disk;
            }

            public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
            {
                $this->deleteAttempts++;

                return parent::deleteBestEffort($diskName, $storageKey, $operation, $fileId);
            }
        };
        $this->app->instance(PrivateFileStorage::class, $storage);

        $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->pdf('lesson.pdf'))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertDatabaseCount('files', 0);
        $this->assertDatabaseCount('learning_materials', 0);
        $this->assertSame([], Storage::disk('local')->allFiles());
        $this->assertSame(1, $storage->deleteAttempts);
    }

    public function test_upload_outer_rollback_removes_database_attachment_and_cleans_new_blob(): void
    {
        [, $teacher, , , $topic] = $this->context();
        $baseTransactionLevel = DB::transactionLevel();
        DB::beginTransaction();

        try {
            $response = $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->pdf('outer-rollback.pdf'));
            $response->assertCreated();
            $materialId = $response->json('data.id');
            $fileId = $response->json('data.file.id');
            $newStorageKey = File::query()->findOrFail($fileId)->storage_key;

            $this->assertDatabaseHas('learning_materials', ['id' => $materialId, 'file_id' => $fileId]);
            $this->assertDatabaseHas('files', ['id' => $fileId, 'storage_key' => $newStorageKey]);
            Storage::disk('local')->assertExists($newStorageKey);

            DB::rollBack();
        } finally {
            if (DB::transactionLevel() > $baseTransactionLevel) {
                DB::rollBack($baseTransactionLevel);
            }
        }

        $this->assertDatabaseMissing('learning_materials', ['id' => $materialId]);
        $this->assertDatabaseMissing('files', ['id' => $fileId]);
        Storage::disk('local')->assertMissing($newStorageKey);
    }

    public function test_explicit_public_or_missing_private_disk_is_rejected_as_server_configuration_failure(): void
    {
        [, $teacher, , , $topic] = $this->context();

        config(['filesystems.private_files_disk' => 'public']);
        $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->pdf('public.pdf'))
            ->assertStatus(500)->assertJsonPath('code', 'server_error');

        config(['filesystems.private_files_disk' => 'missing-private-disk']);
        $this->multipart($teacher, 'POST', $this->uri($topic), [], $this->pdf('missing.pdf'))
            ->assertStatus(500)->assertJsonPath('code', 'server_error');

        $this->assertDatabaseCount('files', 0);
        $this->assertDatabaseCount('learning_materials', 0);
    }

    /** @return array{Institution, User, User, Group, Topic} */
    private function context(): array
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
        $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $topic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);

        return [$institution, $teacher, $admin, $group, $topic];
    }

    private function uri(Topic $topic): string
    {
        return '/api/v1/teacher/topics/'.$topic->id.'/materials';
    }

    /** @param array<string, mixed> $parameters */
    private function multipart(User $actor, string $method, string $uri, array $parameters = [], ?UploadedFile $upload = null): TestResponse
    {
        $files = $upload instanceof UploadedFile ? ['file' => $upload] : [];
        $server = [
            'CONTENT_TYPE' => 'multipart/form-data',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('teacher-material-upload-api-test')->plainTextToken,
        ];
        $response = $this->call($method, $uri, $parameters, [], $files, $server);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @param array<string, mixed> $payload */
    private function jsonRequest(User $actor, string $method, string $uri, array $payload): TestResponse
    {
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('teacher-material-upload-json-test')->plainTextToken,
        ];
        $response = $this->call($method, $uri, [], [], [], $server, json_encode($payload, JSON_THROW_ON_ERROR));
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function pdf(string $name): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, "%PDF-1.7\nTestLabUz");
    }

    private function sizedPdf(string $name, int $size): UploadedFile
    {
        $path = $this->temporaryPath();
        $stream = fopen($path, 'wb');
        $this->assertIsResource($stream);
        fwrite($stream, "%PDF-1.7\n");
        ftruncate($stream, $size);
        fclose($stream);

        return new UploadedFile($path, $name, 'application/octet-stream', UPLOAD_ERR_OK, true);
    }

    private function ooxml(string $name, string $type): UploadedFile
    {
        $part = $type === 'docx' ? 'word/document.xml' : 'ppt/presentation.xml';
        $contentType = $type === 'docx'
            ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'
            : 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml';

        return $this->zip($name, [
            '[Content_Types].xml' => '<Types><Override PartName="/'.$part.'" ContentType="'.$contentType.'"/></Types>',
            $part => '<root/>',
        ]);
    }

    /** @param array<string, string> $entries */
    private function zip(string $name, array $entries): UploadedFile
    {
        $path = $this->temporaryPath();
        $zip = new ZipArchive;
        $this->assertTrue($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE));
        foreach ($entries as $entry => $contents) {
            $this->assertTrue($zip->addFromString($entry, $contents));
        }
        $zip->close();

        return new UploadedFile($path, $name, 'application/octet-stream', UPLOAD_ERR_OK, true);
    }

    private function ppt(string $name): UploadedFile
    {
        $path = $this->temporaryPath();
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
        $encodedName = mb_convert_encoding('PowerPoint Document', 'UTF-16LE', 'UTF-8')."\0\0";
        $directory = substr_replace($directory, $encodedName, 0, strlen($encodedName));
        $directory = substr_replace($directory, pack('v', strlen($encodedName)), 64, 2);
        $directory[66] = chr(2);
        $fat = str_repeat(pack('V', 0xFFFFFFFF), 128);
        $fat = substr_replace($fat, pack('V', 0xFFFFFFFE), 0, 4);
        $fat = substr_replace($fat, pack('V', 0xFFFFFFFD), 4, 4);
        file_put_contents($path, $header.$directory.$fat);

        return new UploadedFile($path, $name, 'application/octet-stream', UPLOAD_ERR_OK, true);
    }

    private function temporaryPath(): string
    {
        $path = tempnam(sys_get_temp_dir(), 's05_be_003_upload_');
        $this->assertIsString($path);
        $this->temporaryFiles[] = $path;

        return $path;
    }
}
