<?php

namespace Database\Seeders;

use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Enums\GroupStatus;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Seeder;
use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Throwable;

class Stage5E2eSeeder extends Seeder
{
    private const TEST_DATABASE = 'testlabuz_testing';

    private const PASSWORD_ENVIRONMENT_NAME = 'STAGE5_E2E_PASSWORD';

    private const TARGET_INSTITUTION_ID = '05000000-0000-4000-8000-000000000101';

    private const LOW_LIMIT_INSTITUTION_ID = '05000000-0000-4000-8000-000000000102';

    private const FOREIGN_INSTITUTION_ID = '05000000-0000-4000-8000-000000000103';

    private const TARGET_ADMIN_ID = '05000000-0000-4000-9000-000000000101';

    private const TARGET_TEACHER_ID = '05000000-0000-4000-9000-000000000201';

    private const TARGET_STUDENT_ID = '05000000-0000-4000-9000-000000000202';

    private const ENDED_STUDENT_ID = '05000000-0000-4000-9000-000000000203';

    private const UNRELATED_TEACHER_ID = '05000000-0000-4000-9000-000000000204';

    private const UNRELATED_STUDENT_ID = '05000000-0000-4000-9000-000000000205';

    private const LOW_LIMIT_ADMIN_ID = '05000000-0000-4000-9000-000000000301';

    private const LOW_LIMIT_TEACHER_ID = '05000000-0000-4000-9000-000000000302';

    private const FOREIGN_ADMIN_ID = '05000000-0000-4000-9000-000000000401';

    private const FOREIGN_TEACHER_ID = '05000000-0000-4000-9000-000000000402';

    private const FOREIGN_STUDENT_ID = '05000000-0000-4000-9000-000000000403';

    private const GROUP_A_ID = '05000000-0000-4000-a000-000000000101';

    private const GROUP_B_ID = '05000000-0000-4000-a000-000000000102';

    private const GROUP_C_ID = '05000000-0000-4000-a000-000000000103';

    private const LOW_LIMIT_GROUP_ID = '05000000-0000-4000-a000-000000000201';

    private const FOREIGN_GROUP_ID = '05000000-0000-4000-a000-000000000301';

    private const SEEDED_TARGET_TOPIC_ID = '05000000-0000-4000-c000-000000000101';

    private const SEEDED_DRAFT_TOPIC_ID = '05000000-0000-4000-c000-000000000102';

    private const UNRELATED_TOPIC_ID = '05000000-0000-4000-c000-000000000103';

    private const ARCHIVED_GROUP_TOPIC_ID = '05000000-0000-4000-c000-000000000104';

    private const LOW_LIMIT_TOPIC_ID = '05000000-0000-4000-c000-000000000201';

    private const FOREIGN_TOPIC_ID = '05000000-0000-4000-c000-000000000301';

    private const DYNAMIC_TOPIC_TITLE = 'E2E S05 UI Topic';

    private const MANUAL_ORIGINAL_NAME = 'e2e_s05_manual_smoke.pdf';

    private const AUTOMATED_ORIGINAL_NAMES = [
        'e2e_s05_material.pdf',
        'e2e_s05_material.docx',
        'e2e_s05_material.ppt',
        'e2e_s05_material.pptx',
        'e2e_s05_replacement.pdf',
        'e2e_s05_unsupported.txt',
        'e2e_s05_low_limit_over.pdf',
        'e2e_s05_platform_over.pdf',
    ];

    public function run(): void
    {
        $this->assertSafeRuntime();
        $password = $this->requiredPassword();
        $ownership = $this->assertOwnershipGraphSafe();
        $ownedBlobKeys = $this->assertPrivateBlobOwnershipSafe($ownership);

        $this->deleteOwnedBlobs($ownedBlobKeys);
        $this->deleteOwnedDynamicNamespace($ownership['dynamic_topic_id']);

        DB::transaction(function () use ($ownership): void {
            $this->resetOwnedDatabaseRows($ownership);
            $this->beforeDatabaseResetCommit();
        });

        $newBlobKeys = [];
        try {
            foreach ($this->fileManifest() as $specification) {
                $key = $specification['storage_key'];
                $bytes = $this->seededPdfBytes($specification['fixture_key']);
                if (! $this->privateDisk()->put($key, $bytes)) {
                    throw new RuntimeException('Stage 5 E2E seeded private blob creation failed.');
                }
                $newBlobKeys[] = $key;
            }

            DB::transaction(function () use ($password): void {
                $this->createFixedManifest($password);
                $this->beforeDatabaseCreationCommit();
            });
        } catch (Throwable $exception) {
            $this->deleteOwnedBlobs($newBlobKeys);

            throw $exception;
        }

        $this->assertSeededBlobChecksums();
    }

    protected function runtimeEnvironment(): string
    {
        return app()->environment();
    }

    protected function currentDatabase(): string
    {
        return (string) DB::scalar('select current_database()');
    }

    protected function connectionDriver(): string
    {
        return DB::connection()->getDriverName();
    }

    protected function pdoDriver(): string
    {
        return (string) DB::connection()->getPdo()->getAttribute(\PDO::ATTR_DRIVER_NAME);
    }

    protected function expectedPrivateRoot(): string
    {
        return storage_path('app/private');
    }

    protected function beforeDatabaseResetCommit(): void {}

    protected function beforeDatabaseCreationCommit(): void {}

    private function assertSafeRuntime(): void
    {
        if ($this->runtimeEnvironment() !== 'testing') {
            throw new RuntimeException('Stage5E2eSeeder may only run with APP_ENV=testing.');
        }
        if ($this->connectionDriver() !== 'pgsql' || $this->pdoDriver() !== 'pgsql') {
            throw new RuntimeException('Stage5E2eSeeder requires Laravel pgsql and PDO pgsql.');
        }
        if ($this->currentDatabase() !== self::TEST_DATABASE) {
            throw new RuntimeException('Stage5E2eSeeder may only run against testlabuz_testing.');
        }

        $diskName = config('filesystems.private_files_disk');
        $disk = is_string($diskName) ? config("filesystems.disks.{$diskName}") : null;
        $configuredRoot = is_array($disk) ? ($disk['root'] ?? null) : null;
        $expectedRoot = realpath($this->expectedPrivateRoot());
        $resolvedRoot = is_string($configuredRoot) ? realpath($configuredRoot) : false;

        if (
            $diskName !== 'local'
            || ! is_array($disk)
            || ($disk['driver'] ?? null) !== 'local'
            || ($disk['visibility'] ?? null) === 'public'
            || ! is_string($expectedRoot)
            || ! is_string($resolvedRoot)
            || $resolvedRoot !== $expectedRoot
        ) {
            throw new RuntimeException('Stage5E2eSeeder requires the exact local private storage root.');
        }
    }

    private function requiredPassword(): string
    {
        $password = env(self::PASSWORD_ENVIRONMENT_NAME);
        if (! is_string($password) || trim($password) === '') {
            throw new RuntimeException(self::PASSWORD_ENVIRONMENT_NAME.' must be provided by the local environment.');
        }

        return $password;
    }

    /**
     * @return array{dynamic_topic_id: ?string, material_ids: list<string>, file_ids: list<string>, file_keys: list<string>}
     */
    private function assertOwnershipGraphSafe(): array
    {
        $this->assertInstitutionManifestSafe();
        $this->assertUserManifestSafe();
        $this->assertSettingManifestSafe();
        $this->assertGroupManifestSafe();
        $this->assertMembershipManifestSafe();
        $dynamicTopicId = $this->assertTopicManifestSafe();

        return $this->assertMaterialAndFileManifestSafe($dynamicTopicId);
    }

    private function assertInstitutionManifestSafe(): void
    {
        $manifest = $this->institutionManifest();
        $rows = Institution::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('name', array_column($manifest, 'name'))
            ->orWhere('name', 'like', 'E2E S05%')
            ->get();

        foreach ($rows as $institution) {
            $expected = $manifest[$institution->id] ?? null;
            if (
                $expected === null
                || $institution->name !== $expected['name']
                || $institution->type->value !== $expected['type']
                || $institution->status !== InstitutionStatus::Active
            ) {
                throw new RuntimeException('Stage 5 E2E Institution manifest collision detected.');
            }
        }
    }

    private function assertUserManifestSafe(): void
    {
        $manifest = $this->userManifest();
        $rows = User::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('login_name', array_column($manifest, 'login_name'))
            ->orWhere('login_name', 'like', 'e2e_s05_%')
            ->orWhere('full_name', 'like', 'E2E S05%')
            ->get();

        foreach ($rows as $user) {
            $expected = $manifest[$user->id] ?? null;
            if (
                $expected === null
                || $user->login_name !== $expected['login_name']
                || $user->full_name !== $expected['full_name']
                || $user->role->value !== $expected['role']
                || $user->institution_id !== $expected['institution_id']
                || ! $user->is_active
                || $user->must_change_password
            ) {
                throw new RuntimeException('Stage 5 E2E User manifest collision detected.');
            }
        }
    }

    private function assertSettingManifestSafe(): void
    {
        foreach (InstitutionSetting::query()->whereIn('institution_id', array_keys($this->institutionManifest()))->get() as $setting) {
            $expectedLimit = $setting->institution_id === self::LOW_LIMIT_INSTITUTION_ID ? 1 : 25;
            if (
                $setting->timezone !== 'Asia/Tashkent'
                || $setting->learning_material_max_mb !== $expectedLimit
                || $setting->student_submission_max_mb !== 15
                || $setting->acceptable_score_difference !== null
                || $setting->blitz_timer_start_mode !== null
                || $setting->student_result_release_mode !== null
                || $setting->parent_result_release_mode !== null
                || $setting->updated_by_user_id !== null
            ) {
                throw new RuntimeException('Stage 5 E2E Institution setting manifest collision detected.');
            }
        }
    }

    private function assertGroupManifestSafe(): void
    {
        $manifest = $this->groupManifest();
        $rows = Group::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhereIn('name', array_column($manifest, 'name'))
            ->orWhere('name', 'like', 'E2E S05%')
            ->orWhereIn('created_by_user_id', [self::TARGET_ADMIN_ID, self::LOW_LIMIT_ADMIN_ID, self::FOREIGN_ADMIN_ID])
            ->get();

        foreach ($rows as $group) {
            $expected = $manifest[$group->id] ?? null;
            if (
                $expected === null
                || $group->name !== $expected['name']
                || $group->institution_id !== $expected['institution_id']
                || $group->created_by_user_id !== $expected['created_by_user_id']
                || $group->status->value !== $expected['status']
            ) {
                throw new RuntimeException('Stage 5 E2E Group manifest collision detected.');
            }
        }
    }

    private function assertMembershipManifestSafe(): void
    {
        $teacherManifest = $this->teacherMembershipManifest();
        $teacherRows = GroupTeacherMembership::query()
            ->whereIn('id', array_keys($teacherManifest))
            ->orWhereIn('group_id', array_keys($this->groupManifest()))
            ->orWhereIn('teacher_id', [self::TARGET_TEACHER_ID, self::UNRELATED_TEACHER_ID, self::LOW_LIMIT_TEACHER_ID, self::FOREIGN_TEACHER_ID])
            ->get();
        foreach ($teacherRows as $membership) {
            $expected = $teacherManifest[$membership->id] ?? null;
            if ($expected === null || ! $this->membershipMatches($membership, $expected, 'teacher_id')) {
                throw new RuntimeException('Stage 5 E2E Teacher membership manifest collision detected.');
            }
        }

        $studentManifest = $this->studentMembershipManifest();
        $studentRows = GroupStudentMembership::query()
            ->whereIn('id', array_keys($studentManifest))
            ->orWhereIn('group_id', array_keys($this->groupManifest()))
            ->orWhereIn('student_id', [self::TARGET_STUDENT_ID, self::ENDED_STUDENT_ID, self::UNRELATED_STUDENT_ID, self::FOREIGN_STUDENT_ID])
            ->get();
        foreach ($studentRows as $membership) {
            $expected = $studentManifest[$membership->id] ?? null;
            if ($expected === null || ! $this->membershipMatches($membership, $expected, 'student_id')) {
                throw new RuntimeException('Stage 5 E2E Student membership manifest collision detected.');
            }
        }
    }

    /** @param array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool} $expected */
    private function membershipMatches(object $membership, array $expected, string $memberColumn): bool
    {
        return $membership->institution_id === $expected['institution_id']
            && $membership->group_id === $expected['group_id']
            && $membership->{$memberColumn} === $expected['member_id']
            && $membership->assigned_by_user_id === $expected['actor_id']
            && ($membership->ended_at !== null) === $expected['ended'];
    }

    private function assertTopicManifestSafe(): ?string
    {
        $manifest = $this->topicManifest();
        $rows = Topic::query()
            ->whereIn('id', array_keys($manifest))
            ->orWhere('title', 'like', 'E2E S05%')
            ->orWhereIn('teacher_id', [self::TARGET_TEACHER_ID, self::UNRELATED_TEACHER_ID, self::LOW_LIMIT_TEACHER_ID, self::FOREIGN_TEACHER_ID])
            ->get();
        $dynamicTopicId = null;

        foreach ($rows as $topic) {
            $expected = $manifest[$topic->id] ?? null;
            if ($expected !== null) {
                if (! $this->topicMatches($topic, $expected)) {
                    throw new RuntimeException('Stage 5 E2E Topic manifest collision detected.');
                }

                continue;
            }

            if (! $this->dynamicTopicMatches($topic) || $dynamicTopicId !== null) {
                throw new RuntimeException('Stage 5 E2E dynamic Topic ownership collision detected.');
            }
            $dynamicTopicId = $topic->id;
        }

        return $dynamicTopicId;
    }

    /** @param array{institution_id: string, group_id: string, teacher_id: string, title: string, subject: string, description: ?string, instructions: string, status: string, allowed_statuses: list<string>} $expected */
    private function topicMatches(Topic $topic, array $expected): bool
    {
        return $topic->institution_id === $expected['institution_id']
            && $topic->group_id === $expected['group_id']
            && $topic->teacher_id === $expected['teacher_id']
            && $topic->title === $expected['title']
            && $topic->subject === $expected['subject']
            && $topic->description === $expected['description']
            && $topic->student_instructions === $expected['instructions']
            && $topic->lesson_at === null
            && in_array($topic->status->value, $expected['allowed_statuses'], true);
    }

    private function dynamicTopicMatches(Topic $topic): bool
    {
        return $topic->institution_id === self::TARGET_INSTITUTION_ID
            && $topic->group_id === self::GROUP_A_ID
            && $topic->teacher_id === self::TARGET_TEACHER_ID
            && $topic->title === self::DYNAMIC_TOPIC_TITLE
            && $topic->subject === 'E2E S05 Subject'
            && $topic->description === 'E2E S05 integration topic'
            && $topic->student_instructions === 'E2E S05 Student instructions'
            && $topic->lesson_at === null
            && in_array($topic->status, [TopicStatus::Draft, TopicStatus::Active, TopicStatus::Closed, TopicStatus::Archived], true);
    }

    /**
     * @return array{dynamic_topic_id: ?string, material_ids: list<string>, file_ids: list<string>, file_keys: list<string>}
     */
    private function assertMaterialAndFileManifestSafe(?string $dynamicTopicId): array
    {
        $materialManifest = $this->materialManifest();
        $fileManifest = $this->fileManifest();
        $materialIds = [];
        $fileIds = [];
        $fileKeys = [];
        $materials = LearningMaterial::query()
            ->with('file')
            ->whereIn('institution_id', array_keys($this->institutionManifest()))
            ->orWhereIn('id', array_keys($materialManifest))
            ->orWhereIn('teacher_id', [self::TARGET_TEACHER_ID, self::UNRELATED_TEACHER_ID, self::FOREIGN_TEACHER_ID])
            ->get();

        foreach ($materials as $material) {
            $file = $material->file;
            if (! $file instanceof File) {
                throw new RuntimeException('Stage 5 E2E material/file ownership graph is incomplete.');
            }
            $expected = $materialManifest[$material->id] ?? null;
            if ($expected !== null) {
                $expectedFile = $fileManifest[$expected['file_id']] ?? null;
                if ($expectedFile === null || ! $this->fixedMaterialMatches($material, $file, $expected, $expectedFile)) {
                    throw new RuntimeException('Stage 5 E2E fixed material/file manifest collision detected.');
                }
            } elseif ($dynamicTopicId !== null && $material->topic_id === $dynamicTopicId) {
                if (! $this->dynamicMaterialMatches($material, $file, $dynamicTopicId)) {
                    throw new RuntimeException('Stage 5 E2E dynamic material/file ownership collision detected.');
                }
            } elseif ($material->topic_id === self::SEEDED_TARGET_TOPIC_ID && $file->original_name === self::MANUAL_ORIGINAL_NAME) {
                if (! $this->manualMaterialMatches($material, $file)) {
                    throw new RuntimeException('Stage 5 E2E manual-smoke material/file ownership collision detected.');
                }
            } else {
                throw new RuntimeException('Stage 5 E2E unmanifested material/file collision detected.');
            }

            $materialIds[] = $material->id;
            $fileIds[] = $file->id;
            $fileKeys[] = $file->storage_key;
        }

        $candidateFiles = File::query()
            ->whereIn('institution_id', array_keys($this->institutionManifest()))
            ->orWhereIn('id', array_keys($fileManifest))
            ->orWhereIn('original_name', [...array_column($fileManifest, 'original_name'), ...self::AUTOMATED_ORIGINAL_NAMES, self::MANUAL_ORIGINAL_NAME])
            ->get();
        foreach ($candidateFiles as $file) {
            if (! in_array($file->id, $fileIds, true)) {
                throw new RuntimeException('Stage 5 E2E unattached File manifest collision detected.');
            }
        }

        return [
            'dynamic_topic_id' => $dynamicTopicId,
            'material_ids' => array_values(array_unique($materialIds)),
            'file_ids' => array_values(array_unique($fileIds)),
            'file_keys' => array_values(array_unique($fileKeys)),
        ];
    }

    /**
     * @param  array{topic_id: string, file_id: string, teacher_id: string, position: int}  $materialExpected
     * @param  array{institution_id: string, uploader_id: string, fixture_key: string, original_name: string, storage_key: string}  $fileExpected
     */
    private function fixedMaterialMatches(LearningMaterial $material, File $file, array $materialExpected, array $fileExpected): bool
    {
        $bytes = $this->seededPdfBytes($fileExpected['fixture_key']);

        return $material->institution_id === $fileExpected['institution_id']
            && $material->topic_id === $materialExpected['topic_id']
            && $material->file_id === $materialExpected['file_id']
            && $material->teacher_id === $materialExpected['teacher_id']
            && $material->position === $materialExpected['position']
            && $material->removed_at === null
            && $file->institution_id === $fileExpected['institution_id']
            && $file->uploaded_by_user_id === $fileExpected['uploader_id']
            && $file->category === FileCategory::LearningMaterial
            && $file->original_name === $fileExpected['original_name']
            && $file->storage_disk === 'local'
            && $file->storage_key === $fileExpected['storage_key']
            && $file->mime_type === 'application/pdf'
            && $file->extension === FileExtension::Pdf
            && $file->size_bytes === strlen($bytes)
            && $file->checksum_sha256 === hash('sha256', $bytes)
            && $file->removed_at === null;
    }

    private function dynamicMaterialMatches(LearningMaterial $material, File $file, string $dynamicTopicId): bool
    {
        return $material->institution_id === self::TARGET_INSTITUTION_ID
            && $material->topic_id === $dynamicTopicId
            && $material->teacher_id === self::TARGET_TEACHER_ID
            && $material->file_id === $file->id
            && $file->institution_id === self::TARGET_INSTITUTION_ID
            && $file->uploaded_by_user_id === self::TARGET_TEACHER_ID
            && $file->category === FileCategory::LearningMaterial
            && in_array($file->original_name, self::AUTOMATED_ORIGINAL_NAMES, true)
            && $file->storage_disk === 'local'
            && str_starts_with($file->storage_key, $this->topicNamespace(self::TARGET_INSTITUTION_ID, $dynamicTopicId).'/')
            && $this->hasCanonicalBlobBasename($file->storage_key)
            && (($material->removed_at === null && $file->removed_at === null) || ($material->removed_at !== null && $file->removed_at !== null));
    }

    private function manualMaterialMatches(LearningMaterial $material, File $file): bool
    {
        return $material->institution_id === self::TARGET_INSTITUTION_ID
            && $material->topic_id === self::SEEDED_TARGET_TOPIC_ID
            && $material->teacher_id === self::TARGET_TEACHER_ID
            && $material->file_id === $file->id
            && $file->institution_id === self::TARGET_INSTITUTION_ID
            && $file->uploaded_by_user_id === self::TARGET_TEACHER_ID
            && $file->category === FileCategory::LearningMaterial
            && $file->original_name === self::MANUAL_ORIGINAL_NAME
            && $file->storage_disk === 'local'
            && str_starts_with($file->storage_key, $this->topicNamespace(self::TARGET_INSTITUTION_ID, self::SEEDED_TARGET_TOPIC_ID).'/')
            && $this->hasCanonicalBlobBasename($file->storage_key)
            && (($material->removed_at === null && $file->removed_at === null) || ($material->removed_at !== null && $file->removed_at !== null));
    }

    /**
     * @param  array{dynamic_topic_id: ?string, material_ids: list<string>, file_ids: list<string>, file_keys: list<string>}  $ownership
     * @return list<string>
     */
    private function assertPrivateBlobOwnershipSafe(array $ownership): array
    {
        $allowedNamespaces = [];
        $fixedKeysByNamespace = [];
        foreach ($this->fileManifest() as $specification) {
            $namespace = dirname($specification['storage_key']);
            $allowedNamespaces[$namespace] = false;
            $fixedKeysByNamespace[$namespace][] = $specification['storage_key'];
        }
        $dynamicTopicId = $ownership['dynamic_topic_id'];
        if ($dynamicTopicId !== null) {
            $allowedNamespaces[$this->topicNamespace(self::TARGET_INSTITUTION_ID, $dynamicTopicId)] = true;
        }

        foreach ($ownership['file_keys'] as $key) {
            $namespace = dirname($key);
            if (! array_key_exists($namespace, $allowedNamespaces)) {
                throw new RuntimeException('Stage 5 E2E File points outside an owned Topic namespace.');
            }
            $fixedKeysByNamespace[$namespace][] = $key;
        }

        $ownedKeys = array_values(array_unique([
            ...$ownership['file_keys'],
            ...array_column($this->fileManifest(), 'storage_key'),
        ]));
        $root = realpath($this->expectedPrivateRoot());
        if (! is_string($root)) {
            throw new RuntimeException('Stage 5 E2E private root is unavailable.');
        }

        foreach (array_keys($this->institutionManifest()) as $institutionId) {
            $institutionRoot = $root.DIRECTORY_SEPARATOR.'learning-materials'.DIRECTORY_SEPARATOR.$institutionId;
            if (! file_exists($institutionRoot)) {
                continue;
            }
            if (is_link($institutionRoot) || ! is_dir($institutionRoot)) {
                throw new RuntimeException('Stage 5 E2E Institution blob namespace shape is unsafe.');
            }
            foreach (new \FilesystemIterator($institutionRoot, \FilesystemIterator::SKIP_DOTS) as $topicEntry) {
                if ($topicEntry->isLink() || ! $topicEntry->isDir()) {
                    throw new RuntimeException('Stage 5 E2E Topic blob namespace shape is unsafe.');
                }
                $namespace = "learning-materials/{$institutionId}/{$topicEntry->getFilename()}";
                if (! array_key_exists($namespace, $allowedNamespaces)) {
                    throw new RuntimeException('Stage 5 E2E unexpected Topic blob namespace collision detected.');
                }
                foreach (new \FilesystemIterator($topicEntry->getPathname(), \FilesystemIterator::SKIP_DOTS) as $fileEntry) {
                    if ($fileEntry->isLink() || ! $fileEntry->isFile()) {
                        throw new RuntimeException('Stage 5 E2E nested or symlink-like blob collision detected.');
                    }
                    $key = $namespace.'/'.$fileEntry->getFilename();
                    if (! $this->hasCanonicalBlobBasename($key)) {
                        throw new RuntimeException('Stage 5 E2E unexpected blob filename collision detected.');
                    }
                    if ($allowedNamespaces[$namespace] !== true && ! in_array($key, $fixedKeysByNamespace[$namespace] ?? [], true)) {
                        throw new RuntimeException('Stage 5 E2E unexpected fixed-Topic blob collision detected.');
                    }
                    $ownedKeys[] = $key;
                }
            }
        }

        return array_values(array_unique($ownedKeys));
    }

    private function hasCanonicalBlobBasename(string $key): bool
    {
        return preg_match('/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|docx|ppt|pptx)\z/D', basename($key)) === 1;
    }

    /** @param list<string> $keys */
    private function deleteOwnedBlobs(array $keys): void
    {
        $disk = $this->privateDisk();
        foreach (array_values(array_unique($keys)) as $key) {
            if ($disk->exists($key) && ! $disk->delete($key)) {
                throw new RuntimeException('Stage 5 E2E owned private blob deletion failed.');
            }
            if ($disk->exists($key)) {
                throw new RuntimeException('Stage 5 E2E owned private blob remained after deletion.');
            }
        }
    }

    private function deleteOwnedDynamicNamespace(?string $dynamicTopicId): void
    {
        if ($dynamicTopicId === null) {
            return;
        }
        $namespace = $this->topicNamespace(self::TARGET_INSTITUTION_ID, $dynamicTopicId);
        $disk = $this->privateDisk();
        if ($disk->directoryExists($namespace) && ! $disk->deleteDirectory($namespace)) {
            throw new RuntimeException('Stage 5 E2E dynamic Topic namespace cleanup failed.');
        }
        if ($disk->directoryExists($namespace)) {
            throw new RuntimeException('Stage 5 E2E dynamic Topic namespace remained after cleanup.');
        }
    }

    /** @param array{dynamic_topic_id: ?string, material_ids: list<string>, file_ids: list<string>, file_keys: list<string>} $ownership */
    private function resetOwnedDatabaseRows(array $ownership): void
    {
        LearningMaterial::query()->whereIn('id', $ownership['material_ids'])->delete();
        File::query()->whereIn('id', $ownership['file_ids'])->delete();

        $topicIds = array_keys($this->topicManifest());
        if ($ownership['dynamic_topic_id'] !== null) {
            $topicIds[] = $ownership['dynamic_topic_id'];
        }
        Topic::query()->whereIn('id', $topicIds)->delete();
        GroupTeacherMembership::query()->whereIn('id', array_keys($this->teacherMembershipManifest()))->delete();
        GroupStudentMembership::query()->whereIn('id', array_keys($this->studentMembershipManifest()))->delete();
        Group::query()->whereIn('id', array_keys($this->groupManifest()))->delete();
        DB::table('personal_access_tokens')
            ->where('tokenable_type', User::class)
            ->whereIn('tokenable_id', array_keys($this->userManifest()))
            ->delete();
        InstitutionSetting::query()->whereIn('institution_id', array_keys($this->institutionManifest()))->delete();
        User::query()->whereIn('id', array_keys($this->userManifest()))->delete();
        Institution::query()->whereIn('id', array_keys($this->institutionManifest()))->delete();
    }

    private function createFixedManifest(string $password): void
    {
        Model::unguarded(function () use ($password): void {
            $this->createInstitutions();
            $this->createUsers($password);
            $this->createSettings();
            $this->createGroups();
            $this->createMemberships();
            $this->createTopics();
            $this->createFilesAndMaterials();
        });
    }

    private function createInstitutions(): void
    {
        $createdAt = Carbon::parse('2020-05-01 08:00:00+00');
        foreach ($this->institutionManifest() as $id => $specification) {
            Institution::query()->create([
                'id' => $id,
                'name' => $specification['name'],
                'type' => $specification['type'],
                'status' => InstitutionStatus::Active,
                'contact_email' => $specification['key'].'@e2e-s05.invalid',
                'contact_phone' => '+998905'.substr(str_replace('-', '', $id), -6),
                'address' => 'E2E S05 deterministic '.$specification['key'].' address',
                'description' => 'E2E S05 deterministic '.$specification['key'].' Institution.',
                'created_by_user_id' => null,
                'deactivated_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createUsers(string $password): void
    {
        $createdAt = Carbon::parse('2020-05-02 08:00:00+00');
        foreach ($this->userManifest() as $id => $specification) {
            User::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'role' => $specification['role'],
                'full_name' => $specification['full_name'],
                'login_name' => $specification['login_name'],
                'email' => $specification['login_name'].'@e2e-s05.invalid',
                'phone' => '+998905'.substr(str_replace('-', '', $id), -6),
                'password' => Hash::make($password),
                'is_active' => true,
                'must_change_password' => false,
                'last_login_at' => null,
                'deactivated_at' => null,
                'created_by_user_id' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createSettings(): void
    {
        $createdAt = Carbon::parse('2020-05-02 10:00:00+00');
        foreach (array_keys($this->institutionManifest()) as $institutionId) {
            InstitutionSetting::query()->create([
                'institution_id' => $institutionId,
                'acceptable_score_difference' => null,
                'blitz_timer_start_mode' => null,
                'student_result_release_mode' => null,
                'parent_result_release_mode' => null,
                'timezone' => 'Asia/Tashkent',
                'learning_material_max_mb' => $institutionId === self::LOW_LIMIT_INSTITUTION_ID ? 1 : 25,
                'student_submission_max_mb' => 15,
                'updated_by_user_id' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createGroups(): void
    {
        $createdAt = Carbon::parse('2020-05-03 08:00:00+00');
        foreach ($this->groupManifest() as $id => $specification) {
            $archived = $specification['status'] === GroupStatus::Archived->value;
            $archivedAt = $archived ? Carbon::parse('2020-05-04 12:00:00+00') : null;
            Group::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'name' => $specification['name'],
                'level' => 'Stage 5',
                'subject_direction' => 'Integrated learning',
                'description' => 'E2E S05 deterministic Group.',
                'status' => $specification['status'],
                'created_by_user_id' => $specification['created_by_user_id'],
                'archived_at' => $archivedAt,
                'created_at' => $createdAt,
                'updated_at' => $archivedAt ?? $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function createMemberships(): void
    {
        $startedAt = Carbon::parse('2020-05-03 10:00:00+00');
        foreach ($this->teacherMembershipManifest() as $id => $specification) {
            $this->createMembership(GroupTeacherMembership::class, 'teacher_id', $id, $specification, $startedAt);
            $startedAt = $startedAt->copy()->addMinute();
        }
        foreach ($this->studentMembershipManifest() as $id => $specification) {
            $this->createMembership(GroupStudentMembership::class, 'student_id', $id, $specification, $startedAt);
            $startedAt = $startedAt->copy()->addMinute();
        }
    }

    /**
     * @param  class-string<GroupTeacherMembership|GroupStudentMembership>  $model
     * @param  array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool}  $specification
     */
    private function createMembership(string $model, string $memberColumn, string $id, array $specification, Carbon $startedAt): void
    {
        $endedAt = $specification['ended'] ? $startedAt->copy()->addHour() : null;
        $model::query()->create([
            'id' => $id,
            'institution_id' => $specification['institution_id'],
            'group_id' => $specification['group_id'],
            $memberColumn => $specification['member_id'],
            'assigned_by_user_id' => $specification['actor_id'],
            'started_at' => $startedAt,
            'ended_at' => $endedAt,
            'created_at' => $startedAt,
            'updated_at' => $endedAt ?? $startedAt,
        ]);
    }

    private function createTopics(): void
    {
        $createdAt = Carbon::parse('2020-05-04 08:00:00+00');
        foreach ($this->topicManifest() as $id => $specification) {
            $active = $specification['status'] === TopicStatus::Active->value;
            $activatedAt = $active ? $createdAt->copy()->addMinute() : null;
            Topic::query()->create([
                'id' => $id,
                'institution_id' => $specification['institution_id'],
                'group_id' => $specification['group_id'],
                'teacher_id' => $specification['teacher_id'],
                'title' => $specification['title'],
                'description' => $specification['description'],
                'subject' => $specification['subject'],
                'student_instructions' => $specification['instructions'],
                'lesson_at' => null,
                'status' => $specification['status'],
                'activated_at' => $activatedAt,
                'closed_at' => null,
                'archived_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $activatedAt ?? $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinutes(5);
        }
    }

    private function createFilesAndMaterials(): void
    {
        $createdAt = Carbon::parse('2020-05-04 09:00:00+00');
        foreach ($this->materialManifest() as $materialId => $materialSpecification) {
            $fileSpecification = $this->fileManifest()[$materialSpecification['file_id']];
            $bytes = $this->seededPdfBytes($fileSpecification['fixture_key']);
            File::query()->create([
                'id' => $materialSpecification['file_id'],
                'institution_id' => $fileSpecification['institution_id'],
                'uploaded_by_user_id' => $fileSpecification['uploader_id'],
                'category' => FileCategory::LearningMaterial,
                'original_name' => $fileSpecification['original_name'],
                'storage_disk' => 'local',
                'storage_key' => $fileSpecification['storage_key'],
                'mime_type' => 'application/pdf',
                'extension' => FileExtension::Pdf,
                'size_bytes' => strlen($bytes),
                'checksum_sha256' => hash('sha256', $bytes),
                'removed_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            LearningMaterial::query()->create([
                'id' => $materialId,
                'institution_id' => $fileSpecification['institution_id'],
                'topic_id' => $materialSpecification['topic_id'],
                'file_id' => $materialSpecification['file_id'],
                'teacher_id' => $materialSpecification['teacher_id'],
                'title' => null,
                'position' => $materialSpecification['position'],
                'removed_at' => null,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            $createdAt = $createdAt->copy()->addMinute();
        }
    }

    private function assertSeededBlobChecksums(): void
    {
        foreach ($this->fileManifest() as $fileId => $specification) {
            $file = File::query()->find($fileId);
            if (! $file instanceof File || ! $this->privateDisk()->exists($specification['storage_key'])) {
                throw new RuntimeException('Stage 5 E2E seeded blob verification failed.');
            }
            $bytes = $this->privateDisk()->get($specification['storage_key']);
            if (! is_string($bytes) || hash('sha256', $bytes) !== $file->checksum_sha256) {
                throw new RuntimeException('Stage 5 E2E seeded blob checksum verification failed.');
            }
        }
    }

    private function privateDisk(): FilesystemAdapter
    {
        return Storage::disk('local');
    }

    private function seededPdfBytes(string $fixtureKey): string
    {
        return "%PDF-1.7\n% TestLabUz Stage 5 deterministic {$fixtureKey}\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n";
    }

    private function topicNamespace(string $institutionId, string $topicId): string
    {
        return "learning-materials/{$institutionId}/{$topicId}";
    }

    /** @return array<string, array{key: string, name: string, type: string}> */
    private function institutionManifest(): array
    {
        return [
            self::TARGET_INSTITUTION_ID => ['key' => 'target', 'name' => 'E2E S05 Target Institution', 'type' => InstitutionType::School->value],
            self::LOW_LIMIT_INSTITUTION_ID => ['key' => 'low_limit', 'name' => 'E2E S05 Low Limit Institution', 'type' => InstitutionType::LearningCenter->value],
            self::FOREIGN_INSTITUTION_ID => ['key' => 'foreign', 'name' => 'E2E S05 Foreign Institution', 'type' => InstitutionType::University->value],
        ];
    }

    /** @return array<string, array{login_name: string, full_name: string, role: string, institution_id: string}> */
    private function userManifest(): array
    {
        return [
            self::TARGET_ADMIN_ID => $this->userSpec('e2e_s05_target_admin', 'E2E S05 Target Admin', UserRole::InstitutionAdmin, self::TARGET_INSTITUTION_ID),
            self::TARGET_TEACHER_ID => $this->userSpec('e2e_s05_target_teacher', 'E2E S05 Target Teacher', UserRole::Teacher, self::TARGET_INSTITUTION_ID),
            self::TARGET_STUDENT_ID => $this->userSpec('e2e_s05_target_student', 'E2E S05 Target Student', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::ENDED_STUDENT_ID => $this->userSpec('e2e_s05_ended_student', 'E2E S05 Ended Student', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::UNRELATED_TEACHER_ID => $this->userSpec('e2e_s05_unrelated_teacher', 'E2E S05 Unrelated Teacher', UserRole::Teacher, self::TARGET_INSTITUTION_ID),
            self::UNRELATED_STUDENT_ID => $this->userSpec('e2e_s05_unrelated_student', 'E2E S05 Unrelated Student', UserRole::Student, self::TARGET_INSTITUTION_ID),
            self::LOW_LIMIT_ADMIN_ID => $this->userSpec('e2e_s05_low_limit_admin', 'E2E S05 Low Limit Admin', UserRole::InstitutionAdmin, self::LOW_LIMIT_INSTITUTION_ID),
            self::LOW_LIMIT_TEACHER_ID => $this->userSpec('e2e_s05_low_limit_teacher', 'E2E S05 Low Limit Teacher', UserRole::Teacher, self::LOW_LIMIT_INSTITUTION_ID),
            self::FOREIGN_ADMIN_ID => $this->userSpec('e2e_s05_foreign_admin', 'E2E S05 Foreign Admin', UserRole::InstitutionAdmin, self::FOREIGN_INSTITUTION_ID),
            self::FOREIGN_TEACHER_ID => $this->userSpec('e2e_s05_foreign_teacher', 'E2E S05 Foreign Teacher', UserRole::Teacher, self::FOREIGN_INSTITUTION_ID),
            self::FOREIGN_STUDENT_ID => $this->userSpec('e2e_s05_foreign_student', 'E2E S05 Foreign Student', UserRole::Student, self::FOREIGN_INSTITUTION_ID),
        ];
    }

    /** @return array{login_name: string, full_name: string, role: string, institution_id: string} */
    private function userSpec(string $login, string $name, UserRole $role, string $institutionId): array
    {
        return ['login_name' => $login, 'full_name' => $name, 'role' => $role->value, 'institution_id' => $institutionId];
    }

    /** @return array<string, array{name: string, institution_id: string, created_by_user_id: string, status: string}> */
    private function groupManifest(): array
    {
        return [
            self::GROUP_A_ID => ['name' => 'E2E S05 Group A', 'institution_id' => self::TARGET_INSTITUTION_ID, 'created_by_user_id' => self::TARGET_ADMIN_ID, 'status' => GroupStatus::Active->value],
            self::GROUP_B_ID => ['name' => 'E2E S05 Group B', 'institution_id' => self::TARGET_INSTITUTION_ID, 'created_by_user_id' => self::TARGET_ADMIN_ID, 'status' => GroupStatus::Active->value],
            self::GROUP_C_ID => ['name' => 'E2E S05 Archived Group C', 'institution_id' => self::TARGET_INSTITUTION_ID, 'created_by_user_id' => self::TARGET_ADMIN_ID, 'status' => GroupStatus::Archived->value],
            self::LOW_LIMIT_GROUP_ID => ['name' => 'E2E S05 Low Limit Group', 'institution_id' => self::LOW_LIMIT_INSTITUTION_ID, 'created_by_user_id' => self::LOW_LIMIT_ADMIN_ID, 'status' => GroupStatus::Active->value],
            self::FOREIGN_GROUP_ID => ['name' => 'E2E S05 Foreign Group', 'institution_id' => self::FOREIGN_INSTITUTION_ID, 'created_by_user_id' => self::FOREIGN_ADMIN_ID, 'status' => GroupStatus::Active->value],
        ];
    }

    /** @return array<string, array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool}> */
    private function teacherMembershipManifest(): array
    {
        return [
            '05000000-0000-4000-b100-000000000101' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_A_ID, self::TARGET_TEACHER_ID, self::TARGET_ADMIN_ID),
            '05000000-0000-4000-b100-000000000102' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_C_ID, self::TARGET_TEACHER_ID, self::TARGET_ADMIN_ID),
            '05000000-0000-4000-b100-000000000103' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_B_ID, self::UNRELATED_TEACHER_ID, self::TARGET_ADMIN_ID),
            '05000000-0000-4000-b100-000000000201' => $this->membershipSpec(self::LOW_LIMIT_INSTITUTION_ID, self::LOW_LIMIT_GROUP_ID, self::LOW_LIMIT_TEACHER_ID, self::LOW_LIMIT_ADMIN_ID),
            '05000000-0000-4000-b100-000000000301' => $this->membershipSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_GROUP_ID, self::FOREIGN_TEACHER_ID, self::FOREIGN_ADMIN_ID),
        ];
    }

    /** @return array<string, array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool}> */
    private function studentMembershipManifest(): array
    {
        return [
            '05000000-0000-4000-b200-000000000101' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_A_ID, self::TARGET_STUDENT_ID, self::TARGET_ADMIN_ID),
            '05000000-0000-4000-b200-000000000102' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_C_ID, self::TARGET_STUDENT_ID, self::TARGET_ADMIN_ID),
            '05000000-0000-4000-b200-000000000103' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_A_ID, self::ENDED_STUDENT_ID, self::TARGET_ADMIN_ID, true),
            '05000000-0000-4000-b200-000000000104' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_C_ID, self::ENDED_STUDENT_ID, self::TARGET_ADMIN_ID, true),
            '05000000-0000-4000-b200-000000000105' => $this->membershipSpec(self::TARGET_INSTITUTION_ID, self::GROUP_B_ID, self::UNRELATED_STUDENT_ID, self::TARGET_ADMIN_ID),
            '05000000-0000-4000-b200-000000000301' => $this->membershipSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_GROUP_ID, self::FOREIGN_STUDENT_ID, self::FOREIGN_ADMIN_ID),
        ];
    }

    /** @return array{institution_id: string, group_id: string, member_id: string, actor_id: string, ended: bool} */
    private function membershipSpec(string $institution, string $group, string $member, string $actor, bool $ended = false): array
    {
        return ['institution_id' => $institution, 'group_id' => $group, 'member_id' => $member, 'actor_id' => $actor, 'ended' => $ended];
    }

    /** @return array<string, array{institution_id: string, group_id: string, teacher_id: string, title: string, subject: string, description: ?string, instructions: string, status: string, allowed_statuses: list<string>}> */
    private function topicManifest(): array
    {
        return [
            self::SEEDED_TARGET_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::GROUP_A_ID, self::TARGET_TEACHER_ID, 'E2E S05 Seeded Active Topic', TopicStatus::Active),
            self::SEEDED_DRAFT_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::GROUP_A_ID, self::TARGET_TEACHER_ID, 'E2E S05 Seeded Draft Topic', TopicStatus::Draft, [TopicStatus::Draft, TopicStatus::Archived]),
            self::UNRELATED_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::GROUP_B_ID, self::UNRELATED_TEACHER_ID, 'E2E S05 Unrelated Topic', TopicStatus::Active),
            self::ARCHIVED_GROUP_TOPIC_ID => $this->topicSpec(self::TARGET_INSTITUTION_ID, self::GROUP_C_ID, self::TARGET_TEACHER_ID, 'E2E S05 Archived Group Topic', TopicStatus::Active, [TopicStatus::Active, TopicStatus::Closed, TopicStatus::Archived]),
            self::LOW_LIMIT_TOPIC_ID => $this->topicSpec(self::LOW_LIMIT_INSTITUTION_ID, self::LOW_LIMIT_GROUP_ID, self::LOW_LIMIT_TEACHER_ID, 'E2E S05 Low Limit Topic', TopicStatus::Draft),
            self::FOREIGN_TOPIC_ID => $this->topicSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_GROUP_ID, self::FOREIGN_TEACHER_ID, 'E2E S05 Foreign Topic', TopicStatus::Active),
        ];
    }

    /**
     * @param  list<TopicStatus>|null  $allowedStatuses
     * @return array{institution_id: string, group_id: string, teacher_id: string, title: string, subject: string, description: ?string, instructions: string, status: string, allowed_statuses: list<string>}
     */
    private function topicSpec(string $institution, string $group, string $teacher, string $title, TopicStatus $status, ?array $allowedStatuses = null): array
    {
        return [
            'institution_id' => $institution,
            'group_id' => $group,
            'teacher_id' => $teacher,
            'title' => $title,
            'subject' => 'E2E S05 Seeded Subject',
            'description' => 'E2E S05 deterministic seeded Topic.',
            'instructions' => 'E2E S05 deterministic Student instructions.',
            'status' => $status->value,
            'allowed_statuses' => array_map(static fn (TopicStatus $allowed): string => $allowed->value, $allowedStatuses ?? [$status]),
        ];
    }

    /** @return array<string, array{topic_id: string, file_id: string, teacher_id: string, position: int}> */
    private function materialManifest(): array
    {
        return [
            '05000000-0000-4000-d000-000000000101' => ['topic_id' => self::SEEDED_TARGET_TOPIC_ID, 'file_id' => '05000000-0000-4000-e000-000000000101', 'teacher_id' => self::TARGET_TEACHER_ID, 'position' => 0],
            '05000000-0000-4000-d000-000000000102' => ['topic_id' => self::UNRELATED_TOPIC_ID, 'file_id' => '05000000-0000-4000-e000-000000000102', 'teacher_id' => self::UNRELATED_TEACHER_ID, 'position' => 0],
            '05000000-0000-4000-d000-000000000103' => ['topic_id' => self::ARCHIVED_GROUP_TOPIC_ID, 'file_id' => '05000000-0000-4000-e000-000000000103', 'teacher_id' => self::TARGET_TEACHER_ID, 'position' => 0],
            '05000000-0000-4000-d000-000000000104' => ['topic_id' => self::FOREIGN_TOPIC_ID, 'file_id' => '05000000-0000-4000-e000-000000000104', 'teacher_id' => self::FOREIGN_TEACHER_ID, 'position' => 0],
        ];
    }

    /** @return array<string, array{institution_id: string, uploader_id: string, fixture_key: string, original_name: string, storage_key: string}> */
    private function fileManifest(): array
    {
        return [
            '05000000-0000-4000-e000-000000000101' => $this->fileSpec(self::TARGET_INSTITUTION_ID, self::TARGET_TEACHER_ID, self::SEEDED_TARGET_TOPIC_ID, 'target', 'e2e_s05_seeded_target.pdf', '05000000-0000-4000-f000-000000000101'),
            '05000000-0000-4000-e000-000000000102' => $this->fileSpec(self::TARGET_INSTITUTION_ID, self::UNRELATED_TEACHER_ID, self::UNRELATED_TOPIC_ID, 'unrelated', 'e2e_s05_seeded_unrelated.pdf', '05000000-0000-4000-f000-000000000102'),
            '05000000-0000-4000-e000-000000000103' => $this->fileSpec(self::TARGET_INSTITUTION_ID, self::TARGET_TEACHER_ID, self::ARCHIVED_GROUP_TOPIC_ID, 'archived', 'e2e_s05_seeded_archived.pdf', '05000000-0000-4000-f000-000000000103'),
            '05000000-0000-4000-e000-000000000104' => $this->fileSpec(self::FOREIGN_INSTITUTION_ID, self::FOREIGN_TEACHER_ID, self::FOREIGN_TOPIC_ID, 'foreign', 'e2e_s05_seeded_foreign.pdf', '05000000-0000-4000-f000-000000000104'),
        ];
    }

    /** @return array{institution_id: string, uploader_id: string, fixture_key: string, original_name: string, storage_key: string} */
    private function fileSpec(string $institution, string $uploader, string $topic, string $key, string $name, string $blobId): array
    {
        return [
            'institution_id' => $institution,
            'uploader_id' => $uploader,
            'fixture_key' => $key,
            'original_name' => $name,
            'storage_key' => $this->topicNamespace($institution, $topic).'/'.$blobId.'.pdf',
        ];
    }
}
