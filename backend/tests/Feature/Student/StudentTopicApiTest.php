<?php

namespace Tests\Feature\Student;

use App\Actions\Student\ShowStudentTopic;
use App\Enums\FileCategory;
use App\Enums\FileExtension;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Http\Resources\Student\StudentTopicResource;
use App\Models\File;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\Institution;
use App\Models\LearningMaterial;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class StudentTopicApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/student/topics';

    public function test_student_topic_routes_are_exact_and_enforce_all_middleware_gates(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => in_array($route['uri'], [
                'api/v1/student/topics',
                'api/v1/student/topics/{topic}',
            ], true))
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'];
        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/student/topics', 'middleware' => $middleware],
            ['methods' => ['GET'], 'uri' => 'api/v1/student/topics/{topic}', 'middleware' => $middleware],
        ], $routes);

        $institution = Institution::factory()->create();
        $this->getJson(self::URI)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $this->requestAs($this->student($institution, ['is_active' => false]), 'GET', self::URI)
            ->assertForbidden()->assertJsonPath('code', 'user_inactive');
        $this->requestAs($this->student($institution, ['must_change_password' => true]), 'GET', self::URI)
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $this->requestAs($this->student($inactiveInstitution), 'GET', self::URI)
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Parent] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
            $this->requestAs($actor, 'GET', self::URI)
                ->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
    }

    public function test_list_is_tenant_current_membership_and_non_draft_scoped_with_archived_group_history(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $student = $this->student($institution);
        $teacher = $this->teacher($institution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $currentGroup = $this->group($institution, $admin, ['name' => '9-A']);
        $archivedGroup = $this->group($institution, $admin, ['name' => 'Archive'], archived: true);
        $endedGroup = $this->group($institution, $admin, ['name' => 'Ended']);
        $unrelatedGroup = $this->group($institution, $admin, ['name' => 'Unrelated']);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin, ['name' => 'Foreign']);
        $this->studentMembership($institution, $currentGroup, $student, $admin);
        $this->studentMembership($institution, $archivedGroup, $student, $admin);
        $this->studentMembership($institution, $endedGroup, $student, $admin, ended: true);

        $active = $this->topic($institution, $currentGroup, $teacher, TopicStatus::Active, [
            'lesson_at' => CarbonImmutable::parse('2026-08-25 04:00:00', 'UTC'),
            'created_at' => CarbonImmutable::parse('2026-08-22 08:00:00', 'UTC'),
        ]);
        $closed = $this->topic($institution, $currentGroup, $teacher, TopicStatus::Closed, [
            'created_at' => CarbonImmutable::parse('2026-08-22 09:00:00', 'UTC'),
        ]);
        $archived = $this->topic($institution, $archivedGroup, $teacher, TopicStatus::Archived, [
            'created_at' => CarbonImmutable::parse('2026-08-22 10:00:00', 'UTC'),
        ]);
        $draft = $this->topic($institution, $currentGroup, $teacher, TopicStatus::Draft);
        $ended = $this->topic($institution, $endedGroup, $teacher, TopicStatus::Active);
        $unrelated = $this->topic($institution, $unrelatedGroup, $teacher, TopicStatus::Active);
        $foreign = $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher, TopicStatus::Active);

        $response = $this->requestAs($student, 'GET', self::URI);
        $response->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertSame([$archived->id, $closed->id, $active->id], collect($response->json('data'))->pluck('id')->all());
        $this->assertSame(['page' => 1, 'per_page' => 20, 'total' => 3, 'last_page' => 1], $response->json('meta.pagination'));
        $this->assertSame(
            ['id', 'group', 'title', 'subject', 'lesson_at', 'status'],
            array_keys($response->json('data.2')),
        );
        $this->assertSame(['id', 'name', 'level', 'subject_direction', 'status'], array_keys($response->json('data.2.group')));
        $this->assertSame('2026-08-25T04:00:00Z', $response->json('data.2.lesson_at'));
        $this->assertSame('archived', $response->json('data.0.group.status'));

        foreach (['institution_id', 'teacher_id', 'membership', 'storage', $draft->id, $ended->id, $unrelated->id, $foreign->id] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public function test_list_filters_literal_search_and_deterministic_pagination(): void
    {
        $institution = Institution::factory()->create();
        $student = $this->student($institution);
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $group = $this->group($institution, $admin);
        $this->studentMembership($institution, $group, $student, $admin);
        $sameTime = CarbonImmutable::parse('2026-08-22 10:00:00', 'UTC');

        $low = $this->topic($institution, $group, $teacher, TopicStatus::Active, [
            'id' => '00000000-0000-0000-0000-000000000001',
            'title' => 'Plain',
            'subject' => 'Literal_100%',
            'created_at' => $sameTime,
        ]);
        $middle = $this->topic($institution, $group, $teacher, TopicStatus::Closed, [
            'id' => '00000000-0000-0000-0000-000000000002',
            'title' => 'PERCENT% lesson',
            'subject' => 'Other',
            'created_at' => $sameTime,
        ]);
        $high = $this->topic($institution, $group, $teacher, TopicStatus::Archived, [
            'id' => '00000000-0000-0000-0000-000000000003',
            'title' => 'Newest',
            'subject' => 'Other',
            'created_at' => $sameTime,
        ]);

        $this->assertSame([$high->id, $middle->id, $low->id], $this->ids($this->requestAs($student, 'GET', self::URI)));
        $this->assertSame([$low->id], $this->ids($this->requestAs($student, 'GET', self::URI, ['search' => '  _100%  '])));
        $this->assertSame([$middle->id, $low->id], $this->ids($this->requestAs($student, 'GET', self::URI, ['search' => '%'])));
        $this->assertSame([$middle->id], $this->ids($this->requestAs($student, 'GET', self::URI, ['status' => 'closed'])));
        $this->assertSame([$high->id, $middle->id, $low->id], $this->ids($this->requestAs($student, 'GET', self::URI, ['search' => '   '])));

        $page = $this->requestAs($student, 'GET', self::URI, ['page' => 2, 'per_page' => 2]);
        $page->assertOk();
        $this->assertSame([$low->id], collect($page->json('data'))->pluck('id')->all());
        $this->assertSame(['page' => 2, 'per_page' => 2, 'total' => 3, 'last_page' => 2], $page->json('meta.pagination'));
    }

    public function test_list_accepts_only_locked_query_shape_and_rejects_any_body(): void
    {
        $institution = Institution::factory()->create();
        $student = $this->student($institution);

        foreach ([
            ['unknown' => 'x'],
            ['sort' => 'created_at'],
            ['status' => 'draft'],
            ['status' => 'published'],
            ['page' => 0],
            ['page' => 'one'],
            ['per_page' => 0],
            ['per_page' => 101],
            ['search' => str_repeat('x', 255)],
        ] as $query) {
            $this->requestAs($student, 'GET', self::URI, $query)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->requestAs($student, 'GET', self::URI, content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_detail_returns_exact_current_material_projection_order_and_placeholders_without_hidden_queries(): void
    {
        $institution = Institution::factory()->create();
        $student = $this->student($institution);
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $group = $this->group($institution, $admin, [
            'name' => '9-A', 'level' => 'Grade 9', 'subject_direction' => 'Informatics',
        ]);
        $this->studentMembership($institution, $group, $student, $admin);
        $topic = $this->topic($institution, $group, $teacher, TopicStatus::Active, [
            'title' => 'Internet Basics',
            'description' => 'Optional description',
            'subject' => 'Informatics',
            'student_instructions' => 'Study the materials.',
            'lesson_at' => null,
        ]);
        $sameTime = CarbonImmutable::parse('2026-08-22 10:00:00', 'UTC');
        $third = $this->material($institution, $topic, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000003', 'position' => 1, 'created_at' => $sameTime,
        ]);
        $first = $this->material($institution, $topic, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000001', 'title' => 'Lesson slides', 'position' => 0, 'created_at' => $sameTime->addMinute(),
        ], [
            'original_name' => 'lesson.pptx',
            'extension' => FileExtension::Pptx,
            'mime_type' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'size_bytes' => 1_250_000,
            'storage_disk' => 'secret-disk',
            'storage_key' => 'private/secret-key.pptx',
        ]);
        $second = $this->material($institution, $topic, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000002', 'position' => 1, 'created_at' => $sameTime,
        ]);
        $this->material($institution, $topic, $teacher, ['removed_at' => now()]);
        $this->material($institution, $topic, $teacher, [], ['removed_at' => now()]);
        $this->material($institution, $topic, $teacher, [], ['category' => FileCategory::StudentSubmission]);

        $response = $this->requestAs($student, 'GET', self::URI.'/'.$topic->id);
        $response->assertOk();
        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertSame([
            'id', 'group', 'title', 'description', 'subject', 'student_instructions', 'lesson_at', 'status',
            'materials', 'homework', 'blitz_status', 'result_status',
        ], array_keys($response->json('data')));
        $this->assertSame([$first->id, $second->id, $third->id], collect($response->json('data.materials'))->pluck('id')->all());
        $this->assertSame(['id', 'title', 'file'], array_keys($response->json('data.materials.0')));
        $this->assertSame(['id', 'original_name', 'extension', 'size_bytes'], array_keys($response->json('data.materials.0.file')));
        $this->assertSame([], $response->json('data.homework'));
        $this->assertSame('not_available', $response->json('data.blitz_status'));
        $this->assertSame('waiting_for_homework', $response->json('data.result_status'));

        foreach (['institution_id', 'teacher_id', 'uploaded_by_user_id', 'mime_type', 'secret-disk', 'private/secret-key.pptx', 'checksum_sha256', 'removed_at', 'position', 'url'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }

        $resolved = app(ShowStudentTopic::class)($student, $topic->id);
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            (new StudentTopicResource($resolved))->response()->getContent();
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }
        $this->assertSame([], $queries);
    }

    public function test_detail_is_privacy_safe_for_all_out_of_scope_targets_and_rejects_extra_input(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $student = $this->student($institution);
        $teacher = $this->teacher($institution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $currentGroup = $this->group($institution, $admin);
        $endedGroup = $this->group($institution, $admin);
        $unrelatedGroup = $this->group($institution, $admin);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin);
        $this->studentMembership($institution, $currentGroup, $student, $admin);
        $this->studentMembership($institution, $endedGroup, $student, $admin, ended: true);
        $visible = $this->topic($institution, $currentGroup, $teacher, TopicStatus::Active);
        $hidden = [
            $this->topic($institution, $currentGroup, $teacher, TopicStatus::Draft)->id,
            $this->topic($institution, $endedGroup, $teacher, TopicStatus::Active)->id,
            $this->topic($institution, $unrelatedGroup, $teacher, TopicStatus::Active)->id,
            $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher, TopicStatus::Active)->id,
            'not-a-uuid',
            '00000000-0000-0000-0000-000000000099',
        ];

        foreach ($hidden as $topicId) {
            $this->requestAs($student, 'GET', self::URI.'/'.$topicId)
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->requestAs($student, 'GET', self::URI.'/'.$visible->id, ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($student, 'GET', self::URI.'/'.$visible->id, content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    private function student(Institution $institution, array $attributes = []): User
    {
        return User::factory()->student($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    private function teacher(Institution $institution): User
    {
        return User::factory()->teacher($institution)->create(['must_change_password' => false]);
    }

    private function admin(Institution $institution): User
    {
        return User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    }

    private function group(Institution $institution, User $admin, array $attributes = [], bool $archived = false): Group
    {
        $factory = $archived ? Group::factory()->archived() : Group::factory();

        return $factory->create(array_merge([
            'institution_id' => $institution->id,
            'created_by_user_id' => $admin->id,
        ], $attributes));
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

    private function topic(
        Institution $institution,
        Group $group,
        User $teacher,
        TopicStatus $status,
        array $attributes = [],
    ): Topic {
        $factory = match ($status) {
            TopicStatus::Active => Topic::factory()->active(),
            TopicStatus::Closed => Topic::factory()->closed(),
            TopicStatus::Archived => Topic::factory()->archivedFromClosed(),
            TopicStatus::Draft => Topic::factory(),
        };

        return $factory->create(array_merge([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ], $attributes));
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
    private function requestAs(
        User $actor,
        string $method,
        string $uri,
        array $query = [],
        string $content = '',
    ): TestResponse {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('student-topic-api-test')->plainTextToken,
        ];
        $response = $this->call($method, $requestUri, [], [], [], $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @return list<string> */
    private function ids(TestResponse $response): array
    {
        $response->assertOk();

        return collect($response->json('data'))->pluck('id')->all();
    }
}
