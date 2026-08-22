<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\ListTeacherLearningMaterials;
use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Enums\UserRole;
use App\Http\Resources\Teacher\TeacherLearningMaterialResource;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class TeacherLearningMaterialReadApiTest extends TestCase
{
    use RefreshDatabase;

    private const MATERIAL_KEYS = ['id', 'topic_id', 'title', 'file', 'created_at', 'updated_at'];

    public function test_exact_five_teacher_material_routes_are_registered_with_teacher_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => str_contains($route['uri'], '/materials'))
            ->values()
            ->all();
        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/teacher/topics/{topic}/materials', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/topics/{topic}/materials', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/materials/{material}/replace', 'middleware' => $middleware],
            ['methods' => ['PATCH'], 'uri' => 'api/v1/teacher/materials/{material}', 'middleware' => $middleware],
            ['methods' => ['DELETE'], 'uri' => 'api/v1/teacher/materials/{material}', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_list_is_tenant_teacher_current_membership_scoped_and_allows_archived_group_history(): void
    {
        [$institution, $teacher, $admin, $group] = $this->context();
        $foreignInstitution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $foreignInstitution->id]);
        $otherTeacher = $this->teacher($institution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $archivedGroup = $this->group($institution, $admin, archived: true);
        $endedGroup = $this->group($institution, $admin);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin);
        $this->membership($institution, $archivedGroup, $teacher, $admin);
        $this->membership($institution, $endedGroup, $teacher, $admin, ended: true);

        $topic = $this->topic($institution, $group, $teacher);
        $archivedTopic = $this->topic($institution, $archivedGroup, $teacher);
        $otherTopic = $this->topic($institution, $group, $otherTeacher);
        $endedTopic = $this->topic($institution, $endedGroup, $teacher);
        $foreignTopic = $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher);
        $material = $this->material($institution, $topic, $teacher, ['title' => 'Visible']);
        $archivedMaterial = $this->material($institution, $archivedTopic, $teacher, ['title' => 'History']);
        $this->material($institution, $topic, $otherTeacher, ['title' => 'Mismatched material owner']);
        $this->material($institution, $otherTopic, $otherTeacher);
        $this->material($institution, $endedTopic, $teacher);
        $this->material($foreignInstitution, $foreignTopic, $foreignTeacher);

        $response = $this->requestAs($teacher, 'GET', $this->uri($topic));
        $response->assertOk();
        $this->assertSame([$material->id], collect($response->json('data'))->pluck('id')->all());

        $archivedResponse = $this->requestAs($teacher, 'GET', $this->uri($archivedTopic));
        $archivedResponse->assertOk()->assertJsonPath('data.0.id', $archivedMaterial->id);

        foreach ([$otherTopic->id, $endedTopic->id, $foreignTopic->id, 'invalid', '00000000-0000-0000-0000-000000000099'] as $hiddenTopic) {
            $this->requestAs($teacher, 'GET', '/api/v1/teacher/topics/'.$hiddenTopic.'/materials')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    public function test_list_filters_non_current_or_wrong_category_rows_and_serializes_exact_private_safe_resource(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher);
        $visible = $this->material($institution, $topic, $teacher, [
            'title' => 'Lesson slides',
            'created_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 15:30:00', 'UTC'),
        ], [
            'original_name' => 'lesson.pptx',
            'storage_disk' => 'secret-disk',
            'storage_key' => 'private/secret-key.pptx',
            'mime_type' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'extension' => FileExtension::Pptx,
            'size_bytes' => 1_250_000,
            'checksum_sha256' => str_repeat('a', 64),
        ]);
        $this->material($institution, $topic, $teacher, ['removed_at' => now()], ['removed_at' => null]);
        $this->material($institution, $topic, $teacher, [], ['removed_at' => now()]);
        $this->material($institution, $topic, $teacher, [], [
            'category' => FileCategory::StudentSubmission,
            'original_name' => 'submission.docx',
            'storage_key' => 'private/submission.docx',
            'extension' => FileExtension::Docx,
            'mime_type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ]);

        $response = $this->requestAs($teacher, 'GET', $this->uri($topic));
        $response->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertCount(1, $response->json('data'));
        $resource = $response->json('data.0');
        $this->assertSame(self::MATERIAL_KEYS, array_keys($resource));
        $this->assertSame(['id', 'original_name', 'mime_type', 'extension', 'size_bytes'], array_keys($resource['file']));
        $this->assertSame($visible->id, $resource['id']);
        $this->assertSame('2026-08-07T15:00:00Z', $resource['created_at']);
        $this->assertSame('2026-08-07T15:30:00Z', $resource['updated_at']);

        foreach (['institution_id', 'teacher_id', 'uploaded_by_user_id', 'secret-disk', 'private/secret-key.pptx', str_repeat('a', 64), 'removed_at'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public function test_list_orders_by_position_created_at_and_uuid_tie_break(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher);
        $sameTime = CarbonImmutable::parse('2026-08-22 10:00:00', 'UTC');
        $third = $this->material($institution, $topic, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000003', 'position' => 1, 'created_at' => $sameTime,
        ]);
        $first = $this->material($institution, $topic, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000001', 'position' => 0, 'created_at' => $sameTime->addMinute(),
        ]);
        $second = $this->material($institution, $topic, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000002', 'position' => 1, 'created_at' => $sameTime,
        ]);

        $response = $this->requestAs($teacher, 'GET', $this->uri($topic));
        $response->assertOk();
        $this->assertSame([$first->id, $second->id, $third->id], collect($response->json('data'))->pluck('id')->all());
    }

    public function test_upload_meta_uses_current_lower_limit_and_default_platform_limit(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher);
        InstitutionSetting::query()->whereKey($institution->id)->update(['learning_material_max_mb' => 20]);

        $response = $this->requestAs($teacher, 'GET', $this->uri($topic));
        $response->assertOk();
        $this->assertSame([
            'max_size_bytes' => 20 * 1_048_576,
            'platform_max_size_bytes' => 25 * 1_048_576,
            'allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx'],
        ], $response->json('meta.upload'));

        InstitutionSetting::query()->whereKey($institution->id)->update(['learning_material_max_mb' => 25]);
        $this->requestAs($teacher, 'GET', $this->uri($topic))
            ->assertOk()->assertJsonPath('meta.upload.max_size_bytes', 26_214_400);
    }

    public function test_list_rejects_any_query_or_body_and_resources_issue_no_hidden_queries(): void
    {
        [$institution, $teacher, , $group] = $this->context();
        $topic = $this->topic($institution, $group, $teacher);
        $this->material($institution, $topic, $teacher);

        $this->requestAs($teacher, 'GET', $this->uri($topic), ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($teacher, 'GET', $this->uri($topic), content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $list = app(ListTeacherLearningMaterials::class)($teacher, $topic->id);
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            foreach ($list->materials as $material) {
                (new TeacherLearningMaterialResource($material))->toArray(Request::create('/'));
            }
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame([], $queries);
    }

    public function test_material_routes_enforce_authentication_role_account_institution_and_password_gates(): void
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $uri = '/api/v1/teacher/topics/00000000-0000-0000-0000-000000000001/materials';

        $this->getJson($uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $this->requestAs($this->teacher($institution, ['is_active' => false]), 'GET', $uri)
            ->assertForbidden()->assertJsonPath('code', 'user_inactive');
        $this->requestAs($this->teacher($institution, ['must_change_password' => true]), 'GET', $uri)
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        InstitutionSetting::factory()->create(['institution_id' => $inactiveInstitution->id]);
        $this->requestAs($this->teacher($inactiveInstitution), 'GET', $uri)
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::InstitutionAdmin, UserRole::Student, UserRole::Parent] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
            $this->requestAs($actor, 'GET', $uri)->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
    }

    /** @return array{Institution, User, User, Group} */
    private function context(): array
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $group = $this->group($institution, $admin);
        $this->membership($institution, $group, $teacher, $admin);

        return [$institution, $teacher, $admin, $group];
    }

    private function teacher(Institution $institution, array $attributes = []): User
    {
        return User::factory()->teacher($institution)->create(array_merge(['must_change_password' => false], $attributes));
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

    private function membership(Institution $institution, Group $group, User $teacher, User $admin, bool $ended = false): void
    {
        ($ended ? GroupTeacherMembership::factory()->ended() : GroupTeacherMembership::factory())->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
    }

    private function topic(Institution $institution, Group $group, User $teacher): Topic
    {
        return Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
    }

    private function material(Institution $institution, Topic $topic, User $teacher, array $attributes = [], array $fileAttributes = []): LearningMaterial
    {
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

    private function uri(Topic $topic): string
    {
        return '/api/v1/teacher/topics/'.$topic->id.'/materials';
    }

    /** @param array<string, mixed> $query */
    private function requestAs(User $actor, string $method, string $uri, array $query = [], string $content = ''): TestResponse
    {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('teacher-material-read-api-test')->plainTextToken,
        ];
        $response = $this->call($method, $requestUri, [], [], [], $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }
}
