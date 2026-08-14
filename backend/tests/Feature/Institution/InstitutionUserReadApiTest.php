<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ListInstitutionUsers;
use App\Actions\Institution\ShowInstitutionUser;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class InstitutionUserReadApiTest extends TestCase
{
    use RefreshDatabase;

    private const INDEX_URI = '/api/v1/institution/users';

    public function test_user_read_routes_are_registered_once_with_required_middleware_order(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => in_array($route['uri'], [
                'api/v1/institution/users',
                'api/v1/institution/users/{user}',
            ], true))
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'];

        $this->assertSame([
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/institution/users',
                'middleware' => $middleware,
            ],
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/institution/users/{user}',
                'middleware' => $middleware,
            ],
        ], $routes);
    }

    public function test_default_list_returns_exact_own_tenant_resource_and_truthful_pagination(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'timezone' => 'Sensitive/Timezone',
        ]);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);

        $teacher = $this->createUserForRole(UserRole::Teacher, $institution, [
            'id' => '00000000-0000-0000-0000-000000000001',
            'full_name' => 'Alpha Teacher',
            'login_name' => 'alpha_teacher',
            'email' => null,
            'phone' => '+998900000001',
            'is_active' => true,
            'must_change_password' => true,
            'last_login_at' => null,
            'deactivated_at' => null,
            'created_at' => CarbonImmutable::parse('2026-08-07 08:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 09:00:00', 'UTC'),
        ]);
        $student = $this->createUserForRole(UserRole::Student, $institution, [
            'id' => '00000000-0000-0000-0000-000000000002',
            'full_name' => 'beta Student',
            'login_name' => 'beta_student',
            'is_active' => false,
            'must_change_password' => false,
            'last_login_at' => CarbonImmutable::parse('2026-08-07 10:00:00', 'UTC'),
            'deactivated_at' => CarbonImmutable::parse('2026-08-07 11:00:00', 'UTC'),
        ]);
        $parent = $this->createUserForRole(UserRole::Parent, $institution, [
            'id' => '00000000-0000-0000-0000-000000000003',
            'full_name' => 'Gamma Parent',
            'login_name' => 'gamma_parent',
        ]);
        $ownInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        foreach ([UserRole::Teacher, UserRole::Student, UserRole::Parent, UserRole::InstitutionAdmin] as $role) {
            $this->createUserForRole($role, $otherInstitution, [
                'full_name' => 'Foreign '.$role->value,
                'login_name' => 'foreign_'.$role->value,
            ]);
        }

        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();
        $response = $this->rawList($token);

        $response->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertSame([$teacher->id, $student->id, $parent->id], $this->idsFromList($response));
        $this->assertSame([
            'page' => 1,
            'per_page' => 20,
            'total' => 3,
            'last_page' => 1,
        ], $response->json('meta.pagination'));

        foreach (['page', 'per_page', 'total', 'last_page'] as $paginationKey) {
            $this->assertIsInt($response->json('meta.pagination.'.$paginationKey));
        }

        $this->assertInstitutionUserResource($response, 'data.0', UserRole::Teacher);
        $this->assertTrue($response->json('data.0.is_active'));
        $this->assertTrue($response->json('data.0.must_change_password'));
        $this->assertNull($response->json('data.0.email'));
        $this->assertNull($response->json('data.0.last_login_at'));
        $this->assertNull($response->json('data.0.deactivated_at'));
        $this->assertSame('2026-08-07T08:00:00Z', $response->json('data.0.created_at'));
        $this->assertSame('2026-08-07T09:00:00Z', $response->json('data.0.updated_at'));
        $this->assertFalse($response->json('data.1.is_active'));
        $this->assertSame('2026-08-07T10:00:00Z', $response->json('data.1.last_login_at'));
        $this->assertSame('2026-08-07T11:00:00Z', $response->json('data.1.deactivated_at'));

        $content = $response->getContent();
        foreach ([
            'institution_id',
            'created_by_user_id',
            'creator',
            'remember_token',
            'personal_access_tokens',
            'permissions',
            'Sensitive/Timezone',
            'institution_settings',
            'relationships',
            'answers',
            'scores',
            'results',
            'message',
            'links',
            $otherInstitution->id,
            $ownInstitutionAdmin->id,
            $platformOwner->id,
        ] as $protectedValue) {
            $this->assertStringNotContainsString($protectedValue, $content, $protectedValue);
        }
        foreach ($response->json('data') as $resource) {
            $this->assertArrayNotHasKey('password', $resource);
        }

        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
    }

    public function test_role_status_and_literal_search_filters_are_tenant_safe_and_validate_boundaries(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);

        $teacher = $this->createUserForRole(UserRole::Teacher, $institution, [
            'full_name' => 'Needle Teacher Bang! Percent% Under_score',
            'login_name' => 'plain_teacher_login',
            'email' => null,
            'phone' => null,
        ]);
        $student = $this->createUserForRole(UserRole::Student, $institution, [
            'full_name' => 'Plain Student',
            'login_name' => 'NeedleStudentLogin',
            'email' => null,
            'phone' => null,
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $parentByEmail = $this->createUserForRole(UserRole::Parent, $institution, [
            'full_name' => 'Plain Email Parent',
            'login_name' => 'plain_email_parent',
            'email' => 'NEEDLE-parent@example.uz',
            'phone' => null,
        ]);
        $parentByPhone = $this->createUserForRole(UserRole::Parent, $institution, [
            'full_name' => 'Plain Phone Parent',
            'login_name' => 'plain_phone_parent',
            'email' => null,
            'phone' => '+998-NEEDLE-42',
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $literalNonMatch = $this->createUserForRole(UserRole::Teacher, $institution, [
            'full_name' => 'BangX PercentX UnderYscore',
            'login_name' => 'literal_non_match',
        ]);
        $this->createUserForRole(UserRole::Teacher, $otherInstitution, [
            'full_name' => 'Needle Teacher Bang! Percent% Under_score',
            'login_name' => 'foreign_search_match',
        ]);

        $this->assertEqualsCanonicalizing([$teacher->id, $literalNonMatch->id], $this->idsFromList($this->authorizedList($actor, [
            'role' => UserRole::Teacher->value,
        ])));
        $this->assertEqualsCanonicalizing([$student->id, $parentByPhone->id], $this->idsFromList($this->authorizedList($actor, [
            'status' => 'inactive',
        ])));
        $this->assertSame([$student->id], $this->idsFromList($this->authorizedList($actor, [
            'role' => UserRole::Student->value,
            'status' => 'inactive',
        ])));

        $this->assertSame([$teacher->id], $this->idsFromList($this->authorizedList($actor, ['search' => '  needle teacher  '])));
        $this->assertSame([$student->id], $this->idsFromList($this->authorizedList($actor, ['search' => 'needlestudentlogin'])));
        $this->assertSame([$parentByEmail->id], $this->idsFromList($this->authorizedList($actor, ['search' => 'needle-parent@'])));
        $this->assertSame([$parentByPhone->id], $this->idsFromList($this->authorizedList($actor, ['search' => '+998-needle'])));
        $this->assertSame([$teacher->id], $this->idsFromList($this->authorizedList($actor, ['search' => 'Bang!'])));
        $this->assertSame([$teacher->id], $this->idsFromList($this->authorizedList($actor, ['search' => 'Percent%'])));
        $this->assertSame([$teacher->id], $this->idsFromList($this->authorizedList($actor, ['search' => 'Under_'])));

        $blankSearch = $this->authorizedList($actor, ['search' => '   ', 'per_page' => 100]);
        $blankSearch->assertOk();
        $this->assertSame(5, $blankSearch->json('meta.pagination.total'));

        $this->authorizedList($actor, ['search' => str_repeat('x', 254)])->assertOk();
        $oversized = $this->assertErrorContract(
            $this->authorizedList($actor, ['search' => str_repeat('x', 255)]),
            422,
            'validation_failed',
        );
        $this->assertObjectHasProperty('search', $oversized->errors);
    }

    public function test_all_sorts_directions_and_pagination_are_deterministic_and_exact(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $firstId = '00000000-0000-0000-0000-000000000001';
        $secondId = '00000000-0000-0000-0000-000000000002';
        $thirdId = '00000000-0000-0000-0000-000000000003';

        $this->createUserForRole(UserRole::Teacher, $institution, [
            'id' => $thirdId,
            'full_name' => 'Beta User',
            'login_name' => 'zeta_login',
            'created_at' => CarbonImmutable::parse('2026-01-03 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-04 00:00:00', 'UTC'),
        ]);
        $this->createUserForRole(UserRole::Student, $institution, [
            'id' => $secondId,
            'full_name' => 'alpha user',
            'login_name' => 'tie_login',
            'created_at' => CarbonImmutable::parse('2026-01-01 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-02 00:00:00', 'UTC'),
        ]);
        $this->createUserForRole(UserRole::Parent, $institution, [
            'id' => $firstId,
            'full_name' => 'Alpha User',
            'login_name' => 'Tie_Login',
            'created_at' => CarbonImmutable::parse('2026-01-01 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-02 00:00:00', 'UTC'),
        ]);

        $ascending = [$firstId, $secondId, $thirdId];
        $descending = [$thirdId, $secondId, $firstId];

        foreach (['full_name', 'login_name', 'created_at', 'updated_at'] as $sort) {
            $this->assertSame($ascending, $this->idsFromList($this->authorizedList($actor, [
                'sort' => $sort,
                'direction' => 'asc',
            ])), $sort.' asc');
            $this->assertSame($descending, $this->idsFromList($this->authorizedList($actor, [
                'sort' => $sort,
                'direction' => 'desc',
            ])), $sort.' desc');
        }

        $this->assertSame($ascending, $this->idsFromList($this->authorizedList($actor)));

        $firstPage = $this->authorizedList($actor, ['page' => 1, 'per_page' => 1]);
        $secondPage = $this->authorizedList($actor, ['page' => 2, 'per_page' => 1]);
        $outOfRange = $this->authorizedList($actor, ['page' => 5, 'per_page' => 1]);
        $maxPageSize = $this->authorizedList($actor, ['per_page' => 100]);
        $empty = $this->authorizedList($actor, ['search' => 'no-result-value']);

        $this->assertSame([$firstId], $this->idsFromList($firstPage));
        $this->assertSame([$secondId], $this->idsFromList($secondPage));
        $this->assertSame([], $this->idsFromList($outOfRange));
        $this->assertSame(5, $outOfRange->json('meta.pagination.page'));
        $this->assertSame(3, $outOfRange->json('meta.pagination.last_page'));
        $this->assertSame(100, $maxPageSize->json('meta.pagination.per_page'));
        $this->assertSame([], $empty->json('data'));
        $this->assertSame(0, $empty->json('meta.pagination.total'));
        $this->assertSame(1, $empty->json('meta.pagination.last_page'));
    }

    public function test_invalid_unknown_array_and_raw_sql_query_inputs_are_rejected_without_writes(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();

        $cases = [
            'invalid role' => [['role' => UserRole::InstitutionAdmin->value], 'role'],
            'array role' => [['role' => [UserRole::Teacher->value]], 'role'],
            'invalid status' => [['status' => 'suspended'], 'status'],
            'array status' => [['status' => ['active']], 'status'],
            'page below minimum' => [['page' => 0], 'page'],
            'page decimal' => [['page' => '1.5'], 'page'],
            'array page' => [['page' => [1]], 'page'],
            'per page below minimum' => [['per_page' => 0], 'per_page'],
            'per page above maximum' => [['per_page' => 101], 'per_page'],
            'unknown sort' => [['sort' => 'role'], 'sort'],
            'raw sort injection' => [['sort' => 'created_at desc, password'], 'sort'],
            'invalid direction' => [['direction' => 'desc nulls last'], 'direction'],
            'array search' => [['search' => ['needle']], 'search'],
            'unknown institution id' => [['institution_id' => $institution->id], 'institution_id'],
            'unknown include' => [['include' => 'relationships'], 'include'],
            'unknown order by' => [['order_by' => 'lower(full_name)'], 'order_by'],
        ];

        foreach ($cases as $case => [$query, $field]) {
            $decoded = $this->assertErrorContract(
                $this->rawList($token, query: $query),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $case);
            $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_both_get_endpoints_accept_only_zero_raw_body_bytes_and_detail_rejects_every_query_key(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $target = $this->createUserForRole(UserRole::Teacher, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();

        $this->rawList($token)->assertOk();
        $this->forgetAuthenticationGuards();
        $this->rawDetail($target->id, $token)->assertOk();
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());

        $bodyCases = [
            'whitespace' => [" \t\r\n", 'text/plain'],
            'empty object' => ['{}', 'application/json'],
            'keyed object' => ['{"role":"teacher"}', 'application/json'],
            'array' => ['[]', 'application/json'],
            'string scalar' => ['"teacher"', 'application/json'],
            'number scalar' => ['42', 'application/json'],
            'json null' => ['null', 'application/json'],
            'malformed json' => ['{"role":"teacher"', 'application/json'],
            'raw text' => ['raw body', 'text/plain'],
            'form content' => ['role=teacher', 'application/x-www-form-urlencoded'],
        ];

        foreach ($bodyCases as $case => [$content, $contentType]) {
            foreach ([
                'list' => fn (): TestResponse => $this->rawList($token, $content, contentType: $contentType),
                'detail' => fn (): TestResponse => $this->rawDetail($target->id, $token, $content, contentType: $contentType),
            ] as $endpoint => $request) {
                $decoded = $this->assertErrorContract($request(), 422, 'validation_failed', $endpoint.' '.$case);
                $this->assertObjectHasProperty('body', $decoded->errors, $endpoint.' '.$case);
                $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $endpoint.' '.$case);
                $this->forgetAuthenticationGuards();
            }
        }

        foreach ([
            'role' => UserRole::Teacher->value,
            'status' => 'active',
            'search' => 'target',
            'page' => 1,
            'per_page' => 20,
            'sort' => 'full_name',
            'direction' => 'asc',
            'institution_id' => $institution->id,
        ] as $key => $value) {
            $decoded = $this->assertErrorContract(
                $this->rawDetail($target->id, $token, query: [$key => $value]),
                422,
                'validation_failed',
                $key,
            );
            $this->assertObjectHasProperty($key, $decoded->errors, $key);
            $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $key);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_detail_returns_exact_active_and_inactive_resources_and_scope_safe_not_found(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $activeTeacher = $this->createUserForRole(UserRole::Teacher, $institution, [
            'email' => null,
            'phone' => '+998901112233',
            'last_login_at' => null,
        ]);
        $inactiveParent = $this->createUserForRole(UserRole::Parent, $institution, [
            'is_active' => false,
            'deactivated_at' => CarbonImmutable::parse('2026-08-07 11:00:00', 'UTC'),
        ]);
        $foreignStudent = $this->createUserForRole(UserRole::Student, $otherInstitution);
        $ownInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();

        $activeResponse = $this->rawDetail($activeTeacher->id, $token);
        $activeResponse->assertOk();
        $this->assertSame(['data'], array_keys($activeResponse->json()));
        $this->assertInstitutionUserResource($activeResponse, 'data', UserRole::Teacher);
        $this->assertSame($activeTeacher->id, $activeResponse->json('data.id'));
        $this->assertNull($activeResponse->json('data.email'));
        $this->assertNull($activeResponse->json('data.last_login_at'));
        $this->assertNull($activeResponse->json('data.deactivated_at'));
        $this->forgetAuthenticationGuards();

        $inactiveResponse = $this->rawDetail($inactiveParent->id, $token);
        $inactiveResponse->assertOk();
        $this->assertInstitutionUserResource($inactiveResponse, 'data', UserRole::Parent);
        $this->assertFalse($inactiveResponse->json('data.is_active'));
        $this->assertSame('2026-08-07T11:00:00Z', $inactiveResponse->json('data.deactivated_at'));
        $this->forgetAuthenticationGuards();

        $notFoundBodies = [];
        foreach ([
            'malformed' => 'not-a-uuid',
            'unknown' => Str::uuid()->toString(),
            'foreign' => $foreignStudent->id,
            'institution admin' => $ownInstitutionAdmin->id,
            'platform owner' => $platformOwner->id,
        ] as $case => $targetId) {
            $response = $this->rawDetail($targetId, $token);
            $this->assertErrorContract($response, 404, 'resource_not_found', $case);
            $notFoundBodies[] = $response->json();
            $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case);
            $this->forgetAuthenticationGuards();
        }
        foreach ($notFoundBodies as $notFoundBody) {
            $this->assertSame($notFoundBodies[0], $notFoundBody);
        }

        $queryBeforeResolution = $this->assertErrorContract(
            $this->rawDetail('not-a-uuid', $token, query: ['role' => 'teacher']),
            422,
            'validation_failed',
        );
        $this->assertObjectHasProperty('role', $queryBeforeResolution->errors);
        $this->forgetAuthenticationGuards();
        $bodyBeforeResolution = $this->assertErrorContract(
            $this->rawDetail('not-a-uuid', $token, '{}'),
            422,
            'validation_failed',
        );
        $this->assertObjectHasProperty('body', $bodyBeforeResolution->errors);

        $fakeTenantList = $this->rawList($token, serverOverrides: ['HTTP_X_INSTITUTION_ID' => $otherInstitution->id]);
        $fakeTenantList->assertOk();
        $this->assertStringNotContainsString($foreignStudent->id, $fakeTenantList->getContent());
        $this->forgetAuthenticationGuards();
        $fakeTenantDetail = $this->rawDetail(
            $foreignStudent->id,
            $token,
            serverOverrides: ['HTTP_X_INSTITUTION_ID' => $otherInstitution->id],
        );
        $this->assertErrorContract($fakeTenantDetail, 404, 'resource_not_found');
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
    }

    public function test_authentication_lifecycle_password_and_role_gates_precede_input_and_target_resolution(): void
    {
        $institution = Institution::factory()->create();

        foreach ([
            'list' => fn (?string $token): TestResponse => $this->rawList($token, '{}', ['unknown' => 'value']),
            'detail' => fn (?string $token): TestResponse => $this->rawDetail('not-a-uuid', $token, '{}', ['unknown' => 'value']),
        ] as $endpoint => $request) {
            $before = $this->protectedRowsSnapshot();
            $this->assertErrorContract($request(null), 401, 'authentication_required', $endpoint.' unauthenticated');
            $this->assertSame($before, $this->protectedRowsSnapshot());
            $this->forgetAuthenticationGuards();

            $inactiveUser = $this->createUserForRole(UserRole::Teacher, $institution, [
                'is_active' => false,
                'deactivated_at' => now(),
            ]);
            $this->assertGateWithoutWrites($request, $inactiveUser, 403, 'user_inactive', $endpoint);

            $inactiveInstitution = Institution::factory()->inactive()->create();
            $inactiveInstitutionUser = $this->createUserForRole(UserRole::Teacher, $inactiveInstitution);
            $this->assertGateWithoutWrites($request, $inactiveInstitutionUser, 403, 'institution_inactive', $endpoint);

            $passwordIncomplete = $this->createUserForRole(UserRole::Teacher, $institution, [
                'must_change_password' => true,
            ]);
            $this->assertGateWithoutWrites($request, $passwordIncomplete, 403, 'password_change_required', $endpoint);

            foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
                $wrongRole = $this->createUserForRole(
                    $role,
                    $role === UserRole::PlatformOwner ? null : $institution,
                );
                $this->assertGateWithoutWrites($request, $wrongRole, 403, 'forbidden', $endpoint.' '.$role->value);
            }
        }
    }

    public function test_actions_use_exactly_two_scoped_list_queries_and_one_scoped_detail_query(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $target = $this->createUserForRole(UserRole::Teacher, $institution, [
            'full_name' => 'Query Needle Teacher',
            'login_name' => 'query_needle_teacher',
        ]);
        $this->createUserForRole(UserRole::Teacher, $otherInstitution, [
            'full_name' => 'Query Needle Foreign',
            'login_name' => 'query_needle_foreign',
        ]);

        $retrievedUsers = 0;
        User::retrieved(function () use (&$retrievedUsers): void {
            $retrievedUsers++;
        });

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $paginator = app(ListInstitutionUsers::class)(
                actor: $actor,
                role: UserRole::Teacher->value,
                status: true,
                search: 'Query Needle',
                sort: 'login_name',
                direction: 'desc',
                page: 1,
                perPage: 20,
            );
            $listQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame([$target->id], collect($paginator->items())->pluck('id')->all());
        $this->assertCount(2, $listQueries);
        $this->assertSame(1, $retrievedUsers);

        $countSql = strtolower($listQueries[0]['query']);
        $selectSql = strtolower($listQueries[1]['query']);
        foreach ([$countSql, $selectSql] as $sql) {
            $this->assertStringContainsString('from "users"', $sql);
            $this->assertStringContainsString('"institution_id" = ?', $sql);
            $this->assertStringContainsString('"role" in (?, ?, ?)', $sql);
            $this->assertStringContainsString('"role" = ?', $sql);
            $this->assertStringContainsString('"is_active" = ?', $sql);
            $this->assertStringContainsString("ilike ? escape '!'", $sql);
        }
        $this->assertStringContainsString(
            'select "id", "role", "full_name", "login_name", "email", "phone", "is_active", "must_change_password", "last_login_at", "deactivated_at", "created_at", "updated_at"',
            $selectSql,
        );
        $this->assertStringContainsString('order by lower(login_name) desc, "id" desc', $selectSql);
        $this->assertStringNotContainsString('select *', $selectSql);
        $this->assertStringNotContainsString('join ', $selectSql);
        foreach ($listQueries as $query) {
            $bindings = collect($query['bindings']);
            $this->assertTrue($bindings->containsStrict($institution->id));
            $this->assertFalse($bindings->containsStrict($otherInstitution->id));
        }

        $retrievedBeforeDetail = $retrievedUsers;
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $resolved = app(ShowInstitutionUser::class)($actor, $target->id);
            $detailQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame($target->id, $resolved->id);
        $this->assertCount(1, $detailQueries);
        $this->assertSame($retrievedBeforeDetail + 1, $retrievedUsers);
        $detailSql = strtolower($detailQueries[0]['query']);
        $this->assertStringContainsString('from "users"', $detailSql);
        $this->assertStringContainsString('"users"."id" = ?', $detailSql);
        $this->assertStringContainsString('"institution_id" = ?', $detailSql);
        $this->assertStringContainsString('"role" in (?, ?, ?)', $detailSql);
        $this->assertStringNotContainsString('select *', $detailSql);
        $this->assertStringNotContainsString('join ', $detailSql);
        $this->assertTrue(collect($detailQueries[0]['bindings'])->containsStrict($institution->id));
        $this->assertFalse(collect($detailQueries[0]['bindings'])->containsStrict($otherInstitution->id));
    }

    public function test_controlled_list_and_detail_failures_return_safe_server_errors_without_writes(): void
    {
        config(['app.debug' => false]);

        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $target = $this->createUserForRole(UserRole::Teacher, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();
        $internalDetail = 'SQLSTATE controlled failure for '.$institution->id.' '.$actor->id.' '.$target->id;

        $listAction = Mockery::mock(ListInstitutionUsers::class);
        $listAction->shouldReceive('__invoke')->once()->andThrow(new RuntimeException($internalDetail));
        $this->app->instance(ListInstitutionUsers::class, $listAction);

        $listResponse = $this->rawList($token);
        $this->assertSafeServerError($listResponse, $internalDetail);
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
        $this->forgetAuthenticationGuards();

        $showAction = Mockery::mock(ShowInstitutionUser::class);
        $showAction->shouldReceive('__invoke')->once()->andThrow(new RuntimeException($internalDetail));
        $this->app->instance(ShowInstitutionUser::class, $showAction);

        $detailResponse = $this->rawDetail($target->id, $token);
        $this->assertSafeServerError($detailResponse, $internalDetail);
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
    }

    public function test_controlled_smoke_covers_list_filters_pagination_detail_and_scope_safe_denial(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $teacher = $this->createUserForRole(UserRole::Teacher, $institution, [
            'full_name' => 'Smoke Teacher',
        ]);
        $student = $this->createUserForRole(UserRole::Student, $institution, [
            'full_name' => 'Smoke Student',
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $foreign = $this->createUserForRole(UserRole::Teacher, $otherInstitution, [
            'full_name' => 'Smoke Foreign Teacher',
        ]);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();

        $default = $this->rawList($token, query: ['per_page' => 1]);
        $default->assertOk();
        $this->assertSame(2, $default->json('meta.pagination.total'));
        $this->assertSame(2, $default->json('meta.pagination.last_page'));
        $this->forgetAuthenticationGuards();

        $filtered = $this->rawList($token, query: [
            'role' => UserRole::Student->value,
            'status' => 'inactive',
            'search' => 'smoke student',
            'sort' => 'created_at',
            'direction' => 'desc',
        ]);
        $this->assertSame([$student->id], $this->idsFromList($filtered));
        $this->forgetAuthenticationGuards();

        $this->rawDetail($teacher->id, $token)
            ->assertOk()
            ->assertJsonPath('data.id', $teacher->id);
        $this->forgetAuthenticationGuards();
        $this->assertErrorContract($this->rawDetail($foreign->id, $token), 404, 'resource_not_found');
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
    }

    private function createUserForRole(
        UserRole $role,
        ?Institution $institution = null,
        array $attributes = [],
    ): User {
        $factory = match ($role) {
            UserRole::PlatformOwner => User::factory()->platformOwner(),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
        };

        return $factory->create(array_merge([
            'must_change_password' => false,
        ], $attributes));
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function authorizedList(User $actor, array $query = []): TestResponse
    {
        return $this->rawList($this->tokenFor($actor), query: $query);
    }

    /**
     * @param  array<string, mixed>  $query
     * @param  array<string, string>  $serverOverrides
     */
    private function rawList(
        ?string $token = null,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
        array $serverOverrides = [],
    ): TestResponse {
        return $this->rawGet(self::INDEX_URI, $token, $content, $query, $contentType, $serverOverrides);
    }

    /**
     * @param  array<string, mixed>  $query
     * @param  array<string, string>  $serverOverrides
     */
    private function rawDetail(
        string $user,
        ?string $token = null,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
        array $serverOverrides = [],
    ): TestResponse {
        return $this->rawGet(self::INDEX_URI.'/'.$user, $token, $content, $query, $contentType, $serverOverrides);
    }

    /**
     * @param  array<string, mixed>  $query
     * @param  array<string, string>  $serverOverrides
     */
    private function rawGet(
        string $baseUri,
        ?string $token,
        string $content,
        array $query,
        string $contentType,
        array $serverOverrides,
    ): TestResponse {
        $uri = $baseUri.($query === [] ? '' : '?'.http_build_query($query));
        $server = array_merge([
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
        ], $serverOverrides);

        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call('GET', $uri, [], [], [], $server, $content);
    }

    private function tokenFor(User $user): string
    {
        return $user->createToken('institution-user-read-api-test')->plainTextToken;
    }

    /**
     * @return list<string>
     */
    private function idsFromList(TestResponse $response): array
    {
        return collect($response->json('data'))->pluck('id')->all();
    }

    private function assertInstitutionUserResource(
        TestResponse $response,
        string $path,
        UserRole $expectedRole,
    ): void {
        $resource = $response->json($path);

        $this->assertSame([
            'id',
            'role',
            'full_name',
            'login_name',
            'email',
            'phone',
            'is_active',
            'must_change_password',
            'last_login_at',
            'deactivated_at',
            'created_at',
            'updated_at',
        ], array_keys($resource));
        $this->assertIsString($resource['id']);
        $this->assertSame($expectedRole->value, $resource['role']);
        $this->assertIsString($resource['full_name']);
        $this->assertIsString($resource['login_name']);
        $this->assertIsBool($resource['is_active']);
        $this->assertIsBool($resource['must_change_password']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['created_at']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['updated_at']);
    }

    /**
     * @param  callable(?string): TestResponse  $request
     */
    private function assertGateWithoutWrites(
        callable $request,
        User $user,
        int $status,
        string $code,
        string $case,
    ): void {
        $token = $this->tokenFor($user);
        $before = $this->protectedRowsSnapshot();

        $this->assertErrorContract($request($token), $status, $code, $case);
        $this->assertSame($before, $this->protectedRowsSnapshot(), $case);
        $this->forgetAuthenticationGuards();
    }

    /**
     * @return array<string, list<array<string, mixed>>>
     */
    private function protectedRowsSnapshot(): array
    {
        return [
            'institutions' => $this->tableRowsSnapshot('institutions'),
            'institution_settings' => $this->tableRowsSnapshot('institution_settings'),
            'users' => $this->tableRowsSnapshot('users'),
            'personal_access_tokens' => $this->tableRowsSnapshot('personal_access_tokens'),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function tableRowsSnapshot(string $table): array
    {
        $orderColumn = $table === 'institution_settings' ? 'institution_id' : 'id';

        return DB::table($table)
            ->orderBy($orderColumn)
            ->get()
            ->map(fn (object $row): array => (array) $row)
            ->values()
            ->all();
    }

    private function assertSafeServerError(TestResponse $response, string $internalDetail): void
    {
        $decoded = $this->assertErrorContract($response, 500, 'server_error');

        $this->assertSame('An unexpected server error occurred.', $decoded->message);
        $content = $response->getContent();
        $this->assertStringNotContainsString($internalDetail, $content);
        $this->assertStringNotContainsString('SQLSTATE', $content);
        $this->assertStringNotContainsString('controlled failure', $content);
        $this->assertStringNotContainsString('trace', $content);
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    private function assertErrorContract(
        TestResponse $response,
        int $status,
        string $code,
        string $case = '',
    ): object {
        $response->assertStatus($status);
        $response->assertHeader('content-type', 'application/json');

        $decoded = json_decode($response->getContent());

        $this->assertIsObject($decoded, $case);
        $this->assertObjectHasProperty('message', $decoded, $case);
        $this->assertIsString($decoded->message, $case);
        $this->assertObjectHasProperty('code', $decoded, $case);
        $this->assertSame($code, $decoded->code, $case);
        $this->assertObjectHasProperty('errors', $decoded, $case);
        $this->assertIsObject($decoded->errors, $case);

        return $decoded;
    }
}
