<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ShowInstitutionDashboard;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class InstitutionDashboardApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/institution/dashboard';

    public function test_dashboard_route_is_registered_once_with_required_middleware_order(): void
    {
        $dashboardRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/institution/dashboard')
            ->filter(fn (array $route): bool => in_array('GET', $route['methods'], true))
            ->values()
            ->all();

        $this->assertSame([
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/institution/dashboard',
                'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'],
            ],
        ], $dashboardRoutes);
    }

    public function test_dashboard_returns_exact_integer_totals_for_active_and_inactive_own_institution_users(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);

        foreach ([UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $this->createUserForRole($role, $institution);
            $this->createUserForRole($role, $institution, [
                'is_active' => false,
                'deactivated_at' => now(),
            ]);

            $this->createUserForRole($role, $otherInstitution);
            $this->createUserForRole($role, $otherInstitution, [
                'is_active' => false,
                'deactivated_at' => now(),
            ]);
        }

        $sameInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $foreignTeacher = User::query()
            ->where('institution_id', $otherInstitution->id)
            ->where('role', UserRole::Teacher)
            ->firstOrFail();

        $response = $this->authorizedDashboard($actor);

        $response->assertOk();
        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertSame(['users'], array_keys($response->json('data')));
        $this->assertSame(['teachers', 'students', 'parents'], array_keys($response->json('data.users')));
        $this->assertSame([
            'teachers' => 2,
            'students' => 2,
            'parents' => 2,
        ], $response->json('data.users'));
        $this->assertIsInt($response->json('data.users.teachers'));
        $this->assertIsInt($response->json('data.users.students'));
        $this->assertIsInt($response->json('data.users.parents'));

        $content = $response->getContent();
        foreach ([
            'message',
            'meta',
            'groups',
            'topics',
            'learning',
            'active',
            'inactive',
            'institution_id',
            'full_name',
            'login_name',
            'email',
            'phone',
            'password',
            'must_change_password',
            'last_login_at',
            'created_by_user_id',
            'deactivated_at',
            'token',
            $institution->id,
            $otherInstitution->id,
            $sameInstitutionAdmin->id,
            $platformOwner->id,
            $foreignTeacher->id,
        ] as $protectedValue) {
            $this->assertStringNotContainsString($protectedValue, $content);
        }
    }

    public function test_account_activation_and_deactivation_do_not_change_role_totals(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $teacher = $this->createUserForRole(UserRole::Teacher, $institution);
        $student = $this->createUserForRole(UserRole::Student, $institution, [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->createUserForRole(UserRole::Parent, $institution);

        $expectedCounts = [
            'teachers' => 1,
            'students' => 1,
            'parents' => 1,
        ];

        $this->assertSame($expectedCounts, $this->authorizedDashboard($actor)->json('data.users'));

        $teacher->forceFill([
            'is_active' => false,
            'deactivated_at' => now(),
        ])->save();
        $student->forceFill([
            'is_active' => true,
            'deactivated_at' => null,
        ])->save();

        $this->assertSame($expectedCounts, $this->authorizedDashboard($actor)->json('data.users'));
    }

    public function test_dashboard_returns_numeric_zeroes_when_institution_has_no_eligible_users(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);

        $response = $this->authorizedDashboard($actor);

        $response->assertOk()->assertExactJson([
            'data' => [
                'users' => [
                    'teachers' => 0,
                    'students' => 0,
                    'parents' => 0,
                ],
            ],
        ]);
        $this->assertIsInt($response->json('data.users.teachers'));
        $this->assertIsInt($response->json('data.users.students'));
        $this->assertIsInt($response->json('data.users.parents'));
    }

    public function test_authentication_lifecycle_password_and_role_gates_have_required_precedence(): void
    {
        $rowsBefore = $this->protectedRowsSnapshot();
        $this->assertErrorContract($this->rawDashboard(), 401, 'authentication_required');
        $this->assertErrorContract($this->rawDashboard('invalid-token'), 401, 'authentication_required');
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), 'unauthenticated requests');
        $this->forgetAuthenticationGuards();

        $institution = Institution::factory()->create();
        $inactiveTeacher = $this->createUserForRole(UserRole::Teacher, $institution, [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertUserDashboardRejectionWithoutWrites(
            $inactiveTeacher,
            403,
            'user_inactive',
        );
        $this->forgetAuthenticationGuards();

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $teacherInInactiveInstitution = $this->createUserForRole(UserRole::Teacher, $inactiveInstitution);
        $this->assertUserDashboardRejectionWithoutWrites(
            $teacherInInactiveInstitution,
            403,
            'institution_inactive',
        );
        $this->forgetAuthenticationGuards();

        $passwordIncompleteTeacher = $this->createUserForRole(UserRole::Teacher, $institution, [
            'must_change_password' => true,
        ]);
        $this->assertUserDashboardRejectionWithoutWrites(
            $passwordIncompleteTeacher,
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole($role, $role === UserRole::PlatformOwner ? null : $institution);

            $this->assertUserDashboardRejectionWithoutWrites(
                $wrongRoleUser,
                403,
                'forbidden',
                $role->value,
            );
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_dashboard_accepts_only_zero_raw_body_bytes_and_rejects_every_query_key_without_writes(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $this->createUserForRole(UserRole::Teacher, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();

        $this->rawDashboard($token)->assertOk();
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());

        $bodyCases = [
            'whitespace' => [" \t\r\n", 'text/plain'],
            'empty object' => ['{}', 'application/json'],
            'keyed object' => ['{"institution_id":"foreign"}', 'application/json'],
            'array' => ['[]', 'application/json'],
            'string scalar' => ['"dashboard"', 'application/json'],
            'number scalar' => ['42', 'application/json'],
            'json null' => ['null', 'application/json'],
            'malformed json' => ['{"role":"teacher"', 'application/json'],
        ];

        foreach ($bodyCases as $case => [$content, $contentType]) {
            $decoded = $this->assertErrorContract(
                $this->rawDashboard($token, $content, contentType: $contentType),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case);
            $this->forgetAuthenticationGuards();
        }

        foreach ([
            'institution_id' => $institution->id,
            'role' => UserRole::Teacher->value,
            'include' => 'users',
            'page' => 1,
        ] as $queryKey => $queryValue) {
            $decoded = $this->assertErrorContract(
                $this->rawDashboard($token, query: [$queryKey => $queryValue]),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $queryKey);
            $this->forgetAuthenticationGuards();
        }

        $combined = $this->assertErrorContract(
            $this->rawDashboard($token, '{}', ['institution_id' => $institution->id]),
            422,
            'validation_failed',
            'body and query',
        );
        $this->assertObjectHasProperty('body', $combined->errors);
        $this->assertObjectHasProperty('institution_id', $combined->errors);
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
    }

    public function test_success_and_authorization_failure_do_not_mutate_institutions_users_or_sanctum_tokens(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $teacher = $this->createUserForRole(UserRole::Teacher, $institution);
        $actorToken = $this->tokenFor($actor);
        $teacherToken = $this->tokenFor($teacher);
        $rowsBefore = $this->protectedRowsSnapshot();

        $this->rawDashboard($actorToken)->assertOk();
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), 'successful request');
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->rawDashboard($teacherToken),
            403,
            'forbidden',
        );
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), 'authorization failure');
    }

    public function test_action_uses_exactly_one_tenant_first_conditional_user_aggregate_without_hydration(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);

        foreach ([UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $this->createUserForRole($role, $institution);
            $this->createUserForRole($role, $otherInstitution);
        }

        $retrievedUsers = 0;
        User::retrieved(function () use (&$retrievedUsers): void {
            $retrievedUsers++;
        });

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $dashboard = app(ShowInstitutionDashboard::class)($actor);
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame([
            'users' => [
                'teachers' => 1,
                'students' => 1,
                'parents' => 1,
            ],
        ], $dashboard);
        $this->assertCount(1, $queries);
        $this->assertSame(0, $retrievedUsers);

        $query = strtolower($queries[0]['query']);
        $this->assertStringContainsString('from "users"', $query);
        $this->assertStringContainsString('count(*) filter (where role = ?) as teachers', $query);
        $this->assertStringContainsString('count(*) filter (where role = ?) as students', $query);
        $this->assertStringContainsString('count(*) filter (where role = ?) as parents', $query);
        $this->assertMatchesRegularExpression('/where "institution_id" = \? and "role" in \(\?, \?, \?\)/', $query);
        $this->assertStringNotContainsString('is_active', $query);
        $this->assertStringNotContainsString('select *', $query);
        $this->assertStringNotContainsString('group by', $query);
        $this->assertSame(1, collect($queries[0]['bindings'])->filter(
            fn (mixed $binding): bool => $binding === $institution->id,
        )->count());
        $this->assertSame(0, collect($queries[0]['bindings'])->filter(
            fn (mixed $binding): bool => $binding === $otherInstitution->id,
        )->count());
    }

    public function test_unexpected_failure_uses_safe_centralized_server_error_without_writes_or_details(): void
    {
        config(['app.debug' => false]);

        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();
        $dashboard = Mockery::mock(ShowInstitutionDashboard::class);
        $dashboard->shouldReceive('__invoke')
            ->once()
            ->with(Mockery::on(fn (mixed $value): bool => $value instanceof User && $value->is($actor)))
            ->andThrow(new RuntimeException(
                'SQLSTATE controlled failure for tenant '.$institution->id.' and user '.$actor->id,
            ));
        $this->app->instance(ShowInstitutionDashboard::class, $dashboard);

        $response = $this->rawDashboard($token);
        $decoded = $this->assertErrorContract($response, 500, 'server_error');

        $this->assertSame('An unexpected server error occurred.', $decoded->message);
        $content = $response->getContent();
        $this->assertStringNotContainsString('SQLSTATE', $content);
        $this->assertStringNotContainsString('controlled failure', $content);
        $this->assertStringNotContainsString($institution->id, $content);
        $this->assertStringNotContainsString($actor->id, $content);
        $this->assertStringNotContainsString('trace', $content);
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

    private function authorizedDashboard(User $user): TestResponse
    {
        return $this->rawDashboard($this->tokenFor($user));
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function rawDashboard(
        ?string $token = null,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $uri = self::URI.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
        ];

        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call('GET', $uri, [], [], [], $server, $content);
    }

    private function tokenFor(User $user): string
    {
        return $user->createToken('institution-dashboard-api-test')->plainTextToken;
    }

    private function assertUserDashboardRejectionWithoutWrites(
        User $user,
        int $status,
        string $code,
        string $case = '',
    ): void {
        $token = $this->tokenFor($user);
        $rowsBefore = $this->protectedRowsSnapshot();

        $this->assertErrorContract($this->rawDashboard($token), $status, $code, $case);
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case);
    }

    /**
     * @return array<string, list<array<string, mixed>>>
     */
    private function protectedRowsSnapshot(): array
    {
        return [
            'institutions' => $this->tableRowsSnapshot('institutions'),
            'users' => $this->tableRowsSnapshot('users'),
            'personal_access_tokens' => $this->tableRowsSnapshot('personal_access_tokens'),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function tableRowsSnapshot(string $table): array
    {
        return DB::table($table)
            ->orderBy('id')
            ->get()
            ->map(fn (object $row): array => (array) $row)
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
