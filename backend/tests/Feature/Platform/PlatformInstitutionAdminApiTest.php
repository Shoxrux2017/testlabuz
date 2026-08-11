<?php

namespace Tests\Feature\Platform;

use App\Actions\Platform\CreatePlatformInstitutionAdmin;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class PlatformInstitutionAdminApiTest extends TestCase
{
    use RefreshDatabase;

    private const INITIAL_PASSWORD = 'Initial admin password 93!';

    private const NEW_PASSWORD = 'Changed admin password 51!';

    public function test_admin_routes_are_registered_once_with_required_middleware_order_and_no_later_routes(): void
    {
        $adminRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/platform/institutions/{institution}/admins')
            ->values()
            ->all();

        $expectedMiddleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:platform_owner'];

        $this->assertSame([
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/platform/institutions/{institution}/admins',
                'middleware' => $expectedMiddleware,
            ],
            [
                'methods' => ['POST'],
                'uri' => 'api/v1/platform/institutions/{institution}/admins',
                'middleware' => $expectedMiddleware,
            ],
        ], $adminRoutes);

        $laterTaskRoutes = collect(Route::getRoutes())
            ->map(fn ($route): string => $route->uri())
            ->filter(fn (string $uri): bool => str_starts_with($uri, 'api/v1/platform/institution-admins/'))
            ->values()
            ->all();

        $this->assertSame([], $laterTaskRoutes);
    }

    public function test_authentication_account_institution_password_role_and_not_found_precedence_for_both_routes(): void
    {
        $institution = Institution::factory()->create();
        $initialUserCount = User::query()->count();

        foreach ([
            'list' => fn (): TestResponse => $this->getJson($this->adminIndexUri($institution)),
            'create' => fn (): TestResponse => $this->postJson($this->adminIndexUri($institution), $this->validPayload()),
        ] as $case => $request) {
            $this->assertErrorContract($request(), 401, 'authentication_required', $case.' unauthenticated');
            $this->assertSame($initialUserCount, User::query()->count(), $case.' unauthenticated count');
        }

        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        foreach ($this->adminRequestsFor($inactivePlatformOwner, $institution) as $case => $request) {
            $before = User::query()->count();
            $this->assertErrorContract($request(), 403, 'user_inactive', $case);
            $this->assertSame($before, User::query()->count(), $case.' count');
            $this->forgetAuthenticationGuards();
        }

        $passwordIncompletePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'must_change_password' => true,
        ]);
        foreach ($this->adminRequestsFor($passwordIncompletePlatformOwner, $institution) as $case => $request) {
            $before = User::query()->count();
            $this->assertErrorContract($request(), 403, 'password_change_required', $case);
            $this->assertSame($before, User::query()->count(), $case.' count');
            $this->forgetAuthenticationGuards();
        }

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole($role);

            foreach ($this->adminRequestsFor($wrongRoleUser, $institution) as $case => $request) {
                $before = User::query()->count();
                $this->assertErrorContract($request(), 403, 'forbidden', $role->value.' '.$case);
                $this->assertSame($before, User::query()->count(), $role->value.' '.$case.' count');
                $this->forgetAuthenticationGuards();
            }
        }

        $inactiveActorInstitution = Institution::factory()->inactive()->create();
        $wrongRoleFromInactiveInstitution = $this->createUserForRole(UserRole::Teacher, $inactiveActorInstitution);
        foreach ($this->adminRequestsFor($wrongRoleFromInactiveInstitution, $institution) as $case => $request) {
            $before = User::query()->count();
            $this->assertErrorContract($request(), 403, 'institution_inactive', $case);
            $this->assertSame($before, User::query()->count(), $case.' count');
            $this->forgetAuthenticationGuards();
        }

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $this->authorizedRawIndex($this->tokenFor($platformOwner), $institution, '')->assertOk();
        $this->forgetAuthenticationGuards();
        $this->withToken($this->tokenFor($platformOwner))->postJson($this->adminIndexUri($institution), $this->validPayload([
            'login_name' => 'authorized_admin_create',
        ]))->assertCreated();
        $this->forgetAuthenticationGuards();

        foreach (['not-a-uuid', Str::uuid()->toString()] as $institutionId) {
            foreach ([
                'list' => fn (): TestResponse => $this->authorizedRawIndexUri($this->tokenFor($platformOwner), '/api/v1/platform/institutions/'.$institutionId.'/admins', ''),
                'create' => fn (): TestResponse => $this->withToken($this->tokenFor($platformOwner))->postJson('/api/v1/platform/institutions/'.$institutionId.'/admins', $this->validPayload([
                    'login_name' => 'not_found_'.Str::lower(Str::random(8)),
                ])),
            ] as $case => $request) {
                $before = User::query()->count();
                $this->assertErrorContract($request(), 404, 'resource_not_found', $institutionId.' '.$case);
                $this->assertSame($before, User::query()->count(), $institutionId.' '.$case.' count');
                $this->forgetAuthenticationGuards();
            }
        }
    }

    public function test_list_scope_default_order_pagination_and_inactive_target_institution_management(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $inactiveInstitution = Institution::factory()->inactive()->create();

        $alphaUpper = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'id' => '00000000-0000-0000-0000-000000000001',
            'full_name' => 'Alpha Admin',
            'login_name' => 'scope_alpha_upper',
            'must_change_password' => true,
        ]);
        $alphaLower = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'id' => '00000000-0000-0000-0000-000000000002',
            'full_name' => 'alpha admin',
            'login_name' => 'scope_alpha_lower',
            'is_active' => false,
            'deactivated_at' => CarbonImmutable::parse('2026-08-07 12:00:00', 'UTC'),
            'must_change_password' => true,
        ]);
        $beta = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'id' => '00000000-0000-0000-0000-000000000003',
            'full_name' => 'Beta Admin',
            'login_name' => 'scope_beta',
            'must_change_password' => true,
        ]);
        $inactiveInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $inactiveInstitution, [
            'full_name' => 'Inactive Institution Admin',
            'login_name' => 'inactive_target_admin',
            'must_change_password' => true,
        ]);

        $this->createUserForRole(UserRole::InstitutionAdmin, $otherInstitution, [
            'full_name' => 'Alpha Admin Other Institution',
            'login_name' => 'other_institution_admin',
        ]);
        foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $this->createUserForRole($role, $role === UserRole::PlatformOwner ? null : $institution, [
                'full_name' => 'Excluded '.$role->value,
                'login_name' => 'excluded_'.Str::lower($role->value),
            ]);
        }

        $response = $this->authorizedIndex($institution);

        $response->assertOk();
        $this->assertSame([$alphaUpper->id, $alphaLower->id, $beta->id], $this->idsFromList($response));
        $this->assertSame([
            'page' => 1,
            'per_page' => 20,
            'total' => 3,
            'last_page' => 1,
        ], $response->json('meta.pagination'));

        $paged = $this->authorizedIndex($institution, [
            'page' => 2,
            'per_page' => 2,
        ]);
        $paged->assertOk();
        $this->assertSame([$beta->id], $this->idsFromList($paged));
        $this->assertSame(2, $paged->json('meta.pagination.page'));
        $this->assertSame(2, $paged->json('meta.pagination.per_page'));

        $beyondLast = $this->authorizedIndex($institution, [
            'page' => 3,
            'per_page' => 2,
        ]);
        $beyondLast->assertOk();
        $this->assertSame([], $beyondLast->json('data'));
        $this->assertSame(3, $beyondLast->json('meta.pagination.page'));
        $this->assertSame(2, $beyondLast->json('meta.pagination.last_page'));

        $inactiveTargetResponse = $this->authorizedIndex($inactiveInstitution);
        $inactiveTargetResponse->assertOk();
        $this->assertSame([$inactiveInstitutionAdmin->id], $this->idsFromList($inactiveTargetResponse));
    }

    public function test_list_search_status_filters_literal_wildcards_empty_search_and_invalid_queries(): void
    {
        $institution = Institution::factory()->create();

        $nameMatch = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Samarkand 100%_Alpha Admin',
            'login_name' => 'name_literal_match',
            'email' => null,
            'phone' => null,
            'must_change_password' => true,
        ]);
        $loginMatch = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Plain Login Admin',
            'login_name' => 'NeedleLoginAdmin',
            'email' => null,
            'phone' => null,
        ]);
        $emailMatch = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Plain Email Admin',
            'login_name' => 'plain_email_admin',
            'email' => 'contact-needle@example.uz',
            'phone' => null,
        ]);
        $phoneMatch = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Plain Phone Admin',
            'login_name' => 'plain_phone_admin',
            'email' => null,
            'phone' => '+998-NEEDLE',
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $literalNonMatch = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Samarkand 100XAlpha Admin',
            'login_name' => 'wildcard_non_match',
        ]);
        $this->createUserForRole(UserRole::Teacher, $institution, [
            'full_name' => 'Samarkand 100%_Alpha Teacher',
            'login_name' => 'teacher_literal_excluded',
        ]);
        $this->createUserForRole(UserRole::InstitutionAdmin, Institution::factory()->create(), [
            'full_name' => 'Samarkand 100%_Alpha Other',
            'login_name' => 'other_literal_excluded',
        ]);

        $literalResponse = $this->authorizedIndex($institution, ['search' => '  100%_alpha  ']);
        $literalResponse->assertOk();
        $this->assertSame([$nameMatch->id], $this->idsFromList($literalResponse));

        $this->assertSame([$loginMatch->id], $this->idsFromList($this->authorizedIndex($institution, [
            'search' => 'needlelogin',
        ])));
        $this->assertSame([$emailMatch->id], $this->idsFromList($this->authorizedIndex($institution, [
            'search' => 'CONTACT-NEEDLE',
        ])));
        $this->assertSame([$phoneMatch->id], $this->idsFromList($this->authorizedIndex($institution, [
            'search' => 'needle',
            'status' => 'inactive',
        ])));

        $emptySearchResponse = $this->authorizedIndex($institution, ['search' => '   ']);
        $emptySearchResponse->assertOk();
        $emptySearchIds = $this->idsFromList($emptySearchResponse);
        sort($emptySearchIds);
        $expectedIds = [$nameMatch->id, $loginMatch->id, $emailMatch->id, $phoneMatch->id, $literalNonMatch->id];
        sort($expectedIds);
        $this->assertSame($expectedIds, $emptySearchIds);

        $this->assertSame([
            $nameMatch->id,
            $loginMatch->id,
            $emailMatch->id,
            $literalNonMatch->id,
        ], $this->idsFromList($this->authorizedIndex($institution, [
            'status' => 'active',
            'sort' => 'login_name',
            'direction' => 'asc',
        ])));

        $invalidCases = [
            'invalid status' => [['status' => 'suspended'], 'status'],
            'page below minimum' => [['page' => 0], 'page'],
            'page non integer' => [['page' => 'one'], 'page'],
            'per page below minimum' => [['per_page' => 0], 'per_page'],
            'per page above max' => [['per_page' => 101], 'per_page'],
            'per page non integer' => [['per_page' => 'many'], 'per_page'],
            'unknown sort' => [['sort' => 'role'], 'sort'],
            'unknown direction' => [['direction' => 'sideways'], 'direction'],
            'oversized search' => [['search' => str_repeat('a', 255)], 'search'],
            'unknown institution id key' => [['institution_id' => Str::uuid()->toString()], 'institution_id'],
            'unknown role key' => [['role' => UserRole::InstitutionAdmin->value], 'role'],
            'unknown password flag key' => [['must_change_password' => true], 'must_change_password'],
            'unknown include key' => [['include' => 'institution'], 'include'],
            'unknown raw column key' => [['order_by' => 'lower(full_name)'], 'order_by'],
        ];

        foreach ($invalidCases as $case => [$query, $expectedField]) {
            $decoded = $this->assertErrorContract(
                $this->authorizedIndex($institution, $query),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($expectedField, $decoded->errors, $case);
        }
    }

    public function test_list_sorting_is_case_insensitive_for_text_and_uses_directional_id_tie_breaks(): void
    {
        $institution = Institution::factory()->create();
        $firstId = '00000000-0000-0000-0000-000000000001';
        $secondId = '00000000-0000-0000-0000-000000000002';
        $thirdId = '00000000-0000-0000-0000-000000000003';

        $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'id' => $thirdId,
            'full_name' => 'Beta Admin',
            'login_name' => 'zeta_login',
            'created_at' => CarbonImmutable::parse('2026-01-03 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-04 00:00:00', 'UTC'),
        ]);
        $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'id' => $secondId,
            'full_name' => 'alpha admin',
            'login_name' => 'tie_login',
            'created_at' => CarbonImmutable::parse('2026-01-01 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-02 00:00:00', 'UTC'),
        ]);
        $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'id' => $firstId,
            'full_name' => 'Alpha Admin',
            'login_name' => 'Tie_Login',
            'created_at' => CarbonImmutable::parse('2026-01-01 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-02 00:00:00', 'UTC'),
        ]);

        $ascendingWithTieBreaker = [$firstId, $secondId, $thirdId];
        $descendingWithTieBreaker = [$thirdId, $secondId, $firstId];

        foreach (['full_name', 'login_name', 'created_at', 'updated_at'] as $sort) {
            $this->assertSame($ascendingWithTieBreaker, $this->idsFromList($this->authorizedIndex($institution, [
                'sort' => $sort,
                'direction' => 'asc',
            ])), $sort.' asc');

            $this->assertSame($descendingWithTieBreaker, $this->idsFromList($this->authorizedIndex($institution, [
                'sort' => $sort,
                'direction' => 'desc',
            ])), $sort.' desc');
        }

        $this->assertSame($ascendingWithTieBreaker, $this->idsFromList($this->authorizedIndex($institution)));
    }

    public function test_list_accepts_only_query_parameters_and_rejects_every_non_empty_get_body_without_mutations(): void
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
        ]);

        $queryAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Query Source Admin',
            'login_name' => 'query_source_admin',
            'is_active' => true,
            'must_change_password' => true,
        ]);
        $bodyOnlyAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Body Only Admin',
            'login_name' => 'body_only_admin',
            'is_active' => false,
            'deactivated_at' => now(),
            'must_change_password' => true,
        ]);

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $token = $this->tokenFor($platformOwner);

        $institutionsBefore = $this->institutionRowsSnapshot();
        $settingsBefore = $this->institutionSettingRowsSnapshot();
        $usersBefore = $this->userRowsSnapshot();
        $tokenRowsBefore = $this->tokenRowsSnapshot();

        $emptyBodyResponse = $this->authorizedRawIndex($token, $institution, '', [
            'search' => 'Query Source',
            'status' => 'active',
            'sort' => 'login_name',
            'direction' => 'asc',
            'page' => 1,
            'per_page' => 10,
        ]);

        $emptyBodyResponse->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($emptyBodyResponse->json()));
        $this->assertSame([$queryAdmin->id], $this->idsFromList($emptyBodyResponse));
        $this->assertSame([
            'page' => 1,
            'per_page' => 10,
            'total' => 1,
            'last_page' => 1,
        ], $emptyBodyResponse->json('meta.pagination'));
        $this->assertStringNotContainsString($bodyOnlyAdmin->id, $emptyBodyResponse->getContent());
        $this->assertReadOnlyPlatformRowsUnchanged($institutionsBefore, $settingsBefore, $usersBefore, $tokenRowsBefore, 'empty body success');

        $bodyCases = [
            'json allowed list parameter' => ['{"search":"Body Only"}', [], 'application/json'],
            'conflicting query and json body' => ['{"search":"Body Only","status":"inactive"}', ['search' => 'Query Source', 'status' => 'active'], 'application/json'],
            'empty json object' => ['{}', [], 'application/json'],
            'json array' => ['["search","Body Only"]', [], 'application/json'],
            'json scalar' => ['"Body Only"', [], 'application/json'],
            'malformed json' => ['{"search":"Body Only"', [], 'application/json'],
            'raw body bytes' => ['Body Only raw bytes', [], 'text/plain'],
            'form encoded body' => ['search=Body+Only&status=inactive', [], 'application/x-www-form-urlencoded'],
            'whitespace only body' => [" \t\r\n", [], 'text/plain'],
        ];

        foreach ($bodyCases as $case => [$content, $query, $contentType]) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRawIndex($token, $institution, $content, $query, $contentType),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertReadOnlyPlatformRowsUnchanged($institutionsBefore, $settingsBefore, $usersBefore, $tokenRowsBefore, $case);
        }

        $unknownQuery = $this->assertErrorContract(
            $this->authorizedRawIndex($token, $institution, '', ['role' => UserRole::InstitutionAdmin->value]),
            422,
            'validation_failed',
            'unknown query key',
        );
        $this->assertObjectHasProperty('role', $unknownQuery->errors, 'unknown query key');
        $this->assertReadOnlyPlatformRowsUnchanged($institutionsBefore, $settingsBefore, $usersBefore, $tokenRowsBefore, 'unknown query key');
    }

    public function test_list_resource_envelope_leakage_exclusions_and_query_behavior_are_bounded_and_read_only(): void
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'timezone' => 'Sensitive/Timezone',
        ]);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $token = $this->tokenFor($platformOwner);

        $admin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'full_name' => 'Contract Admin',
            'login_name' => 'contract_admin',
            'email' => null,
            'phone' => null,
            'is_active' => false,
            'must_change_password' => true,
            'last_login_at' => CarbonImmutable::parse('2026-08-07 10:00:00', 'UTC'),
            'deactivated_at' => CarbonImmutable::parse('2026-08-07 11:00:00', 'UTC'),
            'created_at' => CarbonImmutable::parse('2026-08-07 08:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 09:00:00', 'UTC'),
        ]);
        foreach (range(1, 5) as $number) {
            $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
                'full_name' => 'Bounded Admin '.$number,
                'login_name' => 'bounded_admin_'.$number,
            ]);
        }

        $institutionBefore = $institution->refresh()->getRawOriginal();
        $usersBefore = $this->userRowsSnapshot();
        $tokenRowsBefore = $this->tokenRowsSnapshot();

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $response = $this->authorizedRawIndex($token, $institution, '', [
                'search' => 'Contract Admin',
            ]);
            $queries = collect(DB::getQueryLog())->pluck('query')->map(fn (string $query): string => strtolower($query));
        } finally {
            DB::disableQueryLog();
        }

        $response->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertSame([
            'id',
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
        ], array_keys($response->json('data.0')));
        $this->assertSame($admin->id, $response->json('data.0.id'));
        $this->assertFalse($response->json('data.0.is_active'));
        $this->assertTrue($response->json('data.0.must_change_password'));
        $this->assertNull($response->json('data.0.email'));
        $this->assertNull($response->json('data.0.phone'));
        $this->assertSame('2026-08-07T10:00:00Z', $response->json('data.0.last_login_at'));
        $this->assertSame('2026-08-07T11:00:00Z', $response->json('data.0.deactivated_at'));
        $this->assertSame('2026-08-07T08:00:00Z', $response->json('data.0.created_at'));
        $this->assertSame('2026-08-07T09:00:00Z', $response->json('data.0.updated_at'));

        $content = $response->getContent();
        foreach ([
            'institution_id',
            'role',
            'created_by_user_id',
            'creator',
            'remember_token',
            'token',
            'Sensitive/Timezone',
            'institution_settings',
            'user_counts',
            'links',
            'message',
        ] as $forbiddenText) {
            $this->assertStringNotContainsString($forbiddenText, $content, $forbiddenText);
        }
        $this->assertArrayNotHasKey('password', $response->json('data.0'));

        $userQueries = $queries->filter(fn (string $query): bool => str_contains($query, 'from "users"'))->values();
        $this->assertLessThanOrEqual(3, $userQueries->count());
        $this->assertTrue($queries->contains(fn (string $query): bool => str_contains($query, 'order by lower(full_name) asc, "id" asc')));
        $this->assertFalse($queries->contains(fn (string $query): bool => str_contains($query, 'from "personal_access_tokens" where "personal_access_tokens"."tokenable_id"')));

        $this->assertSame($institutionBefore, $institution->refresh()->getRawOriginal());
        $this->assertSame($usersBefore, $this->userRowsSnapshot());
        $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot());
    }

    public function test_create_success_persists_server_owned_fields_allows_duplicate_contacts_and_multiple_admins_without_side_effects(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 10:00:00', 'UTC'));

        try {
            $institution = Institution::factory()->create();
            InstitutionSetting::factory()->create([
                'institution_id' => $institution->id,
                'timezone' => 'Asia/Tashkent',
            ]);
            $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
            $platformOwnerToken = $this->tokenFor($platformOwner);
            $institutionBefore = $institution->refresh()->getRawOriginal();
            $settingsBefore = InstitutionSetting::query()->orderBy('institution_id')->get()->map->getRawOriginal()->all();
            $tokenRowsBefore = $this->tokenRowsSnapshot();

            $response = $this->withToken($platformOwnerToken)
                ->postJson($this->adminIndexUri($institution), $this->validPayload([
                    'full_name' => '  Institution Admin  ',
                    'login_name' => '  admin.school1  ',
                    'email' => 'shared@example.uz',
                    'phone' => '+998901234567',
                ]));

            $response->assertCreated();
            $this->assertSame(['data', 'message'], array_keys($response->json()));
            $this->assertSame('Institution admin created successfully.', $response->json('message'));
            $this->assertSame([
                'id',
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
            ], array_keys($response->json('data')));
            $this->assertTrue(Str::isUuid($response->json('data.id')));
            $this->assertSame('Institution Admin', $response->json('data.full_name'));
            $this->assertSame('admin.school1', $response->json('data.login_name'));
            $this->assertSame('shared@example.uz', $response->json('data.email'));
            $this->assertSame('+998901234567', $response->json('data.phone'));
            $this->assertTrue($response->json('data.is_active'));
            $this->assertTrue($response->json('data.must_change_password'));
            $this->assertNull($response->json('data.last_login_at'));
            $this->assertNull($response->json('data.deactivated_at'));
            $this->assertSame('2026-08-10T10:00:00Z', $response->json('data.created_at'));
            $this->assertSame('2026-08-10T10:00:00Z', $response->json('data.updated_at'));

            $admin = User::query()->findOrFail($response->json('data.id'));
            $this->assertSame($institution->id, $admin->institution_id);
            $this->assertSame(UserRole::InstitutionAdmin, $admin->role);
            $this->assertSame($platformOwner->id, $admin->created_by_user_id);
            $this->assertTrue($admin->is_active);
            $this->assertTrue($admin->must_change_password);
            $this->assertNull($admin->last_login_at);
            $this->assertNull($admin->deactivated_at);
            $this->assertNotSame(self::INITIAL_PASSWORD, $admin->password);
            $this->assertTrue(Hash::check(self::INITIAL_PASSWORD, $admin->password));

            $content = $response->getContent();
            foreach ([
                self::INITIAL_PASSWORD,
                $admin->password,
                'institution_id',
                'role',
                'created_by_user_id',
                'password_hash',
                'remember_token',
                'token',
                'meta',
            ] as $forbiddenText) {
                $this->assertStringNotContainsString($forbiddenText, $content, $forbiddenText);
            }

            $second = $this->withToken($platformOwnerToken)
                ->postJson($this->adminIndexUri($institution), $this->validPayload([
                    'full_name' => 'Second Institution Admin',
                    'login_name' => 'admin.school2',
                    'email' => 'shared@example.uz',
                    'phone' => '+998901234567',
                ]));
            $second->assertCreated();
            $this->assertSame(2, User::query()
                ->where('institution_id', $institution->id)
                ->where('role', UserRole::InstitutionAdmin->value)
                ->where('email', 'shared@example.uz')
                ->where('phone', '+998901234567')
                ->count());

            $nullableContacts = $this->withToken($platformOwnerToken)
                ->postJson($this->adminIndexUri($institution), $this->validPayload([
                    'full_name' => 'Nullable Contacts Admin',
                    'login_name' => 'admin.school3',
                    'email' => null,
                    'phone' => null,
                ]));
            $nullableContacts->assertCreated();
            $nullableContacts->assertJsonPath('data.email', null);
            $nullableContacts->assertJsonPath('data.phone', null);

            $this->assertSame($institutionBefore, $institution->refresh()->getRawOriginal());
            $this->assertSame($settingsBefore, InstitutionSetting::query()->orderBy('institution_id')->get()->map->getRawOriginal()->all());
            $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot());
            $this->assertSame(3, User::query()->where('institution_id', $institution->id)->where('role', UserRole::InstitutionAdmin->value)->count());
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_create_validation_rejects_unknown_protected_invalid_and_duplicate_login_fields_without_writes(): void
    {
        $institution = Institution::factory()->create();
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $cases = [
            'missing full name' => [array_diff_key($this->validPayload(), ['full_name' => true]), 'full_name'],
            'missing login name' => [array_diff_key($this->validPayload(), ['login_name' => true]), 'login_name'],
            'missing password' => [array_diff_key($this->validPayload(), ['password' => true]), 'password'],
            'blank full name' => [$this->validPayload(['full_name' => '   ']), 'full_name'],
            'blank login name' => [$this->validPayload(['login_name' => '   ']), 'login_name'],
            'long full name' => [$this->validPayload(['full_name' => str_repeat('A', 201)]), 'full_name'],
            'long login name' => [$this->validPayload(['login_name' => str_repeat('a', 192)]), 'login_name'],
            'invalid email' => [$this->validPayload(['email' => 'not an email']), 'email'],
            'long email' => [$this->validPayload(['email' => str_repeat('a', 245).'@example.uz']), 'email'],
            'blank phone' => [$this->validPayload(['phone' => '   ']), 'phone'],
            'long phone' => [$this->validPayload(['phone' => str_repeat('9', 51)]), 'phone'],
            'short password' => [$this->validPayload(['password' => 'short']), 'password'],
            'long password' => [$this->validPayload(['password' => str_repeat('p', 256)]), 'password'],
            'full name array' => [$this->validPayload(['full_name' => ['Admin']]), 'full_name'],
            'phone bool' => [$this->validPayload(['phone' => false]), 'phone'],
        ];

        foreach ($cases as $case => [$payload, $expectedField]) {
            $before = User::query()->count();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $institution, $payload),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($expectedField, $decoded->errors, $case);
            $this->assertSame($before, User::query()->count(), $case);
        }

        foreach ([
            'id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'role' => UserRole::Teacher->value,
            'is_active' => false,
            'must_change_password' => false,
            'last_login_at' => '2026-08-10T10:00:00Z',
            'deactivated_at' => '2026-08-10T10:00:00Z',
            'created_by_user_id' => $platformOwner->id,
            'created_at' => '2026-08-10T10:00:00Z',
            'updated_at' => '2026-08-10T10:00:00Z',
            'password_confirmation' => self::INITIAL_PASSWORD,
            'permissions' => ['*'],
        ] as $field => $value) {
            $before = User::query()->count();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $institution, array_merge($this->validPayload([
                    'login_name' => 'protected_'.$field,
                ]), [
                    $field => $value,
                ])),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertSame($before, User::query()->count(), $field);
        }

        foreach (['institution_id', 'role', 'password', 'include'] as $queryKey) {
            $before = User::query()->count();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $institution, $this->validPayload([
                    'login_name' => 'query_'.$queryKey,
                ]), $this->adminIndexUri($institution).'?'.http_build_query([$queryKey => 'override'])),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($before, User::query()->count(), $queryKey);
        }

        $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'login_name' => 'duplicate_same_institution',
        ]);
        $this->createUserForRole(UserRole::InstitutionAdmin, Institution::factory()->create(), [
            'login_name' => 'duplicate_other_institution',
        ]);

        foreach (['duplicate_same_institution', 'duplicate_other_institution'] as $loginName) {
            $before = User::query()->count();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $institution, $this->validPayload([
                    'login_name' => $loginName,
                ])),
                422,
                'validation_failed',
                $loginName,
            );
            $this->assertObjectHasProperty('login_name', $decoded->errors);
            $this->assertSame($before, User::query()->count(), $loginName);
        }

        foreach (['[]', '"scalar"', ''] as $body) {
            $before = User::query()->count();
            $decoded = $this->assertErrorContract(
                $this->authorizedRawJsonPost($platformOwner, $institution, $body),
                422,
                'validation_failed',
                'body '.$body,
            );
            $this->assertObjectHasProperty('body', $decoded->errors);
            $this->assertSame($before, User::query()->count(), 'body '.$body);
        }
    }

    public function test_duplicate_login_race_maps_database_loser_to_validation_without_leakage_and_different_logins_succeed(): void
    {
        $institution = Institution::factory()->create();
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $firstDifferent = $this->authorizedPost($platformOwner, $institution, $this->validPayload([
            'login_name' => 'different_login_one',
        ]));
        $secondDifferent = $this->authorizedPost($platformOwner, $institution, $this->validPayload([
            'login_name' => 'different_login_two',
        ]));
        $firstDifferent->assertCreated();
        $secondDifferent->assertCreated();

        $this->app->instance(CreatePlatformInstitutionAdmin::class, new class extends CreatePlatformInstitutionAdmin
        {
            public function __invoke(
                User $actor,
                Institution $institution,
                string $fullName,
                string $loginName,
                ?string $email,
                ?string $phone,
                string $password,
            ): User {
                User::query()->create([
                    'institution_id' => $institution->getKey(),
                    'role' => UserRole::InstitutionAdmin,
                    'full_name' => 'Concurrent Winning Admin',
                    'login_name' => $loginName,
                    'email' => $email,
                    'phone' => $phone,
                    'password' => Hash::make($password),
                    'is_active' => true,
                    'must_change_password' => true,
                    'last_login_at' => null,
                    'deactivated_at' => null,
                    'created_by_user_id' => $actor->getKey(),
                ]);

                return parent::__invoke($actor, $institution, $fullName, $loginName, $email, $phone, $password);
            }
        });

        $raceLogin = 'race_login_name';
        $response = $this->authorizedPost($platformOwner, $institution, $this->validPayload([
            'login_name' => $raceLogin,
        ]));

        $decoded = $this->assertErrorContract($response, 422, 'validation_failed', 'race loser');
        $this->assertObjectHasProperty('login_name', $decoded->errors);
        $this->assertSame(1, User::query()->where('login_name', $raceLogin)->count());

        $content = $response->getContent();
        $this->assertStringNotContainsString('SQLSTATE', $content);
        $this->assertStringNotContainsString('users_login_name_unique', $content);
        $this->assertStringNotContainsString('duplicate key', $content);
        $this->assertStringNotContainsString(self::INITIAL_PASSWORD, $content);
    }

    public function test_created_admin_first_login_password_gate_change_flow_and_inactive_gates_remain_accepted(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'timezone' => 'Asia/Tashkent',
        ]);

        $createResponse = $this->authorizedPost($platformOwner, $institution, $this->validPayload([
            'full_name' => 'First Login Admin',
            'login_name' => 'first_login_admin',
        ]));
        $createResponse->assertCreated();
        $this->forgetAuthenticationGuards();

        $loginResponse = $this->postJson('/api/v1/auth/login', [
            'login' => 'first_login_admin',
            'password' => self::INITIAL_PASSWORD,
        ]);
        $loginResponse->assertOk();
        $this->assertTrue($loginResponse->json('data.user.must_change_password'));
        $this->assertSame(UserRole::InstitutionAdmin->value, $loginResponse->json('data.user.role'));
        $token = (string) $loginResponse->json('data.token');
        $this->forgetAuthenticationGuards();

        $this->withToken($token)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.must_change_password', true);
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($token)->getJson('/api/v1/platform/dashboard'),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $this->withToken($token)
            ->postJson('/api/v1/auth/change-password', [
                'current_password' => self::INITIAL_PASSWORD,
                'new_password' => self::NEW_PASSWORD,
                'new_password_confirmation' => self::NEW_PASSWORD,
            ])
            ->assertNoContent();
        $this->forgetAuthenticationGuards();

        $admin = User::query()->where('login_name', 'first_login_admin')->firstOrFail();
        $this->assertFalse($admin->must_change_password);
        $this->assertTrue(Hash::check(self::NEW_PASSWORD, $admin->password));
        $this->assertFalse(Hash::check(self::INITIAL_PASSWORD, $admin->password));

        $this->assertErrorContract(
            $this->withToken($token)->getJson('/api/v1/platform/dashboard'),
            403,
            'forbidden',
        );
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => 'first_login_admin',
            'password' => self::INITIAL_PASSWORD,
        ]), 401, 'invalid_credentials');

        $this->postJson('/api/v1/auth/login', [
            'login' => 'first_login_admin',
            'password' => self::NEW_PASSWORD,
        ])
            ->assertOk()
            ->assertJsonPath('data.user.must_change_password', false);

        $admin->forceFill([
            'is_active' => false,
            'deactivated_at' => now(),
        ])->save();
        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => 'first_login_admin',
            'password' => self::NEW_PASSWORD,
        ]), 403, 'user_inactive');
        $this->forgetAuthenticationGuards();

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $inactiveCreateResponse = $this->authorizedPost($platformOwner, $inactiveInstitution, $this->validPayload([
            'full_name' => 'Inactive Institution Admin',
            'login_name' => 'inactive_institution_admin',
        ]));
        $inactiveCreateResponse->assertCreated();

        $this->authorizedIndex($inactiveInstitution)
            ->assertOk()
            ->assertJsonPath('data.0.login_name', 'inactive_institution_admin');

        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => 'inactive_institution_admin',
            'password' => self::INITIAL_PASSWORD,
        ]), 403, 'institution_inactive');
    }

    public function test_controlled_manual_smoke_flow_covers_list_create_duplicate_first_login_and_inactive_institution(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $activeInstitution = Institution::factory()->create(['name' => 'Smoke Active Institution']);
        $inactiveInstitution = Institution::factory()->inactive()->create(['name' => 'Smoke Inactive Institution']);

        $activeAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $activeInstitution, [
            'full_name' => 'Smoke Existing Admin',
            'login_name' => 'smoke_existing_admin',
            'email' => 'smoke-existing@example.uz',
            'phone' => '+998900000001',
        ]);
        $this->createUserForRole(UserRole::Teacher, $activeInstitution, [
            'full_name' => 'Smoke Teacher Excluded',
            'login_name' => 'smoke_teacher_excluded',
        ]);
        $this->createUserForRole(UserRole::InstitutionAdmin, $inactiveInstitution, [
            'full_name' => 'Smoke Inactive Existing Admin',
            'login_name' => 'smoke_inactive_existing',
        ]);

        $list = $this->authorizedIndex($activeInstitution, [
            'search' => 'existing',
            'sort' => 'full_name',
            'direction' => 'asc',
        ]);
        $list->assertOk();
        $this->assertSame([$activeAdmin->id], $this->idsFromList($list));

        $create = $this->authorizedPost($platformOwner, $activeInstitution, $this->validPayload([
            'full_name' => 'Smoke Created Admin',
            'login_name' => 'smoke_created_admin',
            'email' => null,
            'phone' => null,
        ]));
        $create->assertCreated();
        $create->assertJsonPath('message', 'Institution admin created successfully.');

        $duplicate = $this->authorizedPost($platformOwner, $activeInstitution, $this->validPayload([
            'full_name' => 'Smoke Duplicate Admin',
            'login_name' => 'smoke_created_admin',
        ]));
        $this->assertErrorContract($duplicate, 422, 'validation_failed', 'smoke duplicate');
        $this->assertSame(1, User::query()->where('login_name', 'smoke_created_admin')->count());
        $this->forgetAuthenticationGuards();

        $login = $this->postJson('/api/v1/auth/login', [
            'login' => 'smoke_created_admin',
            'password' => self::INITIAL_PASSWORD,
        ]);
        $login->assertOk();
        $this->assertTrue($login->json('data.user.must_change_password'));
        $token = (string) $login->json('data.token');
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($token)->getJson('/api/v1/platform/dashboard'),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $this->withToken($token)
            ->postJson('/api/v1/auth/change-password', [
                'current_password' => self::INITIAL_PASSWORD,
                'new_password' => self::NEW_PASSWORD,
                'new_password_confirmation' => self::NEW_PASSWORD,
            ])
            ->assertNoContent();
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($token)->getJson('/api/v1/platform/dashboard'),
            403,
            'forbidden',
        );
        $this->forgetAuthenticationGuards();

        $inactiveCreate = $this->authorizedPost($platformOwner, $inactiveInstitution, $this->validPayload([
            'full_name' => 'Smoke Created Inactive Institution Admin',
            'login_name' => 'smoke_inactive_created',
        ]));
        $inactiveCreate->assertCreated();
        $this->authorizedIndex($inactiveInstitution, ['search' => 'inactive'])
            ->assertOk()
            ->assertJsonCount(2, 'data');
        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => 'smoke_inactive_created',
            'password' => self::INITIAL_PASSWORD,
        ]), 403, 'institution_inactive');
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'full_name' => 'Institution Admin',
            'login_name' => 'admin_'.Str::lower(Str::random(12)),
            'email' => 'admin@example.uz',
            'phone' => '+998901234567',
            'password' => self::INITIAL_PASSWORD,
        ], $overrides);
    }

    private function adminIndexUri(Institution $institution): string
    {
        return '/api/v1/platform/institutions/'.$institution->id.'/admins';
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function authorizedIndex(Institution $institution, array $query = []): TestResponse
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        return $this->authorizedRawIndex($this->tokenFor($platformOwner), $institution, '', $query);
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function authorizedRawIndex(
        string $token,
        Institution $institution,
        string $content,
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $uri = $this->adminIndexUri($institution).($query === [] ? '' : '?'.http_build_query($query));

        return $this->authorizedRawIndexUri($token, $uri, $content, $contentType);
    }

    private function authorizedRawIndexUri(
        string $token,
        string $uri,
        string $content,
        string $contentType = 'application/json',
    ): TestResponse {
        return $this->call(
            'GET',
            $uri,
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => $contentType,
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            $content,
        );
    }

    private function authorizedPost(
        User $platformOwner,
        Institution $institution,
        array $payload,
        ?string $uri = null,
    ): TestResponse {
        return $this->withToken($this->tokenFor($platformOwner))
            ->postJson($uri ?? $this->adminIndexUri($institution), $payload);
    }

    private function authorizedRawJsonPost(User $platformOwner, Institution $institution, string $content): TestResponse
    {
        return $this->call(
            'POST',
            $this->adminIndexUri($institution),
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$this->tokenFor($platformOwner),
            ],
            $content,
        );
    }

    /**
     * @return array<string, callable(): TestResponse>
     */
    private function adminRequestsFor(User $actor, Institution $institution): array
    {
        return [
            'list' => fn (): TestResponse => $this->authorizedRawIndex($this->tokenFor($actor), $institution, ''),
            'create' => fn (): TestResponse => $this->withToken($this->tokenFor($actor))->postJson($this->adminIndexUri($institution), $this->validPayload([
                'login_name' => 'denied_'.Str::lower(Str::random(10)),
            ])),
        ];
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
     * @param  list<string>  $abilities
     */
    private function tokenFor(User $user, array $abilities = ['*']): string
    {
        return $user->createToken('platform-institution-admin-api-test', $abilities)->plainTextToken;
    }

    /**
     * @return list<string>
     */
    private function idsFromList(TestResponse $response): array
    {
        return array_column($response->json('data'), 'id');
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function userRowsSnapshot(): array
    {
        return User::query()
            ->orderBy('id')
            ->get()
            ->map(fn (User $user): array => $user->getRawOriginal())
            ->values()
            ->all();
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function institutionRowsSnapshot(): array
    {
        return Institution::query()
            ->orderBy('id')
            ->get()
            ->map(fn (Institution $institution): array => $institution->getRawOriginal())
            ->values()
            ->all();
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function institutionSettingRowsSnapshot(): array
    {
        return InstitutionSetting::query()
            ->orderBy('institution_id')
            ->get()
            ->map(fn (InstitutionSetting $setting): array => $setting->getRawOriginal())
            ->values()
            ->all();
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function tokenRowsSnapshot(): array
    {
        return PersonalAccessToken::query()
            ->orderBy('id')
            ->get()
            ->map(fn (PersonalAccessToken $token): array => [
                'id' => $token->id,
                'tokenable_type' => $token->tokenable_type,
                'tokenable_id' => $token->tokenable_id,
                'name' => $token->name,
                'token' => $token->token,
                'abilities' => $token->abilities,
                'last_used_at' => $token->last_used_at?->toJSON(),
                'created_at' => $token->created_at?->toJSON(),
                'updated_at' => $token->updated_at?->toJSON(),
                'expires_at' => $token->expires_at?->toJSON(),
            ])
            ->values()
            ->all();
    }

    /**
     * @param  list<array<string, mixed>>  $institutionsBefore
     * @param  list<array<string, mixed>>  $settingsBefore
     * @param  list<array<string, mixed>>  $usersBefore
     * @param  list<array<string, mixed>>  $tokenRowsBefore
     */
    private function assertReadOnlyPlatformRowsUnchanged(
        array $institutionsBefore,
        array $settingsBefore,
        array $usersBefore,
        array $tokenRowsBefore,
        string $case,
    ): void {
        $this->assertSame($institutionsBefore, $this->institutionRowsSnapshot(), $case.' institutions');
        $this->assertSame($settingsBefore, $this->institutionSettingRowsSnapshot(), $case.' settings');
        $this->assertSame($usersBefore, $this->userRowsSnapshot(), $case.' users');
        $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot(), $case.' tokens');
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
