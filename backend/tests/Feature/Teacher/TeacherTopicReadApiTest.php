<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\ListTeacherTopics;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
use App\Http\Resources\Teacher\TeacherTopicResource;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class TeacherTopicReadApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/teacher/topics';

    private const TOPIC_KEYS = [
        'id',
        'group',
        'title',
        'description',
        'subject',
        'student_instructions',
        'lesson_at',
        'status',
        'activated_at',
        'closed_at',
        'archived_at',
        'created_at',
        'updated_at',
    ];

    public function test_teacher_topic_routes_are_registered_once_with_exact_methods_and_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => str_starts_with($route['uri'], 'api/v1/teacher/topics'))
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/teacher/topics', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/teacher/topics', 'middleware' => $middleware],
            ['methods' => ['GET'], 'uri' => 'api/v1/teacher/topics/{topic}', 'middleware' => $middleware],
            ['methods' => ['PATCH'], 'uri' => 'api/v1/teacher/topics/{topic}', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_list_is_tenant_teacher_and_current_membership_scoped_with_exact_resources(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $otherTeacher = $this->teacher($institution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);

        $activeGroup = $this->group($institution, $admin, ['name' => '9-A']);
        $archivedGroup = $this->group($institution, $admin, ['name' => 'Archived 10-B'], archived: true);
        $endedGroup = $this->group($institution, $admin, ['name' => 'Ended']);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin, ['name' => 'Foreign']);
        $this->membership($institution, $activeGroup, $teacher, $admin);
        $this->membership($institution, $archivedGroup, $teacher, $admin);
        $this->membership($institution, $endedGroup, $teacher, $admin, ended: true);

        $activeTopic = $this->topic($institution, $activeGroup, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000001',
            'title' => 'Active Group Topic',
            'lesson_at' => CarbonImmutable::parse('2026-08-25 04:00:00', 'UTC'),
            'created_at' => CarbonImmutable::parse('2026-08-22 08:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-22 08:30:00', 'UTC'),
        ]);
        $archivedGroupTopic = $this->topic($institution, $archivedGroup, $teacher, [
            'id' => '00000000-0000-0000-0000-000000000002',
            'title' => 'Archived Group Topic',
            'created_at' => CarbonImmutable::parse('2026-08-22 09:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-22 09:00:00', 'UTC'),
        ]);
        $otherTeacherTopic = $this->topic($institution, $activeGroup, $otherTeacher, ['title' => 'Other teacher secret']);
        $endedTopic = $this->topic($institution, $endedGroup, $teacher, ['title' => 'Ended secret']);
        $foreignTopic = $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher, ['title' => 'Foreign secret']);

        $response = $this->requestAs($teacher, 'GET', self::URI);

        $response->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertSame([$archivedGroupTopic->id, $activeTopic->id], collect($response->json('data'))->pluck('id')->all());
        $this->assertSame(['page' => 1, 'per_page' => 20, 'total' => 2, 'last_page' => 1], $response->json('meta.pagination'));

        $resource = $response->json('data.1');
        $this->assertTopicResource($resource);
        $this->assertSame('2026-08-25T04:00:00Z', $resource['lesson_at']);
        $this->assertSame('2026-08-22T08:00:00Z', $resource['created_at']);
        $this->assertSame('2026-08-22T08:30:00Z', $resource['updated_at']);
        $this->assertSame('archived', $response->json('data.0.group.status'));

        foreach (['institution_id', 'teacher_id', 'membership', 'storage', 'materials', 'results', $otherTeacherTopic->id, $endedTopic->id, $foreignTopic->id] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public function test_list_filters_search_sorts_ties_and_paginates_deterministically(): void
    {
        $institution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $group = $this->group($institution, $admin);
        $this->membership($institution, $group, $teacher, $admin);

        $topics = [
            $this->topic($institution, $group, $teacher, [
                'id' => '00000000-0000-0000-0000-000000000003',
                'title' => 'same',
                'subject' => 'Web_100%',
                'lesson_at' => CarbonImmutable::parse('2026-08-25 05:00:00', 'UTC'),
                'created_at' => CarbonImmutable::parse('2026-08-22 03:00:00', 'UTC'),
                'updated_at' => CarbonImmutable::parse('2026-08-22 06:00:00', 'UTC'),
            ]),
            $this->topic($institution, $group, $teacher, [
                'id' => '00000000-0000-0000-0000-000000000001',
                'title' => 'Same',
                'subject' => 'Plain',
                'lesson_at' => null,
                'created_at' => CarbonImmutable::parse('2026-08-22 01:00:00', 'UTC'),
                'updated_at' => CarbonImmutable::parse('2026-08-22 04:00:00', 'UTC'),
            ]),
            $this->topic($institution, $group, $teacher, [
                'id' => '00000000-0000-0000-0000-000000000002',
                'title' => 'Zulu Percent%',
                'subject' => 'Other',
                'lesson_at' => CarbonImmutable::parse('2026-08-25 04:00:00', 'UTC'),
                'created_at' => CarbonImmutable::parse('2026-08-22 02:00:00', 'UTC'),
                'updated_at' => CarbonImmutable::parse('2026-08-22 05:00:00', 'UTC'),
            ]),
        ];
        $active = $this->topic($institution, $group, $teacher, [], TopicStatus::Active);

        $this->assertSame([$active->id, $topics[0]->id, $topics[2]->id, $topics[1]->id], $this->ids($this->requestAs($teacher, 'GET', self::URI)));
        $this->assertSame([$topics[1]->id, $topics[0]->id, $topics[2]->id], array_values(array_intersect(
            $this->ids($this->requestAs($teacher, 'GET', self::URI, query: ['sort' => 'title', 'direction' => 'asc'])),
            collect($topics)->pluck('id')->all(),
        )));
        $this->assertSame([$topics[0]->id, $topics[2]->id, $topics[1]->id], array_values(array_intersect(
            $this->ids($this->requestAs($teacher, 'GET', self::URI, query: ['sort' => 'lesson_at'])),
            collect($topics)->pluck('id')->all(),
        )));
        $this->assertSame([$topics[1]->id, $topics[2]->id, $topics[0]->id], array_values(array_intersect(
            $this->ids($this->requestAs($teacher, 'GET', self::URI, query: ['sort' => 'updated_at', 'direction' => 'asc'])),
            collect($topics)->pluck('id')->all(),
        )));
        $this->assertSame([$topics[0]->id], $this->ids($this->requestAs($teacher, 'GET', self::URI, query: ['search' => '_100%'])));
        $this->assertSame([$topics[0]->id, $topics[2]->id], $this->ids($this->requestAs($teacher, 'GET', self::URI, query: ['search' => '%'])));
        $this->assertSame([$active->id], $this->ids($this->requestAs($teacher, 'GET', self::URI, query: ['status' => 'active'])));

        $page = $this->requestAs($teacher, 'GET', self::URI, query: ['page' => 2, 'per_page' => 2]);
        $this->assertCount(2, $page->json('data'));
        $this->assertSame(['page' => 2, 'per_page' => 2, 'total' => 4, 'last_page' => 2], $page->json('meta.pagination'));
    }

    public function test_group_filter_is_scope_safe_and_allows_current_archived_or_empty_groups(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $archived = $this->group($institution, $admin, archived: true);
        $empty = $this->group($institution, $admin);
        $unrelated = $this->group($institution, $admin);
        $ended = $this->group($institution, $admin);
        $foreign = $this->group($foreignInstitution, $foreignAdmin);
        $this->membership($institution, $archived, $teacher, $admin);
        $this->membership($institution, $empty, $teacher, $admin);
        $this->membership($institution, $ended, $teacher, $admin, ended: true);
        $topic = $this->topic($institution, $archived, $teacher);

        $this->requestAs($teacher, 'GET', self::URI, query: ['group_id' => 'invalid'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        foreach ([$unrelated, $ended, $foreign] as $hiddenGroup) {
            $this->requestAs($teacher, 'GET', self::URI, query: ['group_id' => $hiddenGroup->id])
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertSame([$topic->id], $this->ids($this->requestAs($teacher, 'GET', self::URI, query: ['group_id' => $archived->id])));
        $emptyResponse = $this->requestAs($teacher, 'GET', self::URI, query: ['group_id' => $empty->id]);
        $emptyResponse->assertOk()->assertJsonPath('data', []);
    }

    public function test_detail_is_scope_safe_exact_and_rejects_query_or_body(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $otherTeacher = $this->teacher($institution);
        $foreignTeacher = $this->teacher($foreignInstitution);
        $admin = $this->admin($institution);
        $foreignAdmin = $this->admin($foreignInstitution);
        $group = $this->group($institution, $admin);
        $endedGroup = $this->group($institution, $admin);
        $foreignGroup = $this->group($foreignInstitution, $foreignAdmin);
        $this->membership($institution, $group, $teacher, $admin);
        $this->membership($institution, $endedGroup, $teacher, $admin, ended: true);
        $topic = $this->topic($institution, $group, $teacher);
        $other = $this->topic($institution, $group, $otherTeacher);
        $ended = $this->topic($institution, $endedGroup, $teacher);
        $foreign = $this->topic($foreignInstitution, $foreignGroup, $foreignTeacher);

        $response = $this->requestAs($teacher, 'GET', self::URI.'/'.$topic->id);
        $response->assertOk();
        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertTopicResource($response->json('data'));

        foreach (['not-a-uuid', '00000000-0000-0000-0000-000000000099', $other->id, $ended->id, $foreign->id] as $hiddenTopic) {
            $this->requestAs($teacher, 'GET', self::URI.'/'.$hiddenTopic)
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->requestAs($teacher, 'GET', self::URI.'/'.$topic->id, query: ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($teacher, 'GET', self::URI.'/'.$topic->id, content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_list_rejects_unknown_invalid_query_and_any_body(): void
    {
        $institution = Institution::factory()->create();
        $teacher = $this->teacher($institution);

        foreach ([
            ['unknown' => 'x'],
            ['status' => 'published'],
            ['page' => 0],
            ['per_page' => 101],
            ['sort' => 'status'],
            ['direction' => 'sideways'],
            ['search' => str_repeat('x', 255)],
        ] as $query) {
            $this->requestAs($teacher, 'GET', self::URI, query: $query)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->requestAs($teacher, 'GET', self::URI, content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_topic_resources_issue_no_hidden_queries(): void
    {
        $institution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $admin = $this->admin($institution);
        $group = $this->group($institution, $admin);
        $this->membership($institution, $group, $teacher, $admin);
        $this->topic($institution, $group, $teacher);
        $this->topic($institution, $group, $teacher);

        $paginator = app(ListTeacherTopics::class)(
            teacher: $teacher,
            groupId: null,
            status: null,
            search: null,
            sort: ListTeacherTopics::DEFAULT_SORT,
            direction: ListTeacherTopics::DEFAULT_DIRECTION,
            page: 1,
            perPage: 20,
        );

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            foreach ($paginator->items() as $topic) {
                (new TeacherTopicResource($topic))->toArray(Request::create('/'));
            }
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame([], $queries);
    }

    public function test_read_routes_enforce_authentication_role_account_institution_and_password_gates(): void
    {
        $institution = Institution::factory()->create();

        $this->getJson(self::URI)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $this->requestAs($this->teacher($institution, ['is_active' => false]), 'GET', self::URI)
            ->assertForbidden()->assertJsonPath('code', 'user_inactive');
        $this->requestAs($this->teacher($institution, ['must_change_password' => true]), 'GET', self::URI)
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $this->requestAs($this->teacher($inactiveInstitution), 'GET', self::URI)
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::InstitutionAdmin, UserRole::Student, UserRole::Parent] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
            $this->requestAs($actor, 'GET', self::URI)->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
    }

    private function teacher(Institution $institution, array $attributes = []): User
    {
        return User::factory()->teacher($institution)->create(array_merge(['must_change_password' => false], $attributes));
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

    private function membership(Institution $institution, Group $group, User $teacher, User $admin, bool $ended = false): void
    {
        $factory = $ended ? GroupTeacherMembership::factory()->ended() : GroupTeacherMembership::factory();
        $factory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $admin->id,
        ]);
    }

    private function topic(
        Institution $institution,
        Group $group,
        User $teacher,
        array $attributes = [],
        TopicStatus $status = TopicStatus::Draft,
    ): Topic {
        $factory = match ($status) {
            TopicStatus::Active => Topic::factory()->active(),
            TopicStatus::Closed => Topic::factory()->closed(),
            TopicStatus::Archived => Topic::factory()->archivedFromDraft(),
            TopicStatus::Draft => Topic::factory(),
        };

        return $factory->create(array_merge([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
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
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('teacher-topic-read-api-test')->plainTextToken,
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

    /** @param array<string, mixed> $resource */
    private function assertTopicResource(array $resource): void
    {
        $this->assertSame(self::TOPIC_KEYS, array_keys($resource));
        $this->assertSame(['id', 'name', 'level', 'subject_direction', 'status'], array_keys($resource['group']));
        $this->assertContains($resource['status'], TopicStatus::values());
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['created_at']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['updated_at']);
    }
}
