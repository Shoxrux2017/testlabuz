<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ListInstitutionGroups;
use App\Actions\Institution\ShowInstitutionGroup;
use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Http\Resources\Institution\InstitutionGroupResource;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class InstitutionGroupReadApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/institution/groups';

    private const RESOURCE_KEYS = [
        'id',
        'name',
        'level',
        'subject_direction',
        'description',
        'status',
        'teachers_count',
        'students_count',
        'archived_at',
        'created_at',
        'updated_at',
    ];

    public function test_all_group_routes_are_registered_once_with_exact_methods_and_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => str_starts_with($route['uri'], 'api/v1/institution/groups'))
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/institution/groups', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/institution/groups', 'middleware' => $middleware],
            ['methods' => ['GET'], 'uri' => 'api/v1/institution/groups/{group}', 'middleware' => $middleware],
            ['methods' => ['PATCH'], 'uri' => 'api/v1/institution/groups/{group}', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/institution/groups/{group}/archive', 'middleware' => $middleware],
            ['methods' => ['GET'], 'uri' => 'api/v1/institution/groups/{group}/teachers', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/institution/groups/{group}/teachers', 'middleware' => $middleware],
            ['methods' => ['DELETE'], 'uri' => 'api/v1/institution/groups/{group}/teachers/{teacher}', 'middleware' => $middleware],
            ['methods' => ['GET'], 'uri' => 'api/v1/institution/groups/{group}/students', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/institution/groups/{group}/students', 'middleware' => $middleware],
            ['methods' => ['DELETE'], 'uri' => 'api/v1/institution/groups/{group}/students/{student}', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_default_list_is_tenant_scoped_and_returns_exact_resources_counts_and_pagination(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);

        $active = Group::factory()->create([
            'id' => '00000000-0000-0000-0000-000000000001',
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Alpha Group',
            'level' => 'Grade 10',
            'subject_direction' => 'General',
            'description' => null,
            'created_at' => CarbonImmutable::parse('2026-08-19 10:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-19 10:30:00', 'UTC'),
        ]);
        $archived = Group::factory()->archived()->create([
            'id' => '00000000-0000-0000-0000-000000000002',
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Beta Group',
            'archived_at' => CarbonImmutable::parse('2026-08-19 11:00:00', 'UTC'),
        ]);
        $foreign = Group::factory()->create([
            'institution_id' => $foreignInstitution->id,
            'created_by_user_id' => $foreignActor->id,
            'name' => 'Foreign Group',
        ]);

        $activeTeacher = User::factory()->teacher($institution)->create();
        $inactiveTeacher = User::factory()->teacher($institution)->inactive()->create();
        $activeStudent = User::factory()->student($institution)->create();
        $endedStudent = User::factory()->student($institution)->create();

        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $active->id,
            'teacher_id' => $activeTeacher->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $active->id,
            'teacher_id' => $inactiveTeacher->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $active->id,
            'student_id' => $activeStudent->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        GroupStudentMembership::factory()->ended()->create([
            'institution_id' => $institution->id,
            'group_id' => $active->id,
            'student_id' => $endedStudent->id,
            'assigned_by_user_id' => $actor->id,
        ]);

        $response = $this->requestAs($actor, 'GET', self::BASE_URI);

        $response->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertSame([$active->id, $archived->id], collect($response->json('data'))->pluck('id')->all());
        $this->assertSame([
            'page' => 1,
            'per_page' => 20,
            'total' => 2,
            'last_page' => 1,
        ], $response->json('meta.pagination'));

        foreach (['page', 'per_page', 'total', 'last_page'] as $key) {
            $this->assertIsInt($response->json('meta.pagination.'.$key));
        }

        $this->assertGroupResource($response->json('data.0'));
        $this->assertSame(2, $response->json('data.0.teachers_count'));
        $this->assertSame(1, $response->json('data.0.students_count'));
        $this->assertIsInt($response->json('data.0.teachers_count'));
        $this->assertIsInt($response->json('data.0.students_count'));
        $this->assertSame('2026-08-19T10:00:00Z', $response->json('data.0.created_at'));
        $this->assertSame('2026-08-19T10:30:00Z', $response->json('data.0.updated_at'));
        $this->assertNull($response->json('data.0.archived_at'));
        $this->assertSame('archived', $response->json('data.1.status'));
        $this->assertSame('2026-08-19T11:00:00Z', $response->json('data.1.archived_at'));

        $content = $response->getContent();
        foreach (['institution_id', 'created_by_user_id', 'teacher_memberships', 'student_memberships', $foreign->id] as $protected) {
            $this->assertStringNotContainsString($protected, $content);
        }
    }

    public function test_list_supports_literal_search_filters_all_sorts_deterministic_ties_and_pagination(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $groups = [
            Group::factory()->create([
                'id' => '00000000-0000-0000-0000-000000000003',
                'institution_id' => $institution->id,
                'created_by_user_id' => $actor->id,
                'name' => 'same',
                'level' => 'Grade_10%',
                'subject_direction' => 'General!',
                'created_at' => CarbonImmutable::parse('2026-08-19 03:00:00', 'UTC'),
                'updated_at' => CarbonImmutable::parse('2026-08-19 06:00:00', 'UTC'),
            ]),
            Group::factory()->archived()->create([
                'id' => '00000000-0000-0000-0000-000000000001',
                'institution_id' => $institution->id,
                'created_by_user_id' => $actor->id,
                'name' => 'Same',
                'level' => 'Plain',
                'subject_direction' => 'Science',
                'created_at' => CarbonImmutable::parse('2026-08-19 01:00:00', 'UTC'),
                'updated_at' => CarbonImmutable::parse('2026-08-19 04:00:00', 'UTC'),
            ]),
            Group::factory()->create([
                'id' => '00000000-0000-0000-0000-000000000002',
                'institution_id' => $institution->id,
                'created_by_user_id' => $actor->id,
                'name' => 'Zulu Percent%',
                'level' => 'Other',
                'subject_direction' => 'Arts',
                'created_at' => CarbonImmutable::parse('2026-08-19 02:00:00', 'UTC'),
                'updated_at' => CarbonImmutable::parse('2026-08-19 05:00:00', 'UTC'),
            ]),
        ];

        $default = $this->requestAs($actor, 'GET', self::BASE_URI);
        $this->assertSame([$groups[1]->id, $groups[0]->id, $groups[2]->id], $this->ids($default));

        $descendingTie = $this->requestAs($actor, 'GET', self::BASE_URI, query: [
            'sort' => 'name',
            'direction' => 'desc',
        ]);
        $this->assertSame([$groups[2]->id, $groups[0]->id, $groups[1]->id], $this->ids($descendingTie));

        foreach ([
            ['status', 'asc', [$groups[2]->id, $groups[0]->id, $groups[1]->id]],
            ['created_at', 'asc', [$groups[1]->id, $groups[2]->id, $groups[0]->id]],
            ['updated_at', 'desc', [$groups[0]->id, $groups[2]->id, $groups[1]->id]],
        ] as [$sort, $direction, $expected]) {
            $response = $this->requestAs($actor, 'GET', self::BASE_URI, query: compact('sort', 'direction'));
            $this->assertSame($expected, $this->ids($response), $sort);
        }

        $this->assertSame(
            [$groups[1]->id],
            $this->ids($this->requestAs($actor, 'GET', self::BASE_URI, query: ['status' => 'archived'])),
        );
        $this->assertSame(
            [$groups[0]->id],
            $this->ids($this->requestAs($actor, 'GET', self::BASE_URI, query: ['search' => '_10%'])),
        );
        $this->assertSame(
            [$groups[0]->id],
            $this->ids($this->requestAs($actor, 'GET', self::BASE_URI, query: ['search' => 'general!'])),
        );
        $this->assertSame(
            [$groups[0]->id, $groups[2]->id],
            $this->ids($this->requestAs($actor, 'GET', self::BASE_URI, query: ['search' => '%'])),
        );
        $this->assertSame(3, $this->requestAs($actor, 'GET', self::BASE_URI, query: ['search' => '   '])->json('meta.pagination.total'));

        $page = $this->requestAs($actor, 'GET', self::BASE_URI, query: ['page' => 2, 'per_page' => 2]);
        $this->assertSame([$groups[2]->id], $this->ids($page));
        $this->assertSame(['page' => 2, 'per_page' => 2, 'total' => 3, 'last_page' => 2], $page->json('meta.pagination'));

        $empty = $this->requestAs($actor, 'GET', self::BASE_URI, query: ['search' => 'not present']);
        $this->assertSame([], $empty->json('data'));
        $this->assertSame(['page' => 1, 'per_page' => 20, 'total' => 0, 'last_page' => 1], $empty->json('meta.pagination'));
    }

    public function test_list_and_detail_reject_strict_transport_shapes_and_hide_invalid_missing_and_cross_tenant_ids(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $otherActor = $this->institutionAdmin($otherInstitution);
        $active = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $archived = Group::factory()->archived()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $foreign = Group::factory()->create([
            'institution_id' => $otherInstitution->id,
            'created_by_user_id' => $otherActor->id,
        ]);

        foreach ([
            ['query' => ['unknown' => 'x']],
            ['query' => ['status' => 'ACTIVE']],
            ['query' => ['page' => 0]],
            ['query' => ['per_page' => 101]],
            ['query' => ['sort' => 'description']],
            ['query' => ['direction' => 'sideways']],
            ['query' => ['search' => str_repeat('x', 255)]],
            ['content' => '{}'],
            ['content' => ' '],
        ] as $case) {
            $this->requestAs(
                $actor,
                'GET',
                self::BASE_URI,
                content: $case['content'] ?? '',
                query: $case['query'] ?? [],
            )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach ([$active, $archived] as $group) {
            $response = $this->requestAs($actor, 'GET', self::BASE_URI.'/'.$group->id);
            $response->assertOk()->assertJsonPath('data.id', $group->id);
            $this->assertGroupResource($response->json('data'));
        }

        $notFoundEnvelopes = [];
        foreach (['not-a-uuid', '11111111-1111-4111-8111-111111111111', $foreign->id] as $identifier) {
            $response = $this->requestAs($actor, 'GET', self::BASE_URI.'/'.$identifier);
            $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $notFoundEnvelopes[] = $response->json();
        }
        $this->assertSame($notFoundEnvelopes[0], $notFoundEnvelopes[1]);
        $this->assertSame($notFoundEnvelopes[1], $notFoundEnvelopes[2]);

        $this->requestAs($actor, 'GET', self::BASE_URI.'/'.$active->id, query: ['x' => '1'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($actor, 'GET', self::BASE_URI.'/'.$active->id, content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_read_queries_are_bounded_tenant_scoped_and_resources_issue_no_queries(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $otherActor = $this->institutionAdmin($otherInstitution);

        foreach (range(1, 8) as $index) {
            Group::factory()->create([
                'institution_id' => $institution->id,
                'created_by_user_id' => $actor->id,
                'name' => 'Bounded '.$index,
            ]);
        }
        Group::factory()->create([
            'institution_id' => $otherInstitution->id,
            'created_by_user_id' => $otherActor->id,
            'name' => 'Bounded Foreign',
        ]);

        foreach ([1, 8] as $perPage) {
            DB::flushQueryLog();
            DB::enableQueryLog();
            try {
                $paginator = app(ListInstitutionGroups::class)(
                    actor: $actor,
                    search: 'Bounded',
                    status: null,
                    sort: 'name',
                    direction: 'asc',
                    page: 1,
                    perPage: $perPage,
                );

                foreach ($paginator->items() as $group) {
                    (new InstitutionGroupResource($group))->toArray(Request::create('/'));
                }
                $queries = DB::getQueryLog();
            } finally {
                DB::disableQueryLog();
            }

            $this->assertCount(2, $queries);
            $selectSql = strtolower($queries[1]['query']);
            $this->assertStringContainsString('from "groups"', $selectSql);
            $this->assertStringContainsString('"institution_id" = ?', $selectSql);
            $this->assertStringContainsString('group_teacher_memberships', $selectSql);
            $this->assertStringContainsString('group_student_memberships', $selectSql);
            $this->assertStringContainsString('"ended_at" is null', $selectSql);
            $this->assertStringContainsString("ilike ? escape '!'", $selectSql);
            $this->assertStringContainsString('order by lower(name) asc, "id" asc', $selectSql);
            $this->assertStringNotContainsString('select *', $selectSql);
            $this->assertTrue(collect($queries[1]['bindings'])->containsStrict($institution->id));
            $this->assertFalse(collect($queries[1]['bindings'])->containsStrict($otherInstitution->id));
        }

        $target = Group::query()->where('institution_id', $institution->id)->firstOrFail();
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $resolved = app(ShowInstitutionGroup::class)($actor, $target->id);
            (new InstitutionGroupResource($resolved))->toArray(Request::create('/'));
            $detailQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }
        $this->assertCount(1, $detailQueries);
        $this->assertStringContainsString('"institution_id" = ?', strtolower($detailQueries[0]['query']));
        $this->assertStringContainsString('group_teacher_memberships', strtolower($detailQueries[0]['query']));
    }

    public function test_read_endpoints_enforce_authentication_role_account_institution_and_password_gates(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);

        foreach ([self::BASE_URI, self::BASE_URI.'/'.$group->id] as $uri) {
            $this->rawRequest('GET', $uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');

            $inactive = $this->institutionAdmin($institution, ['is_active' => false]);
            $this->requestAs($inactive, 'GET', $uri)->assertForbidden()->assertJsonPath('code', 'user_inactive');

            $passwordIncomplete = $this->institutionAdmin($institution, ['must_change_password' => true]);
            $this->requestAs($passwordIncomplete, 'GET', $uri)->assertForbidden()->assertJsonPath('code', 'password_change_required');

            $inactiveInstitution = Institution::factory()->inactive()->create();
            $inactiveInstitutionActor = $this->institutionAdmin($inactiveInstitution);
            $this->requestAs($inactiveInstitutionActor, 'GET', $uri)->assertForbidden()->assertJsonPath('code', 'institution_inactive');

            foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
                $wrongRole = $role === UserRole::PlatformOwner
                    ? User::factory()->platformOwner()->create(['must_change_password' => false])
                    : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
                $this->requestAs($wrongRole, 'GET', $uri)->assertForbidden()->assertJsonPath('code', 'forbidden');
            }
        }
    }

    private function institutionAdmin(Institution $institution, array $attributes = []): User
    {
        return User::factory()->institutionAdmin($institution)->create(array_merge([
            'must_change_password' => false,
        ], $attributes));
    }

    /** @param array<string, mixed> $query */
    private function requestAs(
        User $actor,
        string $method,
        string $uri,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $token = $actor->createToken('institution-group-read-api-test')->plainTextToken;
        $response = $this->rawRequest($method, $uri, $token, $content, $query, $contentType);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @param array<string, mixed> $query */
    private function rawRequest(
        string $method,
        string $uri,
        ?string $token = null,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json'];

        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call($method, $requestUri, [], [], [], $server, $content);
    }

    /** @return list<string> */
    private function ids(TestResponse $response): array
    {
        $response->assertOk();

        return collect($response->json('data'))->pluck('id')->all();
    }

    /** @param array<string, mixed> $resource */
    private function assertGroupResource(array $resource): void
    {
        $this->assertSame(self::RESOURCE_KEYS, array_keys($resource));
        $this->assertIsString($resource['id']);
        $this->assertIsString($resource['name']);
        $this->assertContains($resource['status'], GroupStatus::values());
        $this->assertIsInt($resource['teachers_count']);
        $this->assertIsInt($resource['students_count']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['created_at']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['updated_at']);

        if ($resource['archived_at'] !== null) {
            $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['archived_at']);
        }

        foreach (['institution_id', 'created_by_user_id', 'teacher_memberships', 'student_memberships'] as $protected) {
            $this->assertArrayNotHasKey($protected, $resource);
        }
    }
}
