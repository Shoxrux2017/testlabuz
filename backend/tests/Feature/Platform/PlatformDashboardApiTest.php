<?php

namespace Tests\Feature\Platform;

use App\Actions\Platform\ShowPlatformDashboard;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\UserRole;
use App\Http\Resources\Platform\PlatformDashboardResource;
use App\Models\Institution;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\PersonalAccessToken;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class PlatformDashboardApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/platform/dashboard';

    public function test_dashboard_route_is_registered_once_with_required_middleware_order(): void
    {
        $dashboardRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/platform/dashboard')
            ->filter(fn (array $route): bool => in_array('GET', $route['methods'], true))
            ->values()
            ->all();

        $this->assertSame([
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/platform/dashboard',
                'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:platform_owner'],
            ],
        ], $dashboardRoutes);
    }

    public function test_authentication_account_password_institution_and_role_gates_protect_dashboard(): void
    {
        $this->assertErrorContract($this->getJson(self::URI), 401, 'authentication_required');
        $this->assertErrorContract($this->withToken('invalid-token')->getJson(self::URI), 401, 'authentication_required');
        $this->forgetAuthenticationGuards();

        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertErrorContract(
            $this->authorizedGet($inactivePlatformOwner),
            403,
            'user_inactive',
        );
        $this->forgetAuthenticationGuards();

        $passwordIncompletePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'must_change_password' => true,
        ]);
        $this->assertErrorContract(
            $this->authorizedGet($passwordIncompletePlatformOwner),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole($role);

            $this->assertErrorContract(
                $this->authorizedGet($wrongRoleUser),
                403,
                'forbidden',
                $role->value,
            );
            $this->forgetAuthenticationGuards();
        }

        $inactiveActorInstitution = Institution::factory()->inactive()->create();
        $wrongRoleFromInactiveInstitution = $this->createUserForRole(UserRole::Teacher, $inactiveActorInstitution);
        $this->assertErrorContract(
            $this->authorizedGet($wrongRoleFromInactiveInstitution),
            403,
            'institution_inactive',
        );
        $this->forgetAuthenticationGuards();

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $this->authorizedGet($platformOwner)
            ->assertOk()
            ->assertJsonPath('data.users.total', User::query()->count());
    }

    public function test_dashboard_rejects_every_query_key_with_field_errors_and_no_mutation(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $token = $this->tokenFor($platformOwner);
        $institution = Institution::factory()->create([
            'name' => 'Query Rejection School',
            'created_at' => CarbonImmutable::parse('2026-08-01 10:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-01 10:00:00', 'UTC'),
        ]);
        $user = $this->createUserForRole(UserRole::Teacher, $institution, [
            'last_login_at' => CarbonImmutable::parse('2026-08-02 10:00:00', 'UTC'),
        ]);

        $institutionBefore = $institution->refresh()->getRawOriginal();
        $userBefore = $user->refresh()->getRawOriginal();
        $tokenRowsBefore = $this->tokenRowsSnapshot();

        foreach ([
            'institution_id' => Str::uuid()->toString(),
            'status' => InstitutionStatus::Active->value,
            'type' => InstitutionType::School->value,
            'role' => UserRole::PlatformOwner->value,
            'from' => '2026-08-01T00:00:00Z',
            'to' => '2026-08-02T00:00:00Z',
            'period' => 'week',
            'limit' => 100,
            'page' => 1,
            'per_page' => 5,
            'include' => 'users',
            'sort' => 'created_at',
        ] as $field => $value) {
            $decoded = $this->assertErrorContract(
                $this->withToken($token)->getJson(self::URI.'?'.http_build_query([$field => $value])),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertStringNotContainsString((string) $value, json_encode($decoded->errors), $field);
            $this->forgetAuthenticationGuards();
        }

        $decoded = $this->assertErrorContract(
            $this->withToken($token)->getJson(self::URI.'?'.http_build_query([
                'institution_id' => Str::uuid()->toString(),
                'include' => 'users',
                'period' => 'month',
            ])),
            422,
            'validation_failed',
            'multiple keys',
        );
        $this->assertObjectHasProperty('institution_id', $decoded->errors);
        $this->assertObjectHasProperty('include', $decoded->errors);
        $this->assertObjectHasProperty('period', $decoded->errors);

        $this->assertSame($institutionBefore, $institution->refresh()->getRawOriginal());
        $this->assertSame($userBefore, $user->refresh()->getRawOriginal());
        $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot());
    }

    public function test_dashboard_returns_exact_institution_and_user_counts_with_user_active_field_semantics(): void
    {
        $activeInstitution = Institution::factory()->create(['name' => 'Active Count School']);
        $inactiveInstitution = Institution::factory()->inactive()->create(['name' => 'Inactive Count School']);
        Institution::factory()->create([
            'name' => 'Zero User School',
            'contact_email' => null,
            'contact_phone' => null,
            'address' => null,
            'description' => null,
        ]);

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $institutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $activeInstitution, [
            'must_change_password' => true,
        ]);
        $inactiveTeacher = $this->createUserForRole(UserRole::Teacher, $activeInstitution, [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $activeStudentInInactiveInstitution = $this->createUserForRole(UserRole::Student, $inactiveInstitution, [
            'must_change_password' => true,
            'last_login_at' => CarbonImmutable::parse('2026-08-03 09:00:00', 'UTC'),
        ]);
        $parent = $this->createUserForRole(UserRole::Parent, $activeInstitution);
        $activeStudentInInactiveInstitution->createToken('count-semantics-token');

        $response = $this->authorizedGet($platformOwner);

        $response->assertOk();
        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertSame([
            'institutions',
            'users',
            'recent_institutions',
        ], array_keys($response->json('data')));
        $this->assertSame([
            'total' => 3,
            'active' => 2,
            'inactive' => 1,
        ], $response->json('data.institutions'));
        $this->assertSame(3, $response->json('data.institutions.active') + $response->json('data.institutions.inactive'));
        $this->assertSame([
            'total' => 6,
            'active' => 4,
        ], $response->json('data.users'));
        $this->assertIsInt($response->json('data.institutions.total'));
        $this->assertIsInt($response->json('data.institutions.active'));
        $this->assertIsInt($response->json('data.institutions.inactive'));
        $this->assertIsInt($response->json('data.users.total'));
        $this->assertIsInt($response->json('data.users.active'));

        $content = $response->getContent();
        $this->assertStringNotContainsString('message', $content);
        $this->assertStringNotContainsString('meta', $content);
        $this->assertStringNotContainsString('pagination', $content);
        $this->assertStringNotContainsString('links', $content);
        $this->assertStringNotContainsString('contact_email', $content);
        $this->assertStringNotContainsString('contact_phone', $content);
        $this->assertStringNotContainsString('created_by_user_id', $content);
        $this->assertStringNotContainsString('deactivated_at', $content);
        $this->assertStringNotContainsString('institution_settings', $content);
        $this->assertStringNotContainsString('user_counts', $content);
        $this->assertStringNotContainsString('last_login_at', $content);
        $this->assertStringNotContainsString('must_change_password', $content);
        $this->assertStringNotContainsString('token', $content);
        $this->assertStringNotContainsString($inactivePlatformOwner->login_name, $content);
        $this->assertStringNotContainsString($institutionAdmin->login_name, $content);
        $this->assertStringNotContainsString($inactiveTeacher->login_name, $content);
        $this->assertStringNotContainsString($activeStudentInInactiveInstitution->login_name, $content);
        $this->assertStringNotContainsString($parent->login_name, $content);
    }

    public function test_recent_institutions_are_projected_ordered_limited_and_include_active_and_inactive(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $sameTimestamp = CarbonImmutable::parse('2026-08-04 10:00:00', 'UTC');

        Institution::factory()->create([
            'id' => '00000000-0000-0000-0000-000000000001',
            'name' => 'Oldest School',
            'created_at' => CarbonImmutable::parse('2026-08-01 10:00:00', 'UTC'),
        ]);
        Institution::factory()->inactive()->create([
            'id' => '00000000-0000-0000-0000-000000000002',
            'name' => 'Older Inactive School',
            'created_at' => CarbonImmutable::parse('2026-08-02 10:00:00', 'UTC'),
        ]);
        Institution::factory()->create([
            'id' => '00000000-0000-0000-0000-000000000003',
            'name' => 'Recent Fifth School',
            'created_at' => CarbonImmutable::parse('2026-08-03 10:00:00', 'UTC'),
        ]);
        Institution::factory()->create([
            'id' => '00000000-0000-0000-0000-000000000004',
            'name' => 'Tie Lower School',
            'created_at' => $sameTimestamp,
        ]);
        Institution::factory()->inactive()->create([
            'id' => '00000000-0000-0000-0000-000000000005',
            'name' => 'Tie Higher Inactive School',
            'created_at' => $sameTimestamp,
        ]);
        Institution::factory()->create([
            'id' => '00000000-0000-0000-0000-000000000006',
            'name' => 'Newer School',
            'created_at' => CarbonImmutable::parse('2026-08-05 10:00:00', 'UTC'),
        ]);
        Institution::factory()->inactive()->create([
            'id' => '00000000-0000-0000-0000-000000000007',
            'name' => 'Newest Inactive School',
            'created_at' => CarbonImmutable::parse('2026-08-06 10:00:00', 'UTC'),
        ]);

        $response = $this->authorizedGet($platformOwner);

        $response->assertOk();
        $recentInstitutions = $response->json('data.recent_institutions');
        $this->assertCount(5, $recentInstitutions);
        $this->assertSame([
            '00000000-0000-0000-0000-000000000007',
            '00000000-0000-0000-0000-000000000006',
            '00000000-0000-0000-0000-000000000005',
            '00000000-0000-0000-0000-000000000004',
            '00000000-0000-0000-0000-000000000003',
        ], array_column($recentInstitutions, 'id'));
        $this->assertContains(InstitutionStatus::Active->value, array_column($recentInstitutions, 'status'));
        $this->assertContains(InstitutionStatus::Inactive->value, array_column($recentInstitutions, 'status'));

        foreach ($recentInstitutions as $institution) {
            $this->assertSame([
                'id',
                'name',
                'type',
                'status',
                'created_at',
            ], array_keys($institution));
            $this->assertTrue(Str::isUuid($institution['id']));
            $this->assertIsString($institution['name']);
            $this->assertContains($institution['type'], InstitutionType::values());
            $this->assertContains($institution['status'], InstitutionStatus::values());
        }

        $this->assertSame('2026-08-06T10:00:00Z', $recentInstitutions[0]['created_at']);
        $this->assertArrayNotHasKey('contact_email', $recentInstitutions[0]);
        $this->assertArrayNotHasKey('contact_phone', $recentInstitutions[0]);
        $this->assertArrayNotHasKey('address', $recentInstitutions[0]);
        $this->assertArrayNotHasKey('description', $recentInstitutions[0]);
        $this->assertArrayNotHasKey('created_by_user_id', $recentInstitutions[0]);
        $this->assertArrayNotHasKey('updated_at', $recentInstitutions[0]);
        $this->assertArrayNotHasKey('user_counts', $recentInstitutions[0]);
    }

    public function test_empty_tables_return_exact_zero_response_from_read_model(): void
    {
        $this->assertSame(0, Institution::query()->count());
        $this->assertSame(0, User::query()->count());

        $response = (new PlatformDashboardResource(app(ShowPlatformDashboard::class)()))
            ->toResponse(request());

        $this->assertSame([
            'data' => [
                'institutions' => [
                    'total' => 0,
                    'active' => 0,
                    'inactive' => 0,
                ],
                'users' => [
                    'total' => 0,
                    'active' => 0,
                ],
                'recent_institutions' => [],
            ],
        ], $response->getData(true));
    }

    public function test_dashboard_read_model_uses_bounded_aggregate_and_projected_queries(): void
    {
        foreach (range(1, 8) as $number) {
            $institution = Institution::factory()->create([
                'name' => sprintf('Query Quality School %02d', $number),
            ]);
            User::factory()->teacher($institution)->create([
                'must_change_password' => false,
            ]);
        }

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $dashboard = app(ShowPlatformDashboard::class)();
            $queries = collect(DB::getQueryLog())->pluck('query')->map(fn (string $query): string => strtolower($query));
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame(8, $dashboard['institutions']['total']);
        $this->assertCount(5, $dashboard['recent_institutions']);
        $this->assertCount(3, $queries);
        $this->assertSame(1, $queries->filter(fn (string $query): bool => str_contains($query, 'from "institutions"')
            && str_contains($query, 'count(*) as total')
            && str_contains($query, 'filter (where status = ?)'))->count());
        $this->assertSame(1, $queries->filter(fn (string $query): bool => str_contains($query, 'from "users"')
            && str_contains($query, 'count(*) as total')
            && str_contains($query, 'filter (where is_active = true)'))->count());

        $recentQuery = $queries->first(fn (string $query): bool => str_contains($query, 'order by "created_at" desc, "id" desc'));
        $this->assertIsString($recentQuery);
        $this->assertStringContainsString('select "id", "name", "type", "status", "created_at"', $recentQuery);
        $this->assertStringContainsString('limit 5', $recentQuery);
        $this->assertFalse($queries->contains(fn (string $query): bool => str_contains($query, 'select *')));
        $this->assertFalse($queries->contains(fn (string $query): bool => str_contains($query, 'from "users" where "users"."institution_id"')));
        $this->assertFalse($queries->contains(fn (string $query): bool => str_contains($query, 'group by "role"')));
    }

    public function test_dashboard_success_does_not_mutate_institutions_users_or_token_rows(): void
    {
        $institution = Institution::factory()->create([
            'name' => 'Read Only School',
            'created_at' => CarbonImmutable::parse('2026-08-01 10:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-01 11:00:00', 'UTC'),
        ]);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'last_login_at' => CarbonImmutable::parse('2026-08-02 10:00:00', 'UTC'),
        ]);
        $token = $this->tokenFor($platformOwner);

        $institutionBefore = $institution->refresh()->getRawOriginal();
        $userBefore = $platformOwner->refresh()->getRawOriginal();
        $tokenRowsBefore = $this->tokenRowsSnapshot();

        $this->withToken($token)->getJson(self::URI)->assertOk();

        $this->assertSame($institutionBefore, $institution->refresh()->getRawOriginal());
        $this->assertSame($userBefore, $platformOwner->refresh()->getRawOriginal());
        $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot());
    }

    public function test_unexpected_dashboard_failure_uses_centralized_server_error_without_details(): void
    {
        config(['app.debug' => false]);

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $dashboard = Mockery::mock(ShowPlatformDashboard::class);
        $dashboard->shouldReceive('__invoke')
            ->once()
            ->andThrow(new RuntimeException('controlled dashboard failure with SQLSTATE details'));
        $this->app->instance(ShowPlatformDashboard::class, $dashboard);

        $response = $this->authorizedGet($platformOwner);
        $decoded = $this->assertErrorContract($response, 500, 'server_error');

        $this->assertSame('An unexpected server error occurred.', $decoded->message);
        $content = $response->getContent();
        $this->assertStringNotContainsString('controlled dashboard failure', $content);
        $this->assertStringNotContainsString('SQLSTATE', $content);
        $this->assertStringNotContainsString('trace', $content);
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

    private function authorizedGet(User $user): TestResponse
    {
        return $this->withToken($this->tokenFor($user))->getJson(self::URI);
    }

    /**
     * @param  list<string>  $abilities
     */
    private function tokenFor(User $user, array $abilities = ['*']): string
    {
        return $user->createToken('platform-dashboard-api-test', $abilities)->plainTextToken;
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
