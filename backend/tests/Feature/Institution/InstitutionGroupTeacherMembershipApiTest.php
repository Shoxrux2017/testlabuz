<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ListInstitutionGroupTeachers;
use App\Enums\UserRole;
use App\Http\Resources\Institution\InstitutionGroupTeacherMembershipResource;
use App\Models\Group;
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

class InstitutionGroupTeacherMembershipApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/institution/groups';

    private const RESOURCE_KEYS = [
        'id',
        'full_name',
        'login_name',
        'email',
        'phone',
        'is_active',
        'started_at',
    ];

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_teacher_membership_routes_are_registered_once_with_exact_methods_and_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => str_contains($route['uri'], '/teachers'))
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/institution/groups/{group}/teachers', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/institution/groups/{group}/teachers', 'middleware' => $middleware],
            ['methods' => ['DELETE'], 'uri' => 'api/v1/institution/groups/{group}/teachers/{teacher}', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_teacher_list_is_current_tenant_scoped_searchable_deterministic_paginated_and_query_bounded(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $group = $this->group($institution, $actor);
        $archivedGroup = Group::factory()->archived()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $foreignGroup = $this->group($foreignInstitution, $foreignActor);

        $first = User::factory()->teacher($institution)->create([
            'id' => '00000000-0000-4000-8000-000000000001',
            'full_name' => 'alpha Same',
            'login_name' => 'teacher_alpha_literal',
            'email' => null,
            'phone' => '+99890000%_!',
        ]);
        $second = User::factory()->teacher($institution)->inactive()->create([
            'id' => '00000000-0000-4000-8000-000000000002',
            'full_name' => 'Alpha Same',
            'login_name' => 'teacher_beta_literal',
            'email' => 'beta@example.uz',
            'phone' => null,
        ]);
        $ended = User::factory()->teacher($institution)->create();
        $student = User::factory()->student($institution)->create();
        $foreignTeacher = User::factory()->teacher($foreignInstitution)->create();

        $firstMembership = $this->teacherMembership($institution, $group, $first, $actor, [
            'started_at' => CarbonImmutable::parse('2026-08-19 10:00:00', 'UTC'),
        ]);
        $this->teacherMembership($institution, $group, $second, $actor, [
            'started_at' => CarbonImmutable::parse('2026-08-19 11:00:00', 'UTC'),
        ]);
        $this->teacherMembership($institution, $group, $ended, $actor, [
            'started_at' => CarbonImmutable::parse('2026-08-18 10:00:00', 'UTC'),
            'ended_at' => CarbonImmutable::parse('2026-08-18 12:00:00', 'UTC'),
        ]);
        $this->teacherMembership($foreignInstitution, $foreignGroup, $foreignTeacher, $foreignActor);

        $default = $this->requestAs($actor, 'GET', $this->teachersUri($group));
        $default->assertOk();
        $this->assertSame([$first->id, $second->id], $this->ids($default));
        $this->assertSame(['page' => 1, 'per_page' => 20, 'total' => 2, 'last_page' => 1], $default->json('meta.pagination'));
        $this->assertTeacherResource($default->json('data.0'));
        $this->assertNull($default->json('data.0.email'));
        $this->assertIsBool($default->json('data.0.is_active'));
        $this->assertSame('2026-08-19T10:00:00Z', $default->json('data.0.started_at'));

        $this->assertSame([$first->id], $this->ids($this->requestAs($actor, 'GET', $this->teachersUri($group), query: ['status' => 'active'])));
        $this->assertSame([$second->id], $this->ids($this->requestAs($actor, 'GET', $this->teachersUri($group), query: ['status' => 'inactive'])));
        $this->assertSame([$first->id], $this->ids($this->requestAs($actor, 'GET', $this->teachersUri($group), query: ['search' => '  %_!  '])));
        $this->assertSame([$second->id, $first->id], $this->ids($this->requestAs($actor, 'GET', $this->teachersUri($group), query: [
            'sort' => 'started_at',
            'direction' => 'desc',
        ])));
        $page = $this->requestAs($actor, 'GET', $this->teachersUri($group), query: ['page' => 2, 'per_page' => 1]);
        $this->assertSame([$second->id], $this->ids($page));
        $this->assertSame(['page' => 2, 'per_page' => 1, 'total' => 2, 'last_page' => 2], $page->json('meta.pagination'));

        $this->teacherMembership($institution, $archivedGroup, $first, $actor);
        $this->requestAs($actor, 'GET', $this->teachersUri($archivedGroup))->assertOk()->assertJsonCount(1, 'data');

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $paginator = app(ListInstitutionGroupTeachers::class)(
                actor: $actor,
                group: $group->id,
                search: 'alpha',
                isActive: null,
                sort: 'full_name',
                direction: 'asc',
                page: 1,
                perPage: 20,
            );
            foreach ($paginator->items() as $teacher) {
                (new InstitutionGroupTeacherMembershipResource($teacher))->toArray(Request::create('/'));
            }
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertCount(3, $queries);
        $listSql = strtolower($queries[2]['query']);
        $this->assertStringContainsString('group_teacher_memberships', $listSql);
        $this->assertStringContainsString('"users"."institution_id" = ?', $listSql);
        $this->assertStringContainsString('"group_teacher_memberships"."institution_id" = ?', $listSql);
        $this->assertStringContainsString("ilike ? escape '!'", $listSql);
        $this->assertStringContainsString('order by lower(users.full_name) asc, "users"."id" asc', $listSql);
        $this->assertStringNotContainsString('select *', $listSql);
        $this->assertSame($firstMembership->teacher_id, $first->id);
        $this->assertSame(UserRole::Student, $student->role);
    }

    public function test_bulk_teacher_assign_is_atomic_ordered_idempotent_and_preserves_existing_rows_and_counts(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = $this->group($institution, $actor);
        $secondGroup = $this->group($institution, $actor);
        $first = User::factory()->teacher($institution)->create([
            'id' => '10000000-0000-4000-8000-000000000001',
            'full_name' => 'First Teacher',
            'email' => null,
            'phone' => null,
        ]);
        $second = User::factory()->teacher($institution)->create([
            'id' => '10000000-0000-4000-8000-000000000002',
            'full_name' => 'Second Teacher',
        ]);
        $third = User::factory()->teacher($institution)->create();

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 10:00:00.987654', 'UTC'));
        $firstAssign = $this->jsonRequestAs($actor, 'POST', $this->teachersUri($group), [
            'teacher_ids' => [strtoupper($second->id), strtoupper($first->id)],
        ]);
        $firstAssign->assertCreated()->assertJsonPath('message', 'Teachers assigned to group successfully.');
        $this->assertSame([$second->id, $first->id], $this->ids($firstAssign));
        $this->assertSame(self::RESOURCE_KEYS, array_keys($firstAssign->json('data.0')));
        $this->assertSame('2026-08-19T10:00:00Z', $firstAssign->json('data.0.started_at'));

        $rows = GroupTeacherMembership::query()->where('group_id', $group->id)->orderBy('teacher_id')->get();
        $this->assertCount(2, $rows);
        foreach ($rows as $row) {
            $this->assertSame($institution->id, $row->institution_id);
            $this->assertSame($actor->id, $row->assigned_by_user_id);
            $this->assertNull($row->ended_at);
        }
        $this->assertSame(2, $this->groupCounts($actor, $group)['teachers_count']);

        $timestamps = $rows->mapWithKeys(fn (GroupTeacherMembership $row): array => [$row->teacher_id => [
            $row->started_at->toJSON(),
            $row->created_at->toJSON(),
            $row->updated_at->toJSON(),
        ]])->all();
        $second->forceFill(['is_active' => false, 'deactivated_at' => now()])->save();
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-20 10:00:00', 'UTC'));

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $idempotent = $this->jsonRequestAs($actor, 'POST', $this->teachersUri($group), [
                'teacher_ids' => [$second->id, $first->id],
            ]);
            $idempotentQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }
        $idempotent->assertOk();
        $this->assertSame([$second->id, $first->id], $this->ids($idempotent));
        $this->assertFalse(collect($idempotentQueries)->contains(
            fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "group_teacher_memberships"')
                || str_starts_with(strtolower((string) $query['query']), 'insert into "group_teacher_memberships"')
        ));
        $this->assertSame($timestamps, GroupTeacherMembership::query()->where('group_id', $group->id)->get()
            ->mapWithKeys(fn (GroupTeacherMembership $row): array => [$row->teacher_id => [
                $row->started_at->toJSON(),
                $row->created_at->toJSON(),
                $row->updated_at->toJSON(),
            ]])->all());

        $mixed = $this->jsonRequestAs($actor, 'POST', $this->teachersUri($group), [
            'teacher_ids' => [$first->id, $third->id],
        ]);
        $mixed->assertCreated();
        $this->assertSame([$first->id, $third->id], $this->ids($mixed));
        $this->assertDatabaseCount('group_teacher_memberships', 3);
        $this->assertSame(3, $this->groupCounts($actor, $group)['teachers_count']);

        $this->jsonRequestAs($actor, 'POST', $this->teachersUri($secondGroup), [
            'teacher_ids' => [$first->id],
        ])->assertCreated();
        $this->assertSame(2, GroupTeacherMembership::query()->where('teacher_id', $first->id)->whereNull('ended_at')->count());
    }

    public function test_teacher_remove_ends_once_allows_inactive_member_and_reassignment_creates_history(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = $this->group($institution, $actor);
        $teacher = User::factory()->teacher($institution)->inactive()->create();
        $membership = $this->teacherMembership($institution, $group, $teacher, $actor, [
            'started_at' => CarbonImmutable::parse('2026-08-18 08:00:00', 'UTC'),
            'created_at' => CarbonImmutable::parse('2026-08-18 08:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-18 08:00:00', 'UTC'),
        ]);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 09:00:00', 'UTC'));
        $this->requestAs($actor, 'DELETE', $this->teachersUri($group).'/'.$teacher->id)
            ->assertNoContent()->assertContent('');
        $membership->refresh();
        $this->assertSame('2026-08-19T09:00:00.000000Z', $membership->ended_at?->format('Y-m-d\TH:i:s.u\Z'));
        $this->assertDatabaseCount('group_teacher_memberships', 1);
        $this->assertSame(0, $this->groupCounts($actor, $group)['teachers_count']);
        $snapshot = $membership->only(['started_at', 'ended_at', 'created_at', 'updated_at']);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-20 09:00:00', 'UTC'));
        $this->requestAs($actor, 'DELETE', $this->teachersUri($group).'/'.$teacher->id)->assertNoContent();
        $this->assertEquals($snapshot, $membership->refresh()->only(['started_at', 'ended_at', 'created_at', 'updated_at']));

        $teacher->forceFill(['is_active' => true, 'deactivated_at' => null])->save();
        $this->jsonRequestAs($actor, 'POST', $this->teachersUri($group), ['teacher_ids' => [$teacher->id]])->assertCreated();
        $this->assertSame(2, GroupTeacherMembership::query()->where('group_id', $group->id)->where('teacher_id', $teacher->id)->count());
        $this->assertSame(1, GroupTeacherMembership::query()->where('group_id', $group->id)->where('teacher_id', $teacher->id)->whereNull('ended_at')->count());
    }

    public function test_teacher_transport_privacy_conflicts_and_atomic_rollbacks_are_exact(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $group = $this->group($institution, $actor);
        $archived = Group::factory()->archived()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $foreignGroup = $this->group($foreignInstitution, $foreignActor);
        $valid = User::factory()->teacher($institution)->create();
        $inactive = User::factory()->teacher($institution)->inactive()->create();
        $student = User::factory()->student($institution)->create();
        $foreignTeacher = User::factory()->teacher($foreignInstitution)->create();

        foreach ([
            ['', 'application/json'],
            ['{malformed', 'application/json'],
            ['[]', 'application/json'],
            ['"scalar"', 'application/json'],
            [json_encode(['teacher_ids' => [$valid->id]], JSON_THROW_ON_ERROR), 'text/plain'],
            [json_encode(['teacher_ids' => []], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['teacher_ids' => ['target' => $valid->id]], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['teacher_ids' => array_fill(0, 101, $valid->id)], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['teacher_ids' => ['invalid']], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['teacher_ids' => [$valid->id, $valid->id]], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['teacher_ids' => [strtoupper($valid->id), strtolower($valid->id)]], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['student_ids' => [$valid->id]], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['teacher_ids' => [$valid->id], 'institution_id' => $institution->id], JSON_THROW_ON_ERROR), 'application/json'],
        ] as [$content, $contentType]) {
            $this->requestAs($actor, 'POST', $this->teachersUri($group), content: $content, contentType: $contentType)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->jsonRequestAs($actor, 'POST', $this->teachersUri($group).'?unknown=1', ['teacher_ids' => [$valid->id]])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseCount('group_teacher_memberships', 0);

        $notFoundEnvelopes = [];
        foreach (['11111111-1111-4111-8111-111111111111', $student->id, $foreignTeacher->id] as $target) {
            $response = $this->jsonRequestAs($actor, 'POST', $this->teachersUri($group), ['teacher_ids' => [$valid->id, $target]]);
            $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $notFoundEnvelopes[] = $response->json();
            $this->assertDatabaseCount('group_teacher_memberships', 0);
        }
        $this->assertSame($notFoundEnvelopes[0], $notFoundEnvelopes[1]);
        $this->assertSame($notFoundEnvelopes[1], $notFoundEnvelopes[2]);

        $this->jsonRequestAs($actor, 'POST', $this->teachersUri($group), ['teacher_ids' => [$valid->id, $inactive->id]])
            ->assertConflict()
            ->assertExactJson([
                'message' => 'The selected user is inactive.',
                'code' => 'business_conflict',
                'errors' => [],
            ]);
        $this->assertDatabaseCount('group_teacher_memberships', 0);

        $this->jsonRequestAs($actor, 'POST', $this->teachersUri($archived), ['teacher_ids' => [$valid->id]])
            ->assertConflict()
            ->assertExactJson([
                'message' => 'The group is archived.',
                'code' => 'business_conflict',
                'errors' => [],
            ]);

        foreach (['invalid', '22222222-2222-4222-8222-222222222222', $foreignGroup->id] as $groupId) {
            $this->requestAs($actor, 'GET', self::BASE_URI.'/'.$groupId.'/teachers')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->requestAs($actor, 'GET', $this->teachersUri($group), content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($actor, 'GET', $this->teachersUri($group), query: ['unknown' => '1'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($actor, 'DELETE', $this->teachersUri($group).'/'.$valid->id, content: '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->requestAs($actor, 'DELETE', $this->teachersUri($group).'/'.$valid->id, query: ['unknown' => '1'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_teacher_membership_endpoints_enforce_all_institution_admin_middleware_gates(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = $this->group($institution, $actor);
        $teacher = User::factory()->teacher($institution)->create();
        $operations = [
            ['GET', $this->teachersUri($group), ''],
            ['POST', $this->teachersUri($group), json_encode(['teacher_ids' => [$teacher->id]], JSON_THROW_ON_ERROR)],
            ['DELETE', $this->teachersUri($group).'/'.$teacher->id, ''],
        ];

        foreach ($operations as [$method, $uri, $content]) {
            $this->rawRequest($method, $uri, content: $content)
                ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');

            $this->requestAs($this->institutionAdmin($institution, ['is_active' => false]), $method, $uri, content: $content)
                ->assertForbidden()->assertJsonPath('code', 'user_inactive');
            $this->requestAs($this->institutionAdmin($institution, ['must_change_password' => true]), $method, $uri, content: $content)
                ->assertForbidden()->assertJsonPath('code', 'password_change_required');

            $inactiveInstitution = Institution::factory()->inactive()->create();
            $this->requestAs($this->institutionAdmin($inactiveInstitution), $method, $uri, content: $content)
                ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

            foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
                $this->requestAs($this->userForRole($role, $institution), $method, $uri, content: $content)
                    ->assertForbidden()->assertJsonPath('code', 'forbidden');
            }
        }
    }

    private function institutionAdmin(Institution $institution, array $attributes = []): User
    {
        return User::factory()->institutionAdmin($institution)->create(array_merge([
            'must_change_password' => false,
        ], $attributes));
    }

    private function userForRole(UserRole $role, Institution $institution): User
    {
        $factory = match ($role) {
            UserRole::PlatformOwner => User::factory()->platformOwner(),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
        };

        return $factory->create(['must_change_password' => false]);
    }

    private function group(Institution $institution, User $actor): Group
    {
        return Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
    }

    private function teacherMembership(
        Institution $institution,
        Group $group,
        User $teacher,
        User $actor,
        array $attributes = [],
    ): GroupTeacherMembership {
        return GroupTeacherMembership::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $actor->id,
        ], $attributes));
    }

    /** @return array<string, int> */
    private function groupCounts(User $actor, Group $group): array
    {
        return $this->requestAs($actor, 'GET', self::BASE_URI.'/'.$group->id)->assertOk()->json('data');
    }

    private function teachersUri(Group $group): string
    {
        return self::BASE_URI.'/'.$group->id.'/teachers';
    }

    /** @param array<string, mixed> $payload */
    private function jsonRequestAs(User $actor, string $method, string $uri, array $payload): TestResponse
    {
        return $this->requestAs(
            $actor,
            $method,
            $uri,
            content: json_encode($payload, JSON_THROW_ON_ERROR),
        );
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
        $token = $actor->createToken('institution-group-teacher-membership-api-test')->plainTextToken;
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
        return collect($response->json('data'))->pluck('id')->all();
    }

    /** @param array<string, mixed> $resource */
    private function assertTeacherResource(array $resource): void
    {
        $this->assertSame(self::RESOURCE_KEYS, array_keys($resource));
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['started_at']);

        foreach (['institution_id', 'membership_id', 'group_id', 'assigned_by_user_id', 'ended_at', 'role', 'password'] as $protected) {
            $this->assertArrayNotHasKey($protected, $resource);
        }
    }
}
