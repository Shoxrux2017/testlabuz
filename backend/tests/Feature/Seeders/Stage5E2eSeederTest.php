<?php

namespace Tests\Feature\Seeders;

use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Enums\TopicStatus;
use App\Models\File;
use App\Models\Institution;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Database\Seeders\Stage5E2eSeeder;
use Illuminate\Filesystem\Filesystem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Tests\TestCase;

class Stage5E2eSeederTest extends TestCase
{
    use RefreshDatabase;

    private const TARGET_INSTITUTION_ID = '05000000-0000-4000-8000-000000000101';

    private const TARGET_TEACHER_ID = '05000000-0000-4000-9000-000000000201';

    private const GROUP_A_ID = '05000000-0000-4000-a000-000000000101';

    private const SEEDED_TARGET_TOPIC_ID = '05000000-0000-4000-c000-000000000101';

    private string $privateRoot;

    protected function setUp(): void
    {
        parent::setUp();

        $this->privateRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'testlabuz-stage5-seeder-'.Str::uuid();
        (new Filesystem)->makeDirectory($this->privateRoot, 0700, true);
        config([
            'filesystems.private_files_disk' => 'local',
            'filesystems.disks.local' => [
                'driver' => 'local',
                'root' => $this->privateRoot,
                'throw' => false,
                'visibility' => 'private',
            ],
        ]);
        Storage::forgetDisk('local');
        $this->setPassword();
    }

    public function test_seeder_refuses_unsafe_runtime_and_private_storage_facts_before_mutation(): void
    {
        $unrelated = Institution::factory()->create(['name' => 'Preserved Stage 5 runtime guard Institution']);
        $unsafeSeeders = [
            new class($this->privateRoot) extends IsolatedStage5E2eSeeder
            {
                protected function runtimeEnvironment(): string
                {
                    return 'local';
                }
            },
            new class($this->privateRoot) extends IsolatedStage5E2eSeeder
            {
                protected function connectionDriver(): string
                {
                    return 'sqlite';
                }
            },
            new class($this->privateRoot) extends IsolatedStage5E2eSeeder
            {
                protected function pdoDriver(): string
                {
                    return 'mysql';
                }
            },
            new class($this->privateRoot) extends IsolatedStage5E2eSeeder
            {
                protected function currentDatabase(): string
                {
                    return 'testlabuz';
                }
            },
        ];

        foreach ($unsafeSeeders as $seeder) {
            try {
                $seeder->run();
                self::fail('The Stage 5 E2E seeder accepted unsafe runtime facts.');
            } catch (RuntimeException) {
                $this->assertDatabaseHas('institutions', ['id' => $unrelated->id]);
                $this->assertDatabaseMissing('institutions', ['id' => self::TARGET_INSTITUTION_ID]);
            }
        }

        config(['filesystems.private_files_disk' => 'public']);
        try {
            $this->stage5Seeder()->run();
            self::fail('The Stage 5 E2E seeder accepted the public disk.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('exact local private storage root', $exception->getMessage());
        }

        config([
            'filesystems.private_files_disk' => 'local',
            'filesystems.disks.local.root' => $this->privateRoot.DIRECTORY_SEPARATOR.'wrong',
        ]);
        (new Filesystem)->makeDirectory($this->privateRoot.DIRECTORY_SEPARATOR.'wrong', 0700, true);
        Storage::forgetDisk('local');
        try {
            $this->stage5Seeder()->run();
            self::fail('The Stage 5 E2E seeder accepted the wrong private root.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('exact local private storage root', $exception->getMessage());
        }
    }

    public function test_seeder_requires_a_non_blank_transient_password(): void
    {
        $this->clearPassword();

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('STAGE5_E2E_PASSWORD must be provided');

        $this->stage5Seeder()->run();
    }

    public function test_fixed_and_dynamic_manifest_collisions_fail_before_database_or_blob_mutation(): void
    {
        $this->stage5Seeder()->run();
        $fixedBlob = $this->fixedTargetBlobKey();
        $fixedBytes = Storage::disk('local')->get($fixedBlob);
        Institution::query()->whereKey(self::TARGET_INSTITUTION_ID)->update(['name' => 'Collision']);

        try {
            $this->stage5Seeder()->run();
            self::fail('The Stage 5 E2E seeder accepted a fixed manifest collision.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('Institution manifest collision', $exception->getMessage());
        }
        self::assertSame($fixedBytes, Storage::disk('local')->get($fixedBlob));
        $this->assertDatabaseHas('institutions', ['id' => self::TARGET_INSTITUTION_ID, 'name' => 'Collision']);

        Institution::query()->whereKey(self::TARGET_INSTITUTION_ID)->update(['name' => 'E2E S05 Target Institution']);
        Topic::factory()->create([
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'group_id' => self::GROUP_A_ID,
            'teacher_id' => self::TARGET_TEACHER_ID,
            'title' => 'E2E S05 UI Topic',
            'subject' => 'Wrong subject',
            'description' => 'E2E S05 integration topic',
            'student_instructions' => 'E2E S05 Student instructions',
        ]);

        try {
            $this->stage5Seeder()->run();
            self::fail('The Stage 5 E2E seeder accepted a dynamic Topic collision.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('dynamic Topic ownership collision', $exception->getMessage());
        }
        self::assertSame($fixedBytes, Storage::disk('local')->get($fixedBlob));
    }

    public function test_dynamic_material_file_and_namespace_collisions_fail_closed(): void
    {
        $this->stage5Seeder()->run();
        $dynamic = $this->createDynamicTopic();
        $file = File::factory()->create([
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'uploaded_by_user_id' => '05000000-0000-4000-9000-000000000204',
            'category' => FileCategory::LearningMaterial,
            'original_name' => 'e2e_s05_material.pdf',
            'storage_disk' => 'local',
            'storage_key' => $this->dynamicBlobKey($dynamic->id, '11111111-1111-4111-8111-111111111111.pdf'),
            'mime_type' => 'application/pdf',
            'extension' => FileExtension::Pdf,
            'size_bytes' => 20,
            'checksum_sha256' => str_repeat('a', 64),
        ]);
        LearningMaterial::factory()->create([
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'topic_id' => $dynamic->id,
            'teacher_id' => self::TARGET_TEACHER_ID,
            'file_id' => $file->id,
        ]);

        try {
            $this->stage5Seeder()->run();
            self::fail('The Stage 5 E2E seeder accepted a partial dynamic material/file collision.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('dynamic material/file ownership collision', $exception->getMessage());
        }
        $this->assertDatabaseHas('files', ['id' => $file->id]);

        LearningMaterial::query()->where('file_id', $file->id)->delete();
        File::query()->whereKey($file->id)->delete();
        Storage::disk('local')->put($this->dynamicBlobKey($dynamic->id, 'unexpected.txt'), 'collision');

        try {
            $this->stage5Seeder()->run();
            self::fail('The Stage 5 E2E seeder accepted an unexpected namespace file shape.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('unexpected blob filename', $exception->getMessage());
        }
        self::assertTrue(Storage::disk('local')->exists($this->dynamicBlobKey($dynamic->id, 'unexpected.txt')));
    }

    public function test_seeder_safely_cleans_interrupted_dynamic_orphan_and_manual_smoke_lineage(): void
    {
        $this->stage5Seeder()->run();
        $dynamic = $this->createDynamicTopic();
        $dynamicFile = $this->createOwnedMaterial(
            topic: $dynamic,
            originalName: 'e2e_s05_material.pdf',
            blobName: '22222222-2222-4222-8222-222222222222.pdf',
        );
        $orphanKey = $this->dynamicBlobKey($dynamic->id, '33333333-3333-4333-8333-333333333333.pdf');
        Storage::disk('local')->put($orphanKey, "%PDF-1.7\norphan");

        $seededTopic = Topic::query()->findOrFail(self::SEEDED_TARGET_TOPIC_ID);
        $manualFile = $this->createOwnedMaterial(
            topic: $seededTopic,
            originalName: 'e2e_s05_manual_smoke.pdf',
            blobName: '44444444-4444-4444-8444-444444444444.pdf',
        );

        $this->stage5Seeder()->run();

        $this->assertDatabaseMissing('topics', ['id' => $dynamic->id]);
        $this->assertDatabaseMissing('files', ['id' => $dynamicFile->id]);
        $this->assertDatabaseMissing('files', ['id' => $manualFile->id]);
        self::assertFalse(Storage::disk('local')->exists($orphanKey));
        self::assertFalse(Storage::disk('local')->exists($dynamicFile->storage_key));
        self::assertFalse(Storage::disk('local')->exists($manualFile->storage_key));
        $this->assertDatabaseHas('topics', ['id' => self::SEEDED_TARGET_TOPIC_ID, 'status' => TopicStatus::Active->value]);
    }

    public function test_owned_tokens_are_removed_while_unrelated_rows_tokens_and_blobs_are_preserved_byte_for_byte(): void
    {
        $this->stage5Seeder()->run();
        $ownedUser = User::query()->findOrFail(self::TARGET_TEACHER_ID);
        $ownedTokenId = $ownedUser->createToken('owned-stage5-token')->accessToken->id;

        $unrelatedInstitution = Institution::factory()->create(['name' => 'Unrelated Stage 5 sentinel Institution']);
        $unrelatedUser = User::factory()->teacher($unrelatedInstitution)->create();
        $unrelatedTokenId = $unrelatedUser->createToken('unrelated-stage5-token')->accessToken->id;
        $unrelatedBlobKey = 'unrelated-stage5/'.Str::uuid().'.pdf';
        $unrelatedBlobBytes = "%PDF-1.7\nunrelated-stage5";
        Storage::disk('local')->put($unrelatedBlobKey, $unrelatedBlobBytes);
        $before = json_encode([
            'institution' => DB::table('institutions')->where('id', $unrelatedInstitution->id)->first(),
            'user' => DB::table('users')->where('id', $unrelatedUser->id)->first(),
            'token' => DB::table('personal_access_tokens')->where('id', $unrelatedTokenId)->first(),
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

        $this->stage5Seeder()->run();

        $after = json_encode([
            'institution' => DB::table('institutions')->where('id', $unrelatedInstitution->id)->first(),
            'user' => DB::table('users')->where('id', $unrelatedUser->id)->first(),
            'token' => DB::table('personal_access_tokens')->where('id', $unrelatedTokenId)->first(),
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        self::assertSame($before, $after);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $ownedTokenId]);
        $this->assertDatabaseHas('personal_access_tokens', ['id' => $unrelatedTokenId]);
        self::assertSame($unrelatedBlobBytes, Storage::disk('local')->get($unrelatedBlobKey));
    }

    public function test_reset_failure_after_blob_cleanup_is_recoverable_on_the_next_guarded_run(): void
    {
        $this->stage5Seeder()->run();
        $fixedBlob = $this->fixedTargetBlobKey();
        self::assertTrue(Storage::disk('local')->exists($fixedBlob));

        try {
            (new ResetFailingStage5E2eSeeder($this->privateRoot))->run();
            self::fail('The reset-failure seam did not fail.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('reset failure', $exception->getMessage());
        }

        $this->assertDatabaseHas('topics', ['id' => self::SEEDED_TARGET_TOPIC_ID]);
        self::assertFalse(Storage::disk('local')->exists($fixedBlob));

        $this->stage5Seeder()->run();

        $this->assertDatabaseHas('topics', ['id' => self::SEEDED_TARGET_TOPIC_ID]);
        self::assertTrue(Storage::disk('local')->exists($fixedBlob));
    }

    public function test_creation_failure_compensates_new_blobs_and_a_following_run_recreates_the_world(): void
    {
        try {
            (new CreationFailingStage5E2eSeeder($this->privateRoot))->run();
            self::fail('The creation-failure seam did not fail.');
        } catch (RuntimeException $exception) {
            self::assertStringContainsString('creation failure', $exception->getMessage());
        }

        $this->assertDatabaseMissing('institutions', ['id' => self::TARGET_INSTITUTION_ID]);
        self::assertFalse(Storage::disk('local')->exists($this->fixedTargetBlobKey()));

        $this->stage5Seeder()->run();

        $this->assertDatabaseHas('institutions', ['id' => self::TARGET_INSTITUTION_ID]);
        self::assertTrue(Storage::disk('local')->exists($this->fixedTargetBlobKey()));
    }

    public function test_two_consecutive_runs_produce_the_same_logical_baseline_and_matching_blob_checksums(): void
    {
        $executionStartedAt = CarbonImmutable::now();
        $this->stage5Seeder()->run();
        $this->assertDeterministicInitialChronology($executionStartedAt);
        $first = $this->logicalSnapshot();
        $this->stage5Seeder()->run();
        $second = $this->logicalSnapshot();

        self::assertSame($first, $second);
        self::assertCount(3, DB::table('institutions')->where('name', 'like', 'E2E S05%')->get());
        self::assertCount(11, DB::table('users')->where('login_name', 'like', 'e2e_s05_%')->get());
        self::assertCount(6, DB::table('topics')->where('title', 'like', 'E2E S05%')->get());
        self::assertCount(4, DB::table('learning_materials')->whereIn('institution_id', [
            self::TARGET_INSTITUTION_ID,
            '05000000-0000-4000-8000-000000000103',
        ])->get());

        foreach (File::query()->whereIn('institution_id', $this->stage5InstitutionIds())->get() as $file) {
            $bytes = Storage::disk('local')->get($file->storage_key);
            self::assertSame($file->checksum_sha256, hash('sha256', $bytes));
        }
        self::assertTrue(Hash::check($this->password(), User::query()->findOrFail(self::TARGET_TEACHER_ID)->password));
    }

    protected function tearDown(): void
    {
        $this->clearPassword();
        Storage::forgetDisk('local');
        if (isset($this->privateRoot)) {
            (new Filesystem)->deleteDirectory($this->privateRoot);
        }
        parent::tearDown();
    }

    private function stage5Seeder(): IsolatedStage5E2eSeeder
    {
        return new IsolatedStage5E2eSeeder($this->privateRoot);
    }

    private function createDynamicTopic(): Topic
    {
        return Topic::factory()->create([
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'group_id' => self::GROUP_A_ID,
            'teacher_id' => self::TARGET_TEACHER_ID,
            'title' => 'E2E S05 UI Topic',
            'subject' => 'E2E S05 Subject',
            'description' => 'E2E S05 integration topic',
            'student_instructions' => 'E2E S05 Student instructions',
            'lesson_at' => null,
            'status' => TopicStatus::Draft,
        ]);
    }

    private function createOwnedMaterial(Topic $topic, string $originalName, string $blobName): File
    {
        $bytes = "%PDF-1.7\n{$originalName}";
        $key = $this->dynamicBlobKey($topic->id, $blobName);
        Storage::disk('local')->put($key, $bytes);
        $file = File::factory()->create([
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'uploaded_by_user_id' => self::TARGET_TEACHER_ID,
            'category' => FileCategory::LearningMaterial,
            'original_name' => $originalName,
            'storage_disk' => 'local',
            'storage_key' => $key,
            'mime_type' => 'application/pdf',
            'extension' => FileExtension::Pdf,
            'size_bytes' => strlen($bytes),
            'checksum_sha256' => hash('sha256', $bytes),
        ]);
        LearningMaterial::factory()->create([
            'institution_id' => self::TARGET_INSTITUTION_ID,
            'topic_id' => $topic->id,
            'teacher_id' => self::TARGET_TEACHER_ID,
            'file_id' => $file->id,
        ]);

        return $file;
    }

    private function dynamicBlobKey(string $topicId, string $name): string
    {
        return 'learning-materials/'.self::TARGET_INSTITUTION_ID.'/'.$topicId.'/'.$name;
    }

    private function fixedTargetBlobKey(): string
    {
        return $this->dynamicBlobKey(self::SEEDED_TARGET_TOPIC_ID, '05000000-0000-4000-f000-000000000101.pdf');
    }

    private function assertDeterministicInitialChronology(CarbonImmutable $executionStartedAt): void
    {
        $institutions = DB::table('institutions')->whereIn('id', $this->stage5InstitutionIds())->get();
        $settings = DB::table('institution_settings')->whereIn('institution_id', $this->stage5InstitutionIds())->get();
        $users = DB::table('users')->where('login_name', 'like', 'e2e_s05_%')->get();
        $groups = DB::table('groups')->whereIn('id', $this->stage5GroupIds())->get();
        $teacherMemberships = DB::table('group_teacher_memberships')->whereIn('group_id', $this->stage5GroupIds())->get();
        $studentMemberships = DB::table('group_student_memberships')->whereIn('group_id', $this->stage5GroupIds())->get();
        $topics = DB::table('topics')->where('title', 'like', 'E2E S05%')->get();
        $materials = DB::table('learning_materials')->whereIn('institution_id', $this->stage5InstitutionIds())->get();
        $files = DB::table('files')->whereIn('institution_id', $this->stage5InstitutionIds())->get();

        self::assertSame(
            CarbonImmutable::parse('2020-05-01 08:00:00+00')->getTimestamp(),
            $this->timestamp($institutions->min('created_at')),
        );

        $prerequisiteCreationTimestamps = collect([
            ...$institutions->pluck('created_at'),
            ...$users->pluck('created_at'),
            ...$groups->pluck('created_at'),
            ...$teacherMemberships->pluck('created_at'),
            ...$studentMemberships->pluck('created_at'),
        ])->map(fn (mixed $value): int => $this->timestamp($value));
        $topicCreationTimestamps = $topics->pluck('created_at')->map(fn (mixed $value): int => $this->timestamp($value));
        self::assertTrue($prerequisiteCreationTimestamps->max() < $topicCreationTimestamps->min());

        $activeTopicActivationTimestamps = collect();
        foreach ($topics as $topic) {
            $createdAt = $this->timestamp($topic->created_at);
            if ($topic->status === TopicStatus::Active->value) {
                self::assertNotNull($topic->activated_at);
                $activatedAt = $this->timestamp($topic->activated_at);
                self::assertTrue($createdAt < $activatedAt);
                self::assertSame($activatedAt, $this->timestamp($topic->updated_at));
                $activeTopicActivationTimestamps->push($activatedAt);
            } else {
                self::assertNull($topic->activated_at);
                self::assertSame($createdAt, $this->timestamp($topic->updated_at));
            }
        }

        $contentCreationTimestamps = collect([
            ...$materials->pluck('created_at'),
            ...$files->pluck('created_at'),
        ])->map(fn (mixed $value): int => $this->timestamp($value));
        self::assertTrue($activeTopicActivationTimestamps->max() < $contentCreationTimestamps->min());

        $archivedGroup = $groups->firstWhere('id', '05000000-0000-4000-a000-000000000103');
        self::assertNotNull($archivedGroup);
        self::assertNotNull($archivedGroup->archived_at);
        $groupArchivedAt = $this->timestamp($archivedGroup->archived_at);
        self::assertSame(CarbonImmutable::parse('2020-05-04 12:00:00+00')->getTimestamp(), $groupArchivedAt);
        self::assertTrue($contentCreationTimestamps->max() < $groupArchivedAt);

        foreach ($groups as $group) {
            $expectedUpdatedAt = $group->archived_at ?? $group->created_at;
            self::assertSame($this->timestamp($expectedUpdatedAt), $this->timestamp($group->updated_at));
        }
        foreach ([...$teacherMemberships, ...$studentMemberships] as $membership) {
            self::assertSame($this->timestamp($membership->started_at), $this->timestamp($membership->created_at));
            $expectedUpdatedAt = $membership->ended_at ?? $membership->started_at;
            self::assertSame($this->timestamp($expectedUpdatedAt), $this->timestamp($membership->updated_at));
            if ($membership->ended_at !== null) {
                self::assertTrue($this->timestamp($membership->started_at) < $this->timestamp($membership->ended_at));
            }
        }
        foreach ([$institutions, $settings, $users, $materials, $files] as $unchangedRows) {
            foreach ($unchangedRows as $row) {
                self::assertSame($this->timestamp($row->created_at), $this->timestamp($row->updated_at));
            }
        }

        $historicalTimestamps = [];
        $appendTimestamps = static function (iterable $rows, array $columns) use (&$historicalTimestamps): void {
            foreach ($rows as $row) {
                foreach ($columns as $column) {
                    if ($row->{$column} !== null) {
                        $historicalTimestamps[] = $row->{$column};
                    }
                }
            }
        };
        $appendTimestamps($institutions, ['created_at', 'updated_at']);
        $appendTimestamps($settings, ['created_at', 'updated_at']);
        $appendTimestamps($users, ['created_at', 'updated_at']);
        $appendTimestamps($groups, ['created_at', 'updated_at', 'archived_at']);
        $appendTimestamps($teacherMemberships, ['started_at', 'ended_at', 'created_at', 'updated_at']);
        $appendTimestamps($studentMemberships, ['started_at', 'ended_at', 'created_at', 'updated_at']);
        $appendTimestamps($topics, ['created_at', 'updated_at', 'activated_at']);
        $appendTimestamps($materials, ['created_at', 'updated_at']);
        $appendTimestamps($files, ['created_at', 'updated_at']);
        foreach ($historicalTimestamps as $timestamp) {
            self::assertTrue($this->timestamp($timestamp) < $executionStartedAt->getTimestamp());
        }
    }

    private function timestamp(mixed $value): int
    {
        return CarbonImmutable::parse((string) $value)->getTimestamp();
    }

    private function logicalSnapshot(): string
    {
        return json_encode([
            'institutions' => DB::table('institutions')->where('name', 'like', 'E2E S05%')->orderBy('id')->get(),
            'settings' => DB::table('institution_settings')->whereIn('institution_id', [
                self::TARGET_INSTITUTION_ID,
                '05000000-0000-4000-8000-000000000102',
                '05000000-0000-4000-8000-000000000103',
            ])->orderBy('institution_id')->get(),
            'users' => DB::table('users')->where('login_name', 'like', 'e2e_s05_%')->select([
                'id', 'institution_id', 'role', 'full_name', 'login_name', 'email', 'phone', 'is_active',
                'must_change_password', 'last_login_at', 'deactivated_at', 'created_by_user_id', 'created_at', 'updated_at',
            ])->orderBy('id')->get(),
            'groups' => DB::table('groups')->where('name', 'like', 'E2E S05%')->orderBy('id')->get(),
            'teacher_memberships' => DB::table('group_teacher_memberships')->whereIn('group_id', $this->stage5GroupIds())->orderBy('id')->get(),
            'student_memberships' => DB::table('group_student_memberships')->whereIn('group_id', $this->stage5GroupIds())->orderBy('id')->get(),
            'topics' => DB::table('topics')->where('title', 'like', 'E2E S05%')->orderBy('id')->get(),
            'materials' => DB::table('learning_materials')->whereIn('institution_id', $this->stage5InstitutionIds())->orderBy('id')->get(),
            'files' => DB::table('files')->whereIn('institution_id', $this->stage5InstitutionIds())->orderBy('id')->get(),
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
    }

    /** @return list<string> */
    private function stage5InstitutionIds(): array
    {
        return [
            self::TARGET_INSTITUTION_ID,
            '05000000-0000-4000-8000-000000000102',
            '05000000-0000-4000-8000-000000000103',
        ];
    }

    /** @return list<string> */
    private function stage5GroupIds(): array
    {
        return [
            self::GROUP_A_ID,
            '05000000-0000-4000-a000-000000000102',
            '05000000-0000-4000-a000-000000000103',
            '05000000-0000-4000-a000-000000000201',
            '05000000-0000-4000-a000-000000000301',
        ];
    }

    private function setPassword(): void
    {
        $password = $this->password();
        putenv('STAGE5_E2E_PASSWORD='.$password);
        $_ENV['STAGE5_E2E_PASSWORD'] = $password;
        $_SERVER['STAGE5_E2E_PASSWORD'] = $password;
    }

    private function clearPassword(): void
    {
        putenv('STAGE5_E2E_PASSWORD');
        unset($_ENV['STAGE5_E2E_PASSWORD'], $_SERVER['STAGE5_E2E_PASSWORD']);
    }

    private function password(): string
    {
        return 'S05-Test-Aa9-Deterministic-Password';
    }
}

class IsolatedStage5E2eSeeder extends Stage5E2eSeeder
{
    public function __construct(private readonly string $isolatedPrivateRoot) {}

    protected function expectedPrivateRoot(): string
    {
        return $this->isolatedPrivateRoot;
    }
}

class ResetFailingStage5E2eSeeder extends IsolatedStage5E2eSeeder
{
    protected function beforeDatabaseResetCommit(): void
    {
        throw new RuntimeException('Injected Stage 5 reset failure.');
    }
}

class CreationFailingStage5E2eSeeder extends IsolatedStage5E2eSeeder
{
    protected function beforeDatabaseCreationCommit(): void
    {
        throw new RuntimeException('Injected Stage 5 creation failure.');
    }
}
