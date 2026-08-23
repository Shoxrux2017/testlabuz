<?php

namespace Tests\Feature\Files;

use App\Actions\Files\DownloadLearningMaterialFile;
use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use App\Support\Files\ProtectedFileDownload;
use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use League\Flysystem\FilesystemOperator;
use RuntimeException;
use Tests\TestCase;

class ProtectedLearningMaterialDownloadApiTest extends TestCase
{
    use RefreshDatabase;

    private const FILE_ID = '00000000-0000-0000-0000-000000000001';

    public function test_download_route_is_exact_and_auth_role_account_institution_password_and_input_gates_precede_disclosure(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/files/{file}/download')
            ->values()
            ->all();

        $this->assertSame([[
            'methods' => ['GET'],
            'uri' => 'api/v1/files/{file}/download',
            'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher,student'],
        ]], $routes);

        $institution = Institution::factory()->create();
        $uri = $this->uri(self::FILE_ID);
        $this->getJson($uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $this->requestAs($this->teacher($institution, ['is_active' => false]), $uri)
            ->assertForbidden()->assertJsonPath('code', 'user_inactive');
        $this->requestAs($this->teacher($institution, ['must_change_password' => true]), $uri)
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $this->requestAs($this->student($inactiveInstitution), $uri)
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::InstitutionAdmin, UserRole::Parent] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
            $this->requestAs($actor, $uri)->assertForbidden()->assertJsonPath('code', 'forbidden');
        }

        $teacher = $this->teacher($institution);
        $this->requestAs($teacher, $this->uri('not-a-uuid'))
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->requestAs($teacher, $uri, ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($teacher, $uri, content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_teacher_download_requires_own_topic_and_current_membership_but_all_topic_and_group_statuses_are_readable(): void
    {
        Storage::fake('local');
        [$institution, $admin, $teacher, , $group] = $this->context();
        $otherTeacher = $this->teacher($institution);
        $this->teacherMembership($institution, $group, $otherTeacher, $admin);
        $visibleFiles = [];

        foreach (TopicStatus::cases() as $index => $status) {
            $topic = $this->topic($institution, $group, $teacher, $status);
            $material = $this->material($institution, $topic, $teacher, fileAttributes: [
                'storage_key' => 'learning-materials/teacher-status-'.$index.'.pdf',
            ]);
            $file = $material->file()->firstOrFail();
            Storage::disk('local')->put($file->storage_key, 'teacher-'.$status->value);
            $visibleFiles[] = [$file, 'teacher-'.$status->value];
        }

        $archivedGroup = $this->group($institution, $admin, archived: true);
        $this->teacherMembership($institution, $archivedGroup, $teacher, $admin);
        $archivedMaterial = $this->material(
            $institution,
            $this->topic($institution, $archivedGroup, $teacher, TopicStatus::Archived),
            $teacher,
            fileAttributes: ['storage_key' => 'learning-materials/teacher-archived-group.pdf'],
        );
        $archivedFile = $archivedMaterial->file()->firstOrFail();
        Storage::disk('local')->put($archivedFile->storage_key, 'teacher-archived-group');
        $visibleFiles[] = [$archivedFile, 'teacher-archived-group'];

        foreach ($visibleFiles as [$file, $bytes]) {
            $this->requestAs($teacher, $this->uri($file->id))
                ->assertOk()->assertStreamedContent($bytes);
        }

        $otherMaterial = $this->material(
            $institution,
            $this->topic($institution, $group, $otherTeacher, TopicStatus::Active),
            $otherTeacher,
        );
        $endedGroup = $this->group($institution, $admin);
        $this->teacherMembership($institution, $endedGroup, $teacher, $admin, ended: true);
        $endedMaterial = $this->material(
            $institution,
            $this->topic($institution, $endedGroup, $teacher, TopicStatus::Active),
            $teacher,
        );
        $foreignInstitution = Institution::factory()->create();
        $foreignAdmin = $this->admin($foreignInstitution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin);
        $this->teacherMembership($foreignInstitution, $foreignGroup, $foreignTeacher, $foreignAdmin);
        $foreignMaterial = $this->material(
            $foreignInstitution,
            $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher, TopicStatus::Active),
            $foreignTeacher,
        );

        foreach ([$otherMaterial, $endedMaterial, $foreignMaterial] as $hiddenMaterial) {
            $this->requestAs($teacher, $this->uri($hiddenMaterial->file_id))
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_student_download_requires_current_membership_and_non_draft_topic_without_teacher_membership_dependency(): void
    {
        Storage::fake('local');
        [$institution, $admin, $teacher, $student, $group] = $this->context();
        $visibleFiles = [];

        foreach ([TopicStatus::Active, TopicStatus::Closed, TopicStatus::Archived] as $index => $status) {
            $topic = $this->topic($institution, $group, $teacher, $status);
            $material = $this->material($institution, $topic, $teacher, fileAttributes: [
                'storage_key' => 'learning-materials/student-status-'.$index.'.pdf',
            ]);
            $file = $material->file()->firstOrFail();
            Storage::disk('local')->put($file->storage_key, 'student-'.$status->value);
            $visibleFiles[] = [$file, 'student-'.$status->value];
        }

        $archivedGroup = $this->group($institution, $admin, archived: true);
        $this->studentMembership($institution, $archivedGroup, $student, $admin);
        $archivedMaterial = $this->material(
            $institution,
            $this->topic($institution, $archivedGroup, $teacher, TopicStatus::Closed),
            $teacher,
            fileAttributes: ['storage_key' => 'learning-materials/student-archived-group.pdf'],
        );
        $archivedFile = $archivedMaterial->file()->firstOrFail();
        Storage::disk('local')->put($archivedFile->storage_key, 'student-archived-group');
        $visibleFiles[] = [$archivedFile, 'student-archived-group'];

        GroupTeacherMembership::query()
            ->where('institution_id', $institution->id)
            ->where('group_id', $group->id)
            ->update(['ended_at' => now()]);

        foreach ($visibleFiles as [$file, $bytes]) {
            $this->requestAs($student, $this->uri($file->id))
                ->assertOk()->assertStreamedContent($bytes);
        }

        $draft = $this->material(
            $institution,
            $this->topic($institution, $group, $teacher, TopicStatus::Draft),
            $teacher,
        );
        $unrelatedGroup = $this->group($institution, $admin);
        $unrelated = $this->material(
            $institution,
            $this->topic($institution, $unrelatedGroup, $teacher, TopicStatus::Active),
            $teacher,
        );
        $endedGroup = $this->group($institution, $admin);
        $this->studentMembership($institution, $endedGroup, $student, $admin, ended: true);
        $ended = $this->material(
            $institution,
            $this->topic($institution, $endedGroup, $teacher, TopicStatus::Active),
            $teacher,
        );
        $foreignInstitution = Institution::factory()->create();
        $foreignAdmin = $this->admin($foreignInstitution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin);
        $foreign = $this->material(
            $foreignInstitution,
            $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher, TopicStatus::Active),
            $foreignTeacher,
        );

        foreach ([$draft, $unrelated, $ended, $foreign] as $hiddenMaterial) {
            $this->requestAs($student, $this->uri($hiddenMaterial->file_id))
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_removed_wrong_category_orphan_and_unauthorized_missing_blob_targets_are_privacy_safe_not_found(): void
    {
        Storage::fake('local');
        [$institution, , $teacher, $student, $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher, TopicStatus::Active);
        $removedMaterial = $this->material($institution, $topic, $teacher, ['removed_at' => now()]);
        $removedFileMaterial = $this->material($institution, $topic, $teacher, fileAttributes: ['removed_at' => now()]);
        $wrongCategory = $this->material($institution, $topic, $teacher, fileAttributes: [
            'category' => FileCategory::StudentSubmission,
        ]);
        $orphan = File::factory()->create([
            'institution_id' => $institution->id,
            'uploaded_by_user_id' => $teacher->id,
        ]);

        foreach ([$removedMaterial->file_id, $removedFileMaterial->file_id, $wrongCategory->file_id, $orphan->id] as $hiddenFile) {
            $this->requestAs($student, $this->uri($hiddenFile))
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $otherStudent = $this->student($institution);
        $authorizedButMissingBlob = $this->material($institution, $topic, $teacher);
        $response = $this->requestAs($otherStudent, $this->uri($authorizedButMissingBlob->file_id));
        $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertStringNotContainsString('file_not_available', $response->getContent());
    }

    public function test_download_streams_real_persisted_disk_bytes_with_mime_safe_disposition_and_private_headers(): void
    {
        [$institution, , $teacher, $student, $group] = $this->context();
        config([
            'filesystems.private_files_disk' => 'current-private',
            'filesystems.disks.current-private' => [
                'driver' => 'local', 'root' => storage_path('framework/testing/disks/current-private'), 'throw' => false,
            ],
            'filesystems.disks.persisted-private' => [
                'driver' => 'local', 'root' => storage_path('framework/testing/disks/persisted-private'), 'throw' => false,
            ],
        ]);
        Storage::fake('current-private');
        Storage::fake('persisted-private');
        $topic = $this->topic($institution, $group, $teacher, TopicStatus::Active);
        $material = $this->material($institution, $topic, $teacher, fileAttributes: [
            'original_name' => 'Урок по сети.pptx',
            'storage_disk' => 'persisted-private',
            'storage_key' => 'old-authoritative/location.pptx',
            'mime_type' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'extension' => FileExtension::Pptx,
        ]);
        $bytes = random_bytes(4096);
        Storage::disk('persisted-private')->put('old-authoritative/location.pptx', $bytes);
        Storage::disk('current-private')->put('old-authoritative/location.pptx', 'wrong-current-selector-bytes');

        $baseTransactionLevel = DB::transactionLevel();
        $response = $this->requestAs($student, $this->uri($material->file_id));
        $response->assertOk();
        $this->assertSame($baseTransactionLevel, DB::transactionLevel());
        $response->assertHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.presentationml.presentation');
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->assertStringContainsString('private', (string) $response->headers->get('Cache-Control'));
        $this->assertStringContainsString('no-store', (string) $response->headers->get('Cache-Control'));
        $disposition = (string) $response->headers->get('Content-Disposition');
        $this->assertStringStartsWith('attachment;', $disposition);
        $this->assertStringContainsString("filename*=utf-8''", $disposition);
        $response->assertStreamedContent($bytes);

        $serializedHeaders = json_encode($response->headers->allPreserveCaseWithoutCookies(), JSON_THROW_ON_ERROR);
        foreach (['persisted-private', 'current-private', 'old-authoritative/location.pptx', 'storage_disk', 'storage_key', 'provider', 'bucket'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $serializedHeaders);
        }
    }

    public function test_content_disposition_handles_controls_utf8_and_fallback_without_header_injection(): void
    {
        $institution = Institution::factory()->create();
        $student = $this->student($institution);
        $cases = [
            ["report\r\nX-Evil: injected.pdf", 'reportX-Evil: injected.pdf'],
            ["\r\n\0\x7F", 'download.pdf'],
        ];

        foreach ($cases as [$displayFilename, $expectedFilename]) {
            $stream = fopen('php://temp', 'w+b');
            $this->assertIsResource($stream);
            fwrite($stream, 'safe-bytes');
            rewind($stream);
            $action = $this->createMock(DownloadLearningMaterialFile::class);
            $action->method('__invoke')->willReturn(new ProtectedFileDownload(
                $stream,
                'application/pdf',
                $displayFilename,
                'pdf',
            ));
            $this->app->instance(DownloadLearningMaterialFile::class, $action);

            $response = $this->requestAs($student, $this->uri(self::FILE_ID));
            $response->assertOk()->assertStreamedContent('safe-bytes');
            $disposition = (string) $response->headers->get('Content-Disposition');
            $this->assertStringNotContainsString("\r", $disposition);
            $this->assertStringNotContainsString("\n", $disposition);
            $this->assertStringContainsString($expectedFilename, $disposition);
            $this->assertFalse($response->headers->has('X-Evil'));
        }
    }

    public function test_authorized_missing_malformed_public_disk_and_missing_blob_map_to_exact_file_not_available(): void
    {
        [$institution, , $teacher, $student, $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher, TopicStatus::Active);
        $material = $this->material($institution, $topic, $teacher);
        $file = $material->file()->firstOrFail();

        $cases = [
            ['missing-private', []],
            ['malformed-private', ['filesystems.disks.malformed-private' => 'not-an-array']],
            ['public-private', ['filesystems.disks.public-private' => ['driver' => 'local', 'root' => storage_path('app/public'), 'visibility' => 'public']]],
            ['empty-private', ['filesystems.disks.empty-private' => ['driver' => 'local', 'root' => storage_path('framework/testing/disks/empty-private'), 'throw' => false]]],
        ];

        foreach ($cases as [$diskName, $configuration]) {
            config($configuration);
            if ($diskName === 'empty-private') {
                Storage::fake($diskName);
            }
            $file->forceFill(['storage_disk' => $diskName, 'storage_key' => 'sensitive/private/location.pdf'])->save();

            $response = $this->requestAs($student, $this->uri($file->id));
            $response->assertStatus(500)->assertExactJson([
                'message' => 'The requested file is currently unavailable.',
                'code' => 'file_not_available',
                'errors' => [],
            ]);
            foreach ([$diskName, 'sensitive/private/location.pdf', 'root', 'provider'] as $hidden) {
                $this->assertStringNotContainsString($hidden, $response->getContent());
            }
        }
    }

    public function test_read_stream_exception_and_non_resource_map_to_exact_safe_file_not_available(): void
    {
        [$institution, , $teacher, $student, $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher, TopicStatus::Active);
        $material = $this->material($institution, $topic, $teacher, fileAttributes: [
            'storage_disk' => 'broken-private',
            'storage_key' => 'sensitive/provider/key.pdf',
        ]);
        config(['filesystems.disks.broken-private' => [
            'driver' => 'local', 'root' => storage_path('framework/testing/disks/broken-private'), 'throw' => false,
        ]]);
        $driver = $this->createMock(FilesystemOperator::class);
        $calls = 0;
        $driver->method('readStream')->willReturnCallback(function () use (&$calls): mixed {
            $calls++;
            if ($calls === 1) {
                throw new RuntimeException('sensitive provider failure');
            }

            return 'not-a-resource';
        });
        $disk = $this->createMock(FilesystemAdapter::class);
        $disk->method('getDriver')->willReturn($driver);
        Storage::shouldReceive('disk')->twice()->with('broken-private')->andReturn($disk);

        for ($attempt = 0; $attempt < 2; $attempt++) {
            $response = $this->requestAs($student, $this->uri($material->file_id));
            $response->assertStatus(500)->assertExactJson([
                'message' => 'The requested file is currently unavailable.',
                'code' => 'file_not_available',
                'errors' => [],
            ]);
            $this->assertStringNotContainsString('sensitive', $response->getContent());
            $this->assertStringNotContainsString('provider', $response->getContent());
        }
    }

    /** @return array{Institution, User, User, User, Group} */
    private function context(): array
    {
        $institution = Institution::factory()->create();
        $admin = $this->admin($institution);
        $teacher = $this->teacher($institution);
        $student = $this->student($institution);
        $group = $this->group($institution, $admin);
        $this->teacherMembership($institution, $group, $teacher, $admin);
        $this->studentMembership($institution, $group, $student, $admin);

        return [$institution, $admin, $teacher, $student, $group];
    }

    private function teacher(Institution $institution, array $attributes = []): User
    {
        return User::factory()->teacher($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    private function student(Institution $institution, array $attributes = []): User
    {
        return User::factory()->student($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    private function admin(Institution $institution): User
    {
        return User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    }

    private function group(Institution $institution, User $admin, bool $archived = false): Group
    {
        $factory = $archived ? Group::factory()->archived() : Group::factory();

        return $factory->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
    }

    private function teacherMembership(
        Institution $institution,
        Group $group,
        User $teacher,
        User $admin,
        bool $ended = false,
    ): void {
        ($ended ? GroupTeacherMembership::factory()->ended() : GroupTeacherMembership::factory())->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
    }

    private function studentMembership(
        Institution $institution,
        Group $group,
        User $student,
        User $admin,
        bool $ended = false,
    ): void {
        ($ended ? GroupStudentMembership::factory()->ended() : GroupStudentMembership::factory())->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $admin->id,
        ]);
    }

    private function topic(Institution $institution, Group $group, User $teacher, TopicStatus $status): Topic
    {
        $factory = match ($status) {
            TopicStatus::Active => Topic::factory()->active(),
            TopicStatus::Closed => Topic::factory()->closed(),
            TopicStatus::Archived => Topic::factory()->archivedFromClosed(),
            TopicStatus::Draft => Topic::factory(),
        };

        return $factory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
    }

    private function material(
        Institution $institution,
        Topic $topic,
        User $teacher,
        array $attributes = [],
        array $fileAttributes = [],
    ): LearningMaterial {
        $file = File::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'uploaded_by_user_id' => $teacher->id,
        ], $fileAttributes));

        return LearningMaterial::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'teacher_id' => $teacher->id,
            'file_id' => $file->id,
        ], $attributes));
    }

    /** @param array<string, mixed> $query */
    private function requestAs(User $actor, string $uri, array $query = [], string $content = ''): TestResponse
    {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('protected-download-api-test')->plainTextToken,
        ];
        $response = $this->call('GET', $requestUri, [], [], [], $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function uri(string $fileId): string
    {
        return '/api/v1/files/'.$fileId.'/download';
    }
}
