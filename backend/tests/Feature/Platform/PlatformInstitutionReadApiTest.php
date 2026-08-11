<?php

namespace Tests\Feature\Platform;

use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
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
use Tests\TestCase;

class PlatformInstitutionReadApiTest extends TestCase
{
    use RefreshDatabase;

    private const INDEX_URI = '/api/v1/platform/institutions';

    public function test_routes_are_registered_only_under_platform_institution_path_with_required_middleware_order(): void
    {
        $platformInstitutionRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => str_starts_with($route['uri'], 'api/v1/platform/institutions'))
            ->filter(fn (array $route): bool => in_array('GET', $route['methods'], true))
            ->values()
            ->all();

        $expectedMiddleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:platform_owner'];

        $this->assertSame([
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/platform/institutions',
                'middleware' => $expectedMiddleware,
            ],
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/platform/institutions/{institution}',
                'middleware' => $expectedMiddleware,
            ],
        ], $platformInstitutionRoutes);
    }

    public function test_active_password_complete_platform_owner_can_list_and_view_institutions(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create([
            'name' => 'Authorized Detail School',
            'type' => InstitutionType::School,
            'status' => InstitutionStatus::Active,
        ]);

        $this->withToken($this->tokenFor($platformOwner))
            ->getJson(self::INDEX_URI)
            ->assertOk()
            ->assertJsonPath('data.0.id', $institution->id)
            ->assertJsonPath('data.0.name', 'Authorized Detail School');
        $this->forgetAuthenticationGuards();

        $this->withToken($this->tokenFor($platformOwner))
            ->getJson($this->detailUri($institution))
            ->assertOk()
            ->assertJsonPath('data.id', $institution->id)
            ->assertJsonPath('data.name', 'Authorized Detail School');
    }

    public function test_authentication_account_password_and_role_gates_protect_both_routes(): void
    {
        $institution = Institution::factory()->create();

        foreach ([self::INDEX_URI, $this->detailUri($institution)] as $uri) {
            $this->assertErrorContract($this->getJson($uri), 401, 'authentication_required');
        }

        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertErrorContract(
            $this->withToken($this->tokenFor($inactivePlatformOwner))->getJson(self::INDEX_URI),
            403,
            'user_inactive',
        );
        $this->forgetAuthenticationGuards();

        $passwordIncompletePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'must_change_password' => true,
        ]);
        $this->assertErrorContract(
            $this->withToken($this->tokenFor($passwordIncompletePlatformOwner))->getJson(self::INDEX_URI),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $passwordIncompleteWrongRole = $this->createUserForRole(UserRole::Student, attributes: [
            'must_change_password' => true,
        ]);
        $this->assertErrorContract(
            $this->withToken($this->tokenFor($passwordIncompleteWrongRole))->getJson(self::INDEX_URI),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole($role);

            foreach ([self::INDEX_URI, $this->detailUri($institution)] as $uri) {
                $this->assertErrorContract(
                    $this->withToken($this->tokenFor($wrongRoleUser))->getJson($uri),
                    403,
                    'forbidden',
                    $role->value.' denied '.$uri,
                );
                $this->forgetAuthenticationGuards();
            }
        }
    }

    public function test_client_supplied_role_in_query_headers_body_or_token_ability_cannot_elevate_access(): void
    {
        $institution = Institution::factory()->create();
        $teacher = $this->createUserForRole(UserRole::Teacher, $institution);
        $spoofedToken = $this->tokenFor($teacher, ['platform_owner', 'role:platform_owner']);

        $this->assertErrorContract(
            $this->withToken($spoofedToken)
                ->withHeaders([
                    'X-Role' => UserRole::PlatformOwner->value,
                    'X-User-Role' => UserRole::PlatformOwner->value,
                ])
                ->json('GET', self::INDEX_URI.'?role='.UserRole::PlatformOwner->value, [
                    'role' => UserRole::PlatformOwner->value,
                    'institution_id' => null,
                ]),
            403,
            'forbidden',
        );
    }

    public function test_search_is_case_insensitive_trimmed_name_only_literal_and_composable_with_filters(): void
    {
        $matchingInstitution = Institution::factory()->create([
            'name' => 'Samarkand 100%_Alpha School',
            'type' => InstitutionType::School,
            'status' => InstitutionStatus::Active,
        ]);

        Institution::factory()->inactive()->create([
            'name' => 'Samarkand 100%_Alpha Inactive School',
            'type' => InstitutionType::School,
        ]);
        Institution::factory()->create([
            'name' => 'Samarkand 100%_Alpha College',
            'type' => InstitutionType::College,
            'status' => InstitutionStatus::Active,
        ]);
        Institution::factory()->create([
            'name' => 'Samarkand 100XAlpha School',
            'type' => InstitutionType::School,
            'status' => InstitutionStatus::Active,
        ]);
        $contactOnly = Institution::factory()->create([
            'name' => 'Plain Contact Institution',
            'contact_email' => 'samarkand-100-alpha@example.uz',
            'description' => 'Samarkand 100%_Alpha description',
        ]);
        InstitutionSetting::factory()->create([
            'institution_id' => $contactOnly->id,
            'timezone' => 'Samarkand/Needle',
        ]);
        User::factory()->teacher($contactOnly)->create([
            'full_name' => 'Samarkand 100%_Alpha User',
        ]);

        $response = $this->authorizedIndex([
            'search' => '  100%_alpha  ',
            'status' => InstitutionStatus::Active->value,
            'type' => InstitutionType::School->value,
        ]);

        $response->assertOk();
        $this->assertSame([$matchingInstitution->id], $this->idsFromList($response));
    }

    public function test_empty_search_status_filters_and_all_locked_type_values_work(): void
    {
        $active = Institution::factory()->create([
            'name' => 'Active Searchless School',
            'status' => InstitutionStatus::Active,
            'type' => InstitutionType::School,
        ]);
        $inactive = Institution::factory()->inactive()->create([
            'name' => 'Inactive Searchless School',
            'type' => InstitutionType::School,
        ]);

        $expectedEmptySearchIds = [$active->id, $inactive->id];
        $actualEmptySearchIds = $this->idsFromList($this->authorizedIndex(['search' => '   ']));
        sort($expectedEmptySearchIds);
        sort($actualEmptySearchIds);

        $this->assertSame($expectedEmptySearchIds, $actualEmptySearchIds);
        $this->assertSame([$active->id], $this->idsFromList($this->authorizedIndex([
            'status' => InstitutionStatus::Active->value,
        ])));
        $this->assertSame([$inactive->id], $this->idsFromList($this->authorizedIndex([
            'status' => InstitutionStatus::Inactive->value,
        ])));

        foreach (InstitutionType::cases() as $type) {
            Institution::query()->delete();
            $institution = Institution::factory()->create([
                'name' => 'Type '.$type->value,
                'type' => $type,
            ]);

            $response = $this->authorizedIndex(['type' => $type->value]);

            $response->assertOk();
            $this->assertSame([$institution->id], $this->idsFromList($response));
            $this->assertSame($type->value, $response->json('data.0.type'));
        }
    }

    public function test_invalid_and_unknown_query_parameters_return_validation_failed_with_field_errors(): void
    {
        $cases = [
            'invalid status' => [['status' => 'suspended'], 'status'],
            'invalid type' => [['type' => 'academy'], 'type'],
            'page below minimum' => [['page' => 0], 'page'],
            'page non integer' => [['page' => 'one'], 'page'],
            'per page below minimum' => [['per_page' => 0], 'per_page'],
            'per page above maximum' => [['per_page' => 101], 'per_page'],
            'per page non integer' => [['per_page' => 'many'], 'per_page'],
            'unknown sort' => [['sort' => 'created_by_user_id'], 'sort'],
            'unknown direction' => [['direction' => 'sideways'], 'direction'],
            'oversized search' => [['search' => str_repeat('a', 201)], 'search'],
            'unsafe institution id key' => [['institution_id' => Str::uuid()->toString()], 'institution_id'],
            'unsafe created by key' => [['created_by_user_id' => Str::uuid()->toString()], 'created_by_user_id'],
            'unsafe role key' => [['role' => UserRole::PlatformOwner->value], 'role'],
            'unsafe include users key' => [['include_users' => '1'], 'include_users'],
            'unsafe include learning key' => [['include_learning_data' => '1'], 'include_learning_data'],
        ];

        foreach ($cases as $case => [$query, $expectedField]) {
            $decoded = $this->assertErrorContract(
                $this->authorizedIndex($query),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($expectedField, $decoded->errors, $case);
            $this->assertIsArray($decoded->errors->{$expectedField}, $case);
        }
    }

    public function test_pagination_contract_uses_locked_shape_and_rejects_laravel_transport_fields(): void
    {
        foreach (range(1, 25) as $number) {
            Institution::factory()->create([
                'name' => sprintf('Paged Institution %02d', $number),
            ]);
        }

        $defaultResponse = $this->authorizedIndex();
        $defaultResponse->assertOk();
        $this->assertCount(20, $defaultResponse->json('data'));
        $this->assertSame([
            'page' => 1,
            'per_page' => 20,
            'total' => 25,
            'last_page' => 2,
        ], $defaultResponse->json('meta.pagination'));
        $this->assertArrayNotHasKey('links', $defaultResponse->json());
        $this->assertArrayNotHasKey('current_page', $defaultResponse->json('meta.pagination'));

        $customResponse = $this->authorizedIndex([
            'page' => 2,
            'per_page' => 10,
        ]);
        $customResponse->assertOk();
        $this->assertCount(10, $customResponse->json('data'));
        $this->assertSame(2, $customResponse->json('meta.pagination.page'));
        $this->assertSame(10, $customResponse->json('meta.pagination.per_page'));

        $perPageMaximumResponse = $this->authorizedIndex(['per_page' => 100]);
        $perPageMaximumResponse->assertOk();
        $this->assertCount(25, $perPageMaximumResponse->json('data'));

        $emptyResponse = $this->authorizedIndex(['search' => 'no matching institution']);
        $emptyResponse->assertOk();
        $this->assertSame([], $emptyResponse->json('data'));
        $this->assertSame([
            'page' => 1,
            'per_page' => 20,
            'total' => 0,
            'last_page' => 1,
        ], $emptyResponse->json('meta.pagination'));
    }

    public function test_allowed_sort_fields_support_both_directions_and_deterministic_uuid_tie_breaking(): void
    {
        $firstId = '00000000-0000-0000-0000-000000000001';
        $secondId = '00000000-0000-0000-0000-000000000002';
        $thirdId = '00000000-0000-0000-0000-000000000003';

        Institution::factory()->create([
            'id' => $thirdId,
            'name' => 'Beta',
            'status' => InstitutionStatus::Inactive,
            'created_at' => CarbonImmutable::parse('2026-01-03 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-04 00:00:00', 'UTC'),
        ]);
        Institution::factory()->create([
            'id' => $secondId,
            'name' => 'alpha',
            'status' => InstitutionStatus::Active,
            'created_at' => CarbonImmutable::parse('2026-01-01 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-02 00:00:00', 'UTC'),
        ]);
        Institution::factory()->create([
            'id' => $firstId,
            'name' => 'Alpha',
            'status' => InstitutionStatus::Active,
            'created_at' => CarbonImmutable::parse('2026-01-01 00:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-01-02 00:00:00', 'UTC'),
        ]);

        $ascendingWithTieBreaker = [$firstId, $secondId, $thirdId];
        $descendingWithTieBreaker = [$thirdId, $firstId, $secondId];

        foreach (['name', 'created_at', 'updated_at', 'status'] as $sort) {
            $this->assertSame($ascendingWithTieBreaker, $this->idsFromList($this->authorizedIndex([
                'sort' => $sort,
                'direction' => 'asc',
            ])), $sort.' asc');
            $this->assertSame($descendingWithTieBreaker, $this->idsFromList($this->authorizedIndex([
                'sort' => $sort,
                'direction' => 'desc',
            ])), $sort.' desc');
        }

        $this->assertSame($ascendingWithTieBreaker, $this->idsFromList($this->authorizedIndex()));
    }

    public function test_summary_detail_nullable_timestamp_counts_and_private_data_boundaries_match_contract(): void
    {
        $institution = Institution::factory()->create([
            'name' => 'Contract Shape School',
            'type' => InstitutionType::LearningCenter,
            'status' => InstitutionStatus::Active,
            'contact_email' => null,
            'contact_phone' => null,
            'address' => null,
            'description' => null,
            'created_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 16:00:00', 'UTC'),
        ]);
        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'timezone' => 'Sensitive/Settings',
        ]);
        User::factory()->teacher($institution)->create([
            'full_name' => 'Sensitive Teacher Name',
            'login_name' => 'sensitive_teacher_login',
            'email' => 'sensitive-teacher@example.uz',
            'must_change_password' => false,
        ]);
        User::factory()->student($institution)->inactive()->create([
            'full_name' => 'Inactive Sensitive Student',
            'login_name' => 'inactive_sensitive_student',
            'email' => 'inactive-sensitive-student@example.uz',
            'must_change_password' => false,
        ]);
        User::factory()->parent($institution)->create([
            'full_name' => 'Sensitive Parent Name',
            'login_name' => 'sensitive_parent_login',
            'must_change_password' => false,
        ]);
        User::factory()->teacher(Institution::factory()->create())->create();
        User::factory()->platformOwner()->create();

        $summaryResponse = $this->authorizedIndex(['search' => 'Contract Shape School']);
        $summaryResponse->assertOk();
        $summary = $summaryResponse->json('data.0');

        $this->assertSame([
            'id',
            'name',
            'type',
            'status',
            'contact_email',
            'contact_phone',
            'created_at',
            'updated_at',
            'user_counts',
        ], array_keys($summary));
        $this->assertSame('2026-08-07T15:00:00Z', $summary['created_at']);
        $this->assertSame('2026-08-07T16:00:00Z', $summary['updated_at']);
        $this->assertSame(['total' => 3, 'active' => 2], $summary['user_counts']);
        $this->assertArrayNotHasKey('address', $summary);
        $this->assertArrayNotHasKey('description', $summary);

        $detailResponse = $this->authorizedDetail($institution);
        $detailResponse->assertOk();
        $detail = $detailResponse->json('data');

        $this->assertSame([
            'id',
            'name',
            'type',
            'status',
            'contact_email',
            'contact_phone',
            'address',
            'description',
            'created_at',
            'updated_at',
            'user_counts',
        ], array_keys($detail));
        $this->assertNull($detail['contact_email']);
        $this->assertNull($detail['contact_phone']);
        $this->assertNull($detail['address']);
        $this->assertNull($detail['description']);
        $this->assertSame(InstitutionType::LearningCenter->value, $detail['type']);
        $this->assertSame(InstitutionStatus::Active->value, $detail['status']);
        $this->assertSame(['total' => 3, 'active' => 2], $detail['user_counts']);

        foreach ([$summaryResponse, $detailResponse] as $response) {
            $content = $response->getContent();
            $this->assertStringNotContainsString('Sensitive Teacher Name', $content);
            $this->assertStringNotContainsString('sensitive_teacher_login', $content);
            $this->assertStringNotContainsString('sensitive-teacher@example.uz', $content);
            $this->assertStringNotContainsString('Sensitive/Settings', $content);
            $this->assertStringNotContainsString('acceptable_score_difference', $content);
            $this->assertStringNotContainsString('users', $content);
            $this->assertStringNotContainsString('created_by_user_id', $content);
            $this->assertStringNotContainsString('deactivated_at', $content);
        }
    }

    public function test_detail_returns_known_institution_and_scope_safe_not_found_for_unknown_or_malformed_uuid(): void
    {
        $institution = Institution::factory()->create(['name' => 'Known UUID School']);

        $this->authorizedDetail($institution)
            ->assertOk()
            ->assertJsonPath('data.id', $institution->id);

        $this->assertErrorContract(
            $this->authorizedGet('/api/v1/platform/institutions/'.Str::uuid()),
            404,
            'resource_not_found',
        );

        $this->assertErrorContract(
            $this->authorizedGet('/api/v1/platform/institutions/not-a-uuid'),
            404,
            'resource_not_found',
        );
    }

    public function test_list_user_counts_are_computed_without_one_query_per_institution(): void
    {
        foreach (range(1, 6) as $number) {
            $institution = Institution::factory()->create([
                'name' => sprintf('Count Query School %02d', $number),
            ]);

            User::factory()->teacher($institution)->create(['must_change_password' => false]);
            User::factory()->student($institution)->inactive()->create(['must_change_password' => false]);
        }

        DB::flushQueryLog();
        DB::enableQueryLog();

        $response = $this->authorizedIndex(['per_page' => 6]);

        DB::disableQueryLog();

        $response->assertOk();
        $this->assertCount(6, $response->json('data'));

        $userCountQueries = collect(DB::getQueryLog())
            ->pluck('query')
            ->filter(fn (string $query): bool => str_contains($query, 'user_counts_total')
                || str_contains($query, 'user_counts_active'))
            ->values();

        $this->assertCount(1, $userCountQueries->all());
        $this->assertStringContainsString('select count(*) from "users"', $userCountQueries->first());
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function authorizedIndex(array $query = []): TestResponse
    {
        return $this->authorizedGet(self::INDEX_URI.($query === [] ? '' : '?'.http_build_query($query)));
    }

    private function authorizedDetail(Institution $institution): TestResponse
    {
        return $this->authorizedGet($this->detailUri($institution));
    }

    private function authorizedGet(string $uri): TestResponse
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        return $this->withToken($this->tokenFor($platformOwner))->getJson($uri);
    }

    private function detailUri(Institution $institution): string
    {
        return self::INDEX_URI.'/'.$institution->id;
    }

    /**
     * @return list<string>
     */
    private function idsFromList(TestResponse $response): array
    {
        return array_column($response->json('data'), 'id');
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
        return $user->createToken('platform-institution-read-api-test', $abilities)->plainTextToken;
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
