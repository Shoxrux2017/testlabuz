<?php

namespace Tests\Feature\Teacher;

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
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;
use ZipArchive;

class TeacherLearningMaterialMutationApiTest extends TestCase
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

    public function test_replace_preserves_material_and_file_identity_and_replaces_all_canonical_metadata(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $initialTimestamp = CarbonImmutable::parse('2026-08-22 10:00:00', 'UTC');
        $material = $this->material($institution, $topic, $teacher, [
            'title' => 'Stable title',
            'created_at' => $initialTimestamp,
            'updated_at' => $initialTimestamp,
        ]);
        $materialId = $material->id;
        $fileId = $material->file_id;
        $previousUpdatedAt = $material->updated_at;
        $uploads = [
            [$this->pdf('replacement.PDF'), FileExtension::Pdf, 'application/pdf'],
            [$this->ooxml('replacement.docx', 'docx'), FileExtension::Docx, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
            [$this->ppt('replacement.ppt'), FileExtension::Ppt, 'application/vnd.ms-powerpoint'],
            [$this->ooxml('replacement.pptx', 'pptx'), FileExtension::Pptx, 'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
        ];

        foreach ($uploads as $index => [$upload, $extension, $mimeType]) {
            $oldFile = File::query()->findOrFail($fileId);
            $oldStorageKey = $oldFile->storage_key;
            $this->travelTo(CarbonImmutable::parse('2026-08-22 12:0'.$index.':00', 'UTC'));
            $response = $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $upload);
            $response->assertOk()
                ->assertJsonPath('message', 'Learning material replaced successfully.')
                ->assertJsonPath('data.id', $materialId)
                ->assertJsonPath('data.file.id', $fileId)
                ->assertJsonPath('data.file.extension', $extension->value)
                ->assertJsonPath('data.file.mime_type', $mimeType);

            $material->refresh();
            $file = File::query()->findOrFail($fileId);
            $this->assertSame($materialId, $material->id);
            $this->assertSame($fileId, $material->file_id);
            $this->assertSame('Stable title', $material->title);
            $this->assertSame($upload->getClientOriginalName(), $file->original_name);
            $this->assertSame($extension, $file->extension);
            $this->assertSame($mimeType, $file->mime_type);
            $this->assertSame(filesize($upload->getPathname()), $file->size_bytes);
            $this->assertSame(hash_file('sha256', $upload->getPathname()), $file->checksum_sha256);
            $this->assertNotSame($oldStorageKey, $file->storage_key);
            Storage::disk('local')->assertExists($file->storage_key);
            Storage::disk('local')->assertMissing($oldStorageKey);
            $this->assertTrue($material->updated_at->greaterThan($previousUpdatedAt));
            $previousUpdatedAt = $material->updated_at;
        }

        $this->travelBack();
        $this->assertDatabaseCount('learning_materials', 1);
        $this->assertDatabaseCount('files', 1);
    }

    public function test_unsupported_and_oversized_replace_leave_old_authority_unchanged(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        InstitutionSetting::query()->whereKey($institution->id)->update(['learning_material_max_mb' => 1]);
        $material = $this->material($institution, $topic, $teacher);
        $beforeMaterialUpdatedAt = $material->updated_at;
        $file = File::query()->findOrFail($material->file_id);
        $beforeFileUpdatedAt = $file->updated_at;
        $beforeStorageKey = $file->storage_key;

        $this->multipart(
            $teacher,
            'POST',
            $this->replaceUri($material),
            [],
            UploadedFile::fake()->createWithContent('spoofed.pdf', 'not pdf'),
        )->assertUnprocessable()->assertJsonPath('code', 'unsupported_file_type');
        $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $this->sizedPdf('large.pdf', 1_048_577))
            ->assertUnprocessable()->assertJsonPath('code', 'file_too_large');

        $this->assertTrue($material->fresh()->updated_at->equalTo($beforeMaterialUpdatedAt));
        $this->assertTrue($file->fresh()->updated_at->equalTo($beforeFileUpdatedAt));
        $this->assertSame($beforeStorageKey, $file->storage_key);
        Storage::disk('local')->assertExists($beforeStorageKey);
        $this->assertDatabaseCount('learning_materials', 1);
        $this->assertDatabaseCount('files', 1);
    }

    public function test_replace_storage_failure_keeps_old_material_file_and_blob_authoritative(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $file = File::query()->findOrFail($material->file_id);
        $storage = $this->createMock(PrivateFileStorage::class);
        $storage->expects($this->once())->method('store')->willThrowException(new FileUploadFailedException);
        $this->app->instance(PrivateFileStorage::class, $storage);

        $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $this->pdf('replacement.pdf'))
            ->assertStatus(500)->assertJsonPath('code', 'file_upload_failed');

        $this->assertSame($file->storage_key, $file->fresh()->storage_key);
        $this->assertNull($material->fresh()->removed_at);
        Storage::disk('local')->assertExists($file->storage_key);
        $this->assertDatabaseCount('learning_materials', 1);
        $this->assertDatabaseCount('files', 1);
    }

    public function test_replace_scope_failure_after_new_blob_write_rolls_back_and_cleans_only_new_blob(): void
    {
        [, $teacher, , $group, $topic] = $this->context();
        $material = $this->material($topic->institution, $topic, $teacher);
        $oldFile = File::query()->findOrFail($material->file_id);
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

        $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $this->pdf('replacement.pdf'))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');

        $this->assertSame($oldFile->storage_key, $oldFile->fresh()->storage_key);
        $this->assertNull($material->fresh()->removed_at);
        Storage::disk('local')->assertExists($oldFile->storage_key);
        $this->assertSame([$oldFile->storage_key], Storage::disk('local')->allFiles());
        $this->assertSame(1, $storage->deleteAttempts);
    }

    public function test_old_blob_cleanup_failure_does_not_roll_back_successful_replace(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $oldFile = File::query()->findOrFail($material->file_id);
        $storage = new class extends PrivateFileStorage
        {
            public int $deleteAttempts = 0;

            public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
            {
                $this->deleteAttempts++;

                return false;
            }
        };
        $this->app->instance(PrivateFileStorage::class, $storage);

        $response = $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $this->pdf('replacement.pdf'));
        $response->assertOk()->assertJsonPath('data.id', $material->id)->assertJsonPath('data.file.id', $oldFile->id);
        $newFile = $oldFile->fresh();

        $this->assertSame(1, $storage->deleteAttempts);
        $this->assertNotSame($oldFile->storage_key, $newFile->storage_key);
        Storage::disk('local')->assertExists($oldFile->storage_key);
        Storage::disk('local')->assertExists($newFile->storage_key);
    }

    public function test_replace_outer_rollback_restores_old_authority_and_cleans_new_blob(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $oldFile = File::query()->findOrFail($material->file_id);
        $oldStorageKey = $oldFile->storage_key;
        $baseTransactionLevel = DB::transactionLevel();
        DB::beginTransaction();

        try {
            $response = $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $this->pdf('outer-rollback.pdf'));
            $response->assertOk();
            $newStorageKey = File::query()->findOrFail($oldFile->id)->storage_key;

            $this->assertNotSame($oldStorageKey, $newStorageKey);
            Storage::disk('local')->assertExists($oldStorageKey);
            Storage::disk('local')->assertExists($newStorageKey);

            DB::rollBack();
        } finally {
            if (DB::transactionLevel() > $baseTransactionLevel) {
                DB::rollBack($baseTransactionLevel);
            }
        }

        $this->assertSame($oldStorageKey, File::query()->findOrFail($oldFile->id)->storage_key);
        $this->assertNull(LearningMaterial::query()->findOrFail($material->id)->removed_at);
        Storage::disk('local')->assertExists($oldStorageKey);
        Storage::disk('local')->assertMissing($newStorageKey);
    }

    public function test_replace_outer_commit_deletes_old_blob_and_keeps_new_authority(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $oldFile = File::query()->findOrFail($material->file_id);
        $oldStorageKey = $oldFile->storage_key;
        $baseTransactionLevel = DB::transactionLevel();
        DB::beginTransaction();

        try {
            $response = $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $this->pdf('outer-commit.pdf'));
            $response->assertOk();
            $newStorageKey = File::query()->findOrFail($oldFile->id)->storage_key;

            $this->assertNotSame($oldStorageKey, $newStorageKey);
            Storage::disk('local')->assertExists($oldStorageKey);
            Storage::disk('local')->assertExists($newStorageKey);

            DB::commit();
        } finally {
            if (DB::transactionLevel() > $baseTransactionLevel) {
                DB::rollBack($baseTransactionLevel);
            }
        }

        $this->assertSame($newStorageKey, File::query()->findOrFail($oldFile->id)->storage_key);
        Storage::disk('local')->assertMissing($oldStorageKey);
        Storage::disk('local')->assertExists($newStorageKey);
    }

    public function test_replace_accepts_only_one_file_and_rejects_query_or_protected_fields(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);

        $this->multipart($teacher, 'POST', $this->replaceUri($material))->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        foreach ([['title' => 'Changed'], ['storage_key' => 'public/key'], ['removed_at' => null]] as $parameters) {
            $this->multipart($teacher, 'POST', $this->replaceUri($material), $parameters, $this->pdf('replacement.pdf'))
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->multipart($teacher, 'POST', $this->replaceUri($material).'?unexpected=x', [], $this->pdf('replacement.pdf'))
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_title_update_trims_clears_and_preserves_file_timestamp_and_exact_no_op_timestamp(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $past = CarbonImmutable::parse('2026-08-22 10:00:00', 'UTC');
        $material = $this->material($institution, $topic, $teacher, ['title' => 'Original', 'updated_at' => $past], ['updated_at' => $past]);
        $fileUpdatedAt = File::query()->findOrFail($material->file_id)->updated_at;
        $this->travelTo($past->addHour());

        $response = $this->jsonRequest($teacher, 'PATCH', $this->materialUri($material), ['title' => '  Updated title  ']);
        $response->assertOk()
            ->assertJsonPath('message', 'Learning material updated successfully.')
            ->assertJsonPath('data.title', 'Updated title');
        $material->refresh();
        $this->assertSame('Updated title', $material->title);
        $this->assertTrue($material->updated_at->greaterThan($past));
        $this->assertTrue(File::query()->findOrFail($material->file_id)->updated_at->equalTo($fileUpdatedAt));

        $noOpUpdatedAt = $material->updated_at;
        $this->travelTo($past->addHours(2));
        $this->jsonRequest($teacher, 'PATCH', $this->materialUri($material), ['title' => 'Updated title'])
            ->assertOk()->assertJsonPath('data.title', 'Updated title');
        $this->assertTrue($material->fresh()->updated_at->equalTo($noOpUpdatedAt));
        $this->assertTrue(File::query()->findOrFail($material->file_id)->updated_at->equalTo($fileUpdatedAt));

        $this->jsonRequest($teacher, 'PATCH', $this->materialUri($material), ['title' => null])
            ->assertOk()->assertJsonPath('data.title', null);
        $this->assertNull($material->fresh()->title);
        $this->assertTrue(File::query()->findOrFail($material->file_id)->updated_at->equalTo($fileUpdatedAt));
        $this->travelBack();
    }

    public function test_title_update_rejects_invalid_json_shapes_unknown_fields_and_query(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);

        foreach (['', '{}', '[]', '"title"', '{bad json'] as $content) {
            $this->rawJson($teacher, 'PATCH', $this->materialUri($material), $content)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        foreach ([
            ['title' => '   '],
            ['title' => str_repeat('x', 256)],
            ['storage_key' => 'private/key'],
            ['title' => 'Valid', 'removed_at' => null],
        ] as $payload) {
            $this->jsonRequest($teacher, 'PATCH', $this->materialUri($material), $payload)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->jsonRequest($teacher, 'PATCH', $this->materialUri($material).'?unexpected=x', ['title' => 'Valid'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_remove_is_historical_uses_one_timestamp_deletes_blob_after_commit_and_is_repeat_safe(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $file = File::query()->findOrFail($material->file_id);

        $this->request($teacher, 'DELETE', $this->materialUri($material))->assertNoContent();
        $material->refresh();
        $file->refresh();
        $this->assertNotNull($material->removed_at);
        $this->assertTrue($material->removed_at->equalTo($file->removed_at));
        $this->assertDatabaseHas('learning_materials', ['id' => $material->id]);
        $this->assertDatabaseHas('files', ['id' => $file->id]);
        Storage::disk('local')->assertMissing($file->storage_key);

        $this->request($teacher, 'DELETE', $this->materialUri($material))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
    }

    public function test_remove_blob_cleanup_failure_still_returns_204_and_keeps_rows_removed(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $file = File::query()->findOrFail($material->file_id);
        $storage = new class extends PrivateFileStorage
        {
            public int $deleteAttempts = 0;

            public function deleteBestEffort(string $diskName, string $storageKey, string $operation, ?string $fileId = null): bool
            {
                $this->deleteAttempts++;

                return false;
            }
        };
        $this->app->instance(PrivateFileStorage::class, $storage);

        $this->request($teacher, 'DELETE', $this->materialUri($material))->assertNoContent();
        $this->assertSame(1, $storage->deleteAttempts);
        $this->assertNotNull($material->fresh()->removed_at);
        $this->assertNotNull($file->fresh()->removed_at);
        Storage::disk('local')->assertExists($file->storage_key);
    }

    public function test_remove_outer_rollback_restores_current_rows_and_keeps_blob(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $file = File::query()->findOrFail($material->file_id);
        $baseTransactionLevel = DB::transactionLevel();
        DB::beginTransaction();

        try {
            $this->request($teacher, 'DELETE', $this->materialUri($material))->assertNoContent();

            $this->assertNotNull(LearningMaterial::query()->findOrFail($material->id)->removed_at);
            $this->assertNotNull(File::query()->findOrFail($file->id)->removed_at);
            Storage::disk('local')->assertExists($file->storage_key);

            DB::rollBack();
        } finally {
            if (DB::transactionLevel() > $baseTransactionLevel) {
                DB::rollBack($baseTransactionLevel);
            }
        }

        $this->assertNull(LearningMaterial::query()->findOrFail($material->id)->removed_at);
        $this->assertNull(File::query()->findOrFail($file->id)->removed_at);
        Storage::disk('local')->assertExists($file->storage_key);
    }

    public function test_remove_outer_commit_keeps_rows_historically_removed_and_deletes_blob(): void
    {
        [$institution, $teacher, , , $topic] = $this->context();
        $material = $this->material($institution, $topic, $teacher);
        $file = File::query()->findOrFail($material->file_id);
        $baseTransactionLevel = DB::transactionLevel();
        DB::beginTransaction();

        try {
            $this->request($teacher, 'DELETE', $this->materialUri($material))->assertNoContent();

            $this->assertNotNull(LearningMaterial::query()->findOrFail($material->id)->removed_at);
            $this->assertNotNull(File::query()->findOrFail($file->id)->removed_at);
            Storage::disk('local')->assertExists($file->storage_key);

            DB::commit();
        } finally {
            if (DB::transactionLevel() > $baseTransactionLevel) {
                DB::rollBack($baseTransactionLevel);
            }
        }

        $this->assertNotNull(LearningMaterial::query()->findOrFail($material->id)->removed_at);
        $this->assertNotNull(File::query()->findOrFail($file->id)->removed_at);
        Storage::disk('local')->assertMissing($file->storage_key);
    }

    public function test_direct_mutations_hide_foreign_other_teacher_ended_and_removed_materials_before_lifecycle_disclosure(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->context();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $otherMaterial = $this->material($institution, $topic, $otherTeacher);
        $endedGroup = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        GroupTeacherMembership::factory()->ended()->create([
            'institution_id' => $institution->id,
            'group_id' => $endedGroup->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
        $endedTopic = Topic::factory()->create(['institution_id' => $institution->id, 'group_id' => $endedGroup->id, 'teacher_id' => $teacher->id]);
        $endedMaterial = $this->material($institution, $endedTopic, $teacher);
        $removedMaterial = $this->material($institution, $topic, $teacher, [
            'created_at' => now()->subMinute(), 'removed_at' => now(),
        ]);
        $removedFileMaterial = $this->material($institution, $topic, $teacher, [], [
            'created_at' => now()->subMinute(), 'removed_at' => now(),
        ]);
        $foreignInstitution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $foreignInstitution->id]);
        $foreignTeacher = User::factory()->teacher($foreignInstitution)->create(['must_change_password' => false]);
        $foreignAdmin = User::factory()->institutionAdmin($foreignInstitution)->create(['must_change_password' => false]);
        $foreignGroup = Group::factory()->create(['institution_id' => $foreignInstitution->id, 'created_by_user_id' => $foreignAdmin->id]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $foreignInstitution->id, 'group_id' => $foreignGroup->id,
            'teacher_id' => $foreignTeacher->id, 'assigned_by_user_id' => $foreignAdmin->id,
        ]);
        $foreignTopic = Topic::factory()->create([
            'institution_id' => $foreignInstitution->id, 'group_id' => $foreignGroup->id, 'teacher_id' => $foreignTeacher->id,
        ]);
        $foreignMaterial = $this->material($foreignInstitution, $foreignTopic, $foreignTeacher);

        foreach (['invalid', $otherMaterial->id, $endedMaterial->id, $removedMaterial->id, $removedFileMaterial->id, $foreignMaterial->id] as $hiddenMaterial) {
            $this->jsonRequest($teacher, 'PATCH', '/api/v1/teacher/materials/'.$hiddenMaterial, ['title' => 'Hidden'])
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->multipart($teacher, 'POST', '/api/v1/teacher/materials/'.$hiddenMaterial.'/replace', [], $this->pdf('replacement.pdf'))
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->request($teacher, 'DELETE', '/api/v1/teacher/materials/'.$hiddenMaterial)
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_closed_archived_topics_and_archived_groups_are_read_only_for_all_mutations(): void
    {
        [$institution, $teacher, $admin] = $this->context();
        $contexts = [];
        foreach ([Topic::factory()->closed(), Topic::factory()->archivedFromDraft()] as $topicFactory) {
            $group = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
            GroupTeacherMembership::factory()->create([
                'institution_id' => $institution->id, 'group_id' => $group->id,
                'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id,
            ]);
            $contexts[] = $this->material($institution, $topicFactory->create([
                'institution_id' => $institution->id, 'group_id' => $group->id, 'teacher_id' => $teacher->id,
            ]), $teacher);
        }
        $archivedGroup = Group::factory()->archived()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id, 'group_id' => $archivedGroup->id,
            'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id,
        ]);
        $contexts[] = $this->material($institution, Topic::factory()->create([
            'institution_id' => $institution->id, 'group_id' => $archivedGroup->id, 'teacher_id' => $teacher->id,
        ]), $teacher);

        foreach ($contexts as $material) {
            $this->jsonRequest($teacher, 'PATCH', $this->materialUri($material), ['title' => 'No'])
                ->assertConflict()->assertJsonPath('code', 'topic_not_editable');
            $this->multipart($teacher, 'POST', $this->replaceUri($material), [], $this->pdf('replacement.pdf'))
                ->assertConflict()->assertJsonPath('code', 'topic_not_editable');
            $this->request($teacher, 'DELETE', $this->materialUri($material))
                ->assertConflict()->assertJsonPath('code', 'topic_not_editable');
        }
    }

    public function test_postgresql_locks_serialize_all_required_upload_replace_remove_archive_and_membership_races(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $workerPath = tempnam(sys_get_temp_dir(), 's05_be_003_material_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $ids = json_decode($this->runWorker([$workerPath, base_path(), 'setup']), true, flags: JSON_THROW_ON_ERROR);

        try {
            foreach ([
                ['upload_archive', 'upload', 'archive', 'ok', 'ok'],
                ['archive_upload', 'archive', 'upload', 'ok', 'topic_not_editable'],
                ['upload_membership', 'upload', 'membership_remove', 'ok', 'ok'],
                ['membership_upload', 'membership_remove', 'upload', 'ok', 'not_found'],
                ['replace_archive', 'replace', 'archive', 'ok', 'ok'],
                ['archive_replace', 'archive', 'replace', 'ok', 'topic_not_editable'],
                ['replace_membership', 'replace', 'membership_remove', 'ok', 'ok'],
                ['membership_replace', 'membership_remove', 'replace', 'ok', 'not_found'],
                ['replace_remove', 'replace', 'material_remove', 'ok', 'ok'],
                ['remove_replace', 'material_remove', 'replace', 'ok', 'not_found'],
            ] as [$scenario, $firstOperation, $secondOperation, $firstOutcome, $secondOutcome]) {
                $result = $this->runRace($workerPath, $ids, $scenario, $firstOperation, $secondOperation);
                $this->assertSame($firstOutcome, $result['first']['outcome'], $scenario.' first');
                $this->assertSame($secondOutcome, $result['second']['outcome'], $scenario.' second');
            }
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
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

    private function material(Institution $institution, Topic $topic, User $teacher, array $attributes = [], array $fileAttributes = []): LearningMaterial
    {
        $storageKey = $fileAttributes['storage_key'] ?? 'learning-materials/'.$institution->id.'/'.$topic->id.'/'.fake()->uuid().'.pdf';
        $file = File::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'uploaded_by_user_id' => $teacher->id,
            'storage_disk' => 'local',
            'storage_key' => $storageKey,
            'size_bytes' => 13,
            'checksum_sha256' => hash('sha256', "%PDF-1.7\nOld"),
        ], $fileAttributes));
        Storage::disk('local')->put($file->storage_key, "%PDF-1.7\nOld");

        return LearningMaterial::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'teacher_id' => $teacher->id,
            'file_id' => $file->id,
        ], $attributes));
    }

    private function materialUri(LearningMaterial $material): string
    {
        return '/api/v1/teacher/materials/'.$material->id;
    }

    private function replaceUri(LearningMaterial $material): string
    {
        return $this->materialUri($material).'/replace';
    }

    /** @param array<string, mixed> $parameters */
    private function multipart(User $actor, string $method, string $uri, array $parameters = [], ?UploadedFile $upload = null): TestResponse
    {
        $files = $upload instanceof UploadedFile ? ['file' => $upload] : [];

        return $this->callAs($actor, $method, $uri, $parameters, $files, 'multipart/form-data');
    }

    /** @param array<string, mixed> $payload */
    private function jsonRequest(User $actor, string $method, string $uri, array $payload): TestResponse
    {
        return $this->rawJson($actor, $method, $uri, json_encode($payload, JSON_THROW_ON_ERROR));
    }

    private function rawJson(User $actor, string $method, string $uri, string $content): TestResponse
    {
        return $this->callAs($actor, $method, $uri, contentType: 'application/json', content: $content);
    }

    private function request(User $actor, string $method, string $uri): TestResponse
    {
        return $this->callAs($actor, $method, $uri, contentType: 'application/json');
    }

    /**
     * @param  array<string, mixed>  $parameters
     * @param  array<string, UploadedFile>  $files
     */
    private function callAs(
        User $actor,
        string $method,
        string $uri,
        array $parameters = [],
        array $files = [],
        string $contentType = 'application/json',
        string $content = '',
    ): TestResponse {
        $server = [
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('teacher-material-mutation-api-test')->plainTextToken,
        ];
        $response = $this->call($method, $uri, $parameters, [], $files, $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function pdf(string $name): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, "%PDF-1.7\nReplacement");
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
        $path = $this->temporaryPath();
        $part = $type === 'docx' ? 'word/document.xml' : 'ppt/presentation.xml';
        $contentType = $type === 'docx'
            ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'
            : 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml';
        $zip = new ZipArchive;
        $this->assertTrue($zip->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE));
        $zip->addFromString('[Content_Types].xml', '<Types><Override PartName="/'.$part.'" ContentType="'.$contentType.'"/></Types>');
        $zip->addFromString($part, '<root/>');
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
        $path = tempnam(sys_get_temp_dir(), 's05_be_003_mutation_');
        $this->assertIsString($path);
        $this->temporaryFiles[] = $path;

        return $path;
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(string $workerPath, array $ids, string $scenario, string $firstOperation, string $secondOperation): array
    {
        $lockedPath = $this->unusedTempPath('s05_be_003_locked_');
        $releasePath = $this->unusedTempPath('s05_be_003_release_');
        $attemptPath = $this->unusedTempPath('s05_be_003_attempt_');
        $firstAttemptPath = $attemptPath.'.first';
        $arguments = [
            $ids['teacher'],
            $ids['admin'],
            $ids['groups'][$scenario],
            $ids['topics'][$scenario],
            $ids['materials'][$scenario] ?? '-',
        ];

        $first = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $firstOperation, 'hold', $lockedPath, $releasePath, $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'First Learning Material worker did not finish while retaining its locks.');

        $second = $this->startWorker([
            $workerPath, base_path(), 'run', ...$arguments, $secondOperation, 'normal', $lockedPath, $releasePath, $attemptPath,
        ]);
        $this->waitForFile($attemptPath, 'Second Learning Material worker did not begin its locking operation.');
        $secondBackendPid = (int) file_get_contents($attemptPath);

        try {
            $this->waitForPostgresLock($secondBackendPid, $scenario);
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath]);
            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }

        file_put_contents($releasePath, 'release');
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $attemptPath, $firstAttemptPath]);

        return ['first' => $firstResult, 'second' => $secondResult];
    }

    private function unusedTempPath(string $prefix): string
    {
        $path = tempnam(sys_get_temp_dir(), $prefix);
        $this->assertIsString($path);
        unlink($path);

        return $path;
    }

    private function waitForFile(string $path, string $failureMessage): void
    {
        $deadline = microtime(true) + 10;

        do {
            clearstatcache(true, $path);
            if (file_exists($path) && filesize($path) > 0) {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail($failureMessage);
    }

    private function waitForPostgresLock(int $backendPid, string $scenario): void
    {
        $deadline = microtime(true) + 10;
        $lastActivity = null;

        do {
            DB::select('select pg_stat_clear_snapshot()');
            $lastActivity = DB::selectOne(
                'select wait_event_type, wait_event from pg_stat_activity where pid = ?',
                [$backendPid],
            );
            if ($lastActivity !== null && $lastActivity->wait_event_type === 'Lock') {
                return;
            }
            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail('Second worker never entered a PostgreSQL lock wait for '.$scenario.'. Activity: '.json_encode($lastActivity));
    }

    /** @return array{process: resource, pipes: array<int, resource>} */
    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open(array_merge([PHP_BINARY], $arguments), [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);
        $this->assertIsResource($process);
        fclose($pipes[0]);

        return ['process' => $process, 'pipes' => $pipes];
    }

    /** @param array{process: resource, pipes: array<int, resource>} $worker */
    private function finishWorker(array $worker): string
    {
        $stdout = stream_get_contents($worker['pipes'][1]);
        $stderr = stream_get_contents($worker['pipes'][2]);
        fclose($worker['pipes'][1]);
        fclose($worker['pipes'][2]);
        $exitCode = proc_close($worker['process']);
        $this->assertSame(0, $exitCode, $stderr."\nSTDOUT: ".$stdout);

        return trim($stdout);
    }

    private function runWorker(array $arguments): string
    {
        return $this->finishWorker($this->startWorker($arguments));
    }

    /** @param list<string> $paths */
    private function removeTempPaths(array $paths): void
    {
        foreach ($paths as $path) {
            if (file_exists($path)) {
                unlink($path);
            }
        }
    }

    private function postgresConcurrencyWorkerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Institution\ArchiveInstitutionGroup;
use App\Actions\Institution\RemoveTeacherFromInstitutionGroup;
use App\Actions\Teacher\RemoveTeacherLearningMaterial;
use App\Actions\Teacher\ReplaceTeacherLearningMaterial;
use App\Actions\Teacher\UploadTeacherLearningMaterial;
use App\Exceptions\Teacher\TopicNotEditableException;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S05 BE 003 concurrency institution']);
    $teacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
    $admin = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $groups = [];
    $topics = [];
    $materials = [];
    $scenarios = [
        'upload_archive', 'archive_upload', 'upload_membership', 'membership_upload',
        'replace_archive', 'archive_replace', 'replace_membership', 'membership_replace',
        'replace_remove', 'remove_replace',
    ];

    foreach ($scenarios as $scenario) {
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
            'name' => 'Material race '.$scenario,
        ]);
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
        $groups[$scenario] = $group->id;
        $topics[$scenario] = $topic->id;

        if (str_contains($scenario, 'replace')) {
            $file = File::factory()->create([
                'institution_id' => $institution->id,
                'uploaded_by_user_id' => $teacher->id,
                'storage_key' => 'learning-materials/'.$institution->id.'/'.$topic->id.'/old-'.$scenario.'.pdf',
                'size_bytes' => 12,
            ]);
            $materials[$scenario] = LearningMaterial::factory()->create([
                'institution_id' => $institution->id,
                'topic_id' => $topic->id,
                'teacher_id' => $teacher->id,
                'file_id' => $file->id,
                'title' => 'Original',
            ])->id;
        }
    }

    echo json_encode([
        'institution' => $institution->id,
        'teacher' => $teacher->id,
        'admin' => $admin->id,
        'groups' => $groups,
        'topics' => $topics,
        'materials' => $materials,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    LearningMaterial::query()->where('institution_id', $institutionId)->delete();
    File::query()->where('institution_id', $institutionId)->delete();
    Topic::query()->where('institution_id', $institutionId)->delete();
    GroupTeacherMembership::query()->where('institution_id', $institutionId)->delete();
    Group::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->whereKey($institutionId)->delete();
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    Storage::disk(config('filesystems.private_files_disk'))->deleteDirectory('learning-materials/'.$institutionId);
    echo '{}';
    exit(0);
}

$teacher = User::query()->findOrFail($argv[3]);
$admin = User::query()->findOrFail($argv[4]);
$groupId = $argv[5];
$topicId = $argv[6];
$materialId = $argv[7];
$operation = $argv[8];
$hold = $argv[9] === 'hold';
$lockedPath = $argv[10];
$releasePath = $argv[11];
$attemptPath = $argv[12];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);

if ($hold) {
    DB::beginTransaction();
}

$outcome = 'ok';
$uploadPath = tempnam(sys_get_temp_dir(), 's05_be_003_race_upload_');
file_put_contents($uploadPath, "%PDF-1.7\nRace");
$upload = new UploadedFile($uploadPath, 'race.pdf', 'application/octet-stream', UPLOAD_ERR_OK, true);

try {
    match ($operation) {
        'upload' => app(UploadTeacherLearningMaterial::class)($teacher, $topicId, $upload, null),
        'replace' => app(ReplaceTeacherLearningMaterial::class)($teacher, $materialId, $upload),
        'archive' => app(ArchiveInstitutionGroup::class)($admin, $groupId),
        'membership_remove' => app(RemoveTeacherFromInstitutionGroup::class)($admin, $groupId, $teacher->id),
        'material_remove' => app(RemoveTeacherLearningMaterial::class)($teacher, $materialId),
    };
} catch (NotFoundHttpException) {
    $outcome = 'not_found';
} catch (TopicNotEditableException) {
    $outcome = 'topic_not_editable';
} finally {
    unlink($uploadPath);
}

if ($hold) {
    file_put_contents($lockedPath, 'locked');
    $deadline = microtime(true) + 15;
    while (! file_exists($releasePath) && microtime(true) < $deadline) {
        usleep(5_000);
    }
    if (! file_exists($releasePath)) {
        DB::rollBack();
        fwrite(STDERR, 'Timed out waiting for deterministic race release.');
        exit(1);
    }
    DB::commit();
}

echo json_encode(['outcome' => $outcome], JSON_THROW_ON_ERROR);
PHP;
    }
}
