<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ShowInstitutionProfile;
use App\Actions\Institution\UpdateInstitutionProfile;
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
use Mockery;
use RuntimeException;
use Tests\TestCase;

class InstitutionProfileApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/institution/profile';

    private const PROFILE_KEYS = [
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
    ];

    public function test_profile_routes_are_registered_once_with_required_middleware_order(): void
    {
        $profileRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/institution/profile')
            ->values()
            ->all();

        $this->assertSame([
            [
                'methods' => ['GET'],
                'uri' => 'api/v1/institution/profile',
                'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'],
            ],
            [
                'methods' => ['PATCH'],
                'uri' => 'api/v1/institution/profile',
                'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'],
            ],
        ], $profileRoutes);
    }

    public function test_get_returns_only_the_authenticated_institution_exact_resource_with_utc_timestamps_and_nulls(): void
    {
        $creator = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create([
            'name' => 'Own School',
            'type' => InstitutionType::School,
            'status' => InstitutionStatus::Active,
            'contact_email' => null,
            'contact_phone' => '+998 90 123 45 67',
            'address' => null,
            'description' => 'Own description',
            'created_by_user_id' => $creator->id,
            'created_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 20:30:00', 'UTC'),
        ]);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $teacher = $this->createUserForRole(UserRole::Teacher, $institution);
        $otherInstitution = Institution::factory()->create([
            'name' => 'Foreign Institution',
            'contact_email' => 'foreign@example.uz',
        ]);
        InstitutionSetting::factory()->create(['institution_id' => $otherInstitution->id]);
        $foreignUser = $this->createUserForRole(UserRole::Teacher, $otherInstitution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();

        $response = $this->rawProfile('GET', $token);

        $response->assertOk()->assertExactJson([
            'data' => [
                'id' => $institution->id,
                'name' => 'Own School',
                'type' => InstitutionType::School->value,
                'status' => InstitutionStatus::Active->value,
                'contact_email' => null,
                'contact_phone' => '+998 90 123 45 67',
                'address' => null,
                'description' => 'Own description',
                'created_at' => '2026-08-07T15:00:00Z',
                'updated_at' => '2026-08-07T20:30:00Z',
            ],
        ]);
        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertSame(self::PROFILE_KEYS, array_keys($response->json('data')));
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());

        $content = $response->getContent();
        foreach ([
            'message',
            'meta',
            'links',
            'institution_id',
            'created_by_user_id',
            'deactivated_at',
            'settings',
            'timezone',
            'acceptable_score_difference',
            'user_counts',
            'users',
            'tokens',
            'password',
            'relationships',
            'learning',
            'scores',
            'results',
            $creator->id,
            $teacher->id,
            $otherInstitution->id,
            $foreignUser->id,
            'Foreign Institution',
            'foreign@example.uz',
        ] as $protectedValue) {
            $this->assertStringNotContainsString((string) $protectedValue, $content);
        }
    }

    public function test_get_accepts_only_zero_raw_body_bytes_and_rejects_every_query_key_without_writes(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();

        $this->rawProfile('GET', $token)->assertOk();
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());

        foreach ([
            'whitespace' => " \t\r\n",
            'empty object' => '{}',
            'keyed object' => '{"institution_id":"foreign"}',
            'array' => '[]',
            'string scalar' => '"profile"',
            'number scalar' => '42',
            'json null' => 'null',
            'malformed json' => '{"name":"broken"',
        ] as $case => $content) {
            $decoded = $this->assertErrorContract(
                $this->rawProfile('GET', $token, $content),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case);
            $this->forgetAuthenticationGuards();
        }

        foreach ([
            'institution_id' => Str::uuid()->toString(),
            'include' => 'settings',
            'page' => 1,
            'unknown' => 'value',
        ] as $queryKey => $queryValue) {
            $decoded = $this->assertErrorContract(
                $this->rawProfile('GET', $token, query: [$queryKey => $queryValue]),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $queryKey);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_patch_updates_allowed_fields_independently_and_together_clears_nulls_and_retains_omitted_values(): void
    {
        $institution = Institution::factory()->create([
            'name' => 'Original School',
            'contact_email' => 'old@example.uz',
            'contact_phone' => 'old phone',
            'address' => 'Old address',
            'description' => 'Old description',
        ]);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);

        foreach ([
            'name' => str_repeat('N', 200),
            'contact_email' => $this->maximumLengthEmail(),
            'contact_phone' => str_repeat('9', 50),
            'address' => str_repeat('A', 1200),
            'description' => str_repeat('D', 1300),
        ] as $field => $value) {
            $before = $this->rawInstitutionSnapshot($institution);
            $response = $this->rawJsonProfilePatch($token, [$field => $value]);

            $this->assertSuccessfulPatch($response, $institution->id);
            $this->assertSame($value, $response->json('data.'.$field), $field);

            foreach (['name', 'contact_email', 'contact_phone', 'address', 'description'] as $otherField) {
                if ($otherField !== $field) {
                    $this->assertSame($before[$otherField], $response->json('data.'.$otherField), $field.' omitted '.$otherField);
                }
            }

            $institution->refresh();
        }

        $combined = [
            'name' => '  Combined School  ',
            'contact_email' => 'combined@example.uz',
            'contact_phone' => '+998 90 555 55 55',
            'address' => 'Combined address',
            'description' => 'Combined description',
        ];
        $combinedResponse = $this->rawJsonProfilePatch($token, $combined);
        $this->assertSuccessfulPatch($combinedResponse, $institution->id);
        $this->assertSame('Combined School', $combinedResponse->json('data.name'));
        foreach (array_diff_key($combined, ['name' => true]) as $field => $value) {
            $this->assertSame($value, $combinedResponse->json('data.'.$field));
        }

        $clearResponse = $this->rawJsonProfilePatch($token, [
            'contact_email' => null,
            'contact_phone' => null,
            'address' => null,
            'description' => null,
        ]);
        $this->assertSuccessfulPatch($clearResponse, $institution->id);
        $this->assertSame('Combined School', $clearResponse->json('data.name'));
        foreach (['contact_email', 'contact_phone', 'address', 'description'] as $field) {
            $this->assertNull($clearResponse->json('data.'.$field));
        }

        Institution::factory()->create([
            'contact_email' => 'duplicate@example.uz',
            'contact_phone' => 'duplicate phone',
        ]);
        $duplicateResponse = $this->rawJsonProfilePatch($token, [
            'contact_email' => 'duplicate@example.uz',
            'contact_phone' => 'duplicate phone',
        ]);
        $this->assertSuccessfulPatch($duplicateResponse, $institution->id);
        $this->assertSame('duplicate@example.uz', $duplicateResponse->json('data.contact_email'));
        $this->assertSame('duplicate phone', $duplicateResponse->json('data.contact_phone'));
    }

    public function test_patch_rejects_invalid_body_shapes_queries_validation_failures_and_protected_keys_without_partial_writes(): void
    {
        $institution = Institution::factory()->create([
            'name' => 'Validation School',
            'contact_email' => 'original@example.uz',
            'contact_phone' => 'original phone',
            'address' => 'Original address',
            'description' => 'Original description',
        ]);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $this->createUserForRole(UserRole::Teacher, $institution);
        $token = $this->tokenFor($actor);

        foreach ([
            'absent body' => '',
            'whitespace body' => " \t\r\n",
            'empty object' => '{}',
            'malformed object' => '{"name":"broken"',
            'array' => '[]',
            'string scalar' => '"profile"',
            'number scalar' => '42',
            'boolean scalar' => 'true',
            'json null' => 'null',
        ] as $case => $content) {
            $before = $this->protectedRowsSnapshot();
            $decoded = $this->assertErrorContract(
                $this->rawProfile('PATCH', $token, $content),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($before, $this->protectedRowsSnapshot(), $case);
            $this->forgetAuthenticationGuards();
        }

        foreach ([
            'blank name' => [['name' => '   '], 'name'],
            'null name' => [['name' => null], 'name'],
            'array name' => [['name' => ['School']], 'name'],
            'boolean name' => [['name' => true], 'name'],
            'too long name' => [['name' => str_repeat('N', 201)], 'name'],
            'invalid email' => [['contact_email' => 'not an email'], 'contact_email'],
            'too long email' => [['contact_email' => $this->maximumLengthEmail().'x'], 'contact_email'],
            'array email' => [['contact_email' => ['email']], 'contact_email'],
            'boolean email' => [['contact_email' => false], 'contact_email'],
            'too long phone' => [['contact_phone' => str_repeat('9', 51)], 'contact_phone'],
            'array phone' => [['contact_phone' => ['phone']], 'contact_phone'],
            'boolean phone' => [['contact_phone' => false], 'contact_phone'],
            'array address' => [['address' => ['Samarkand']], 'address'],
            'boolean address' => [['address' => true], 'address'],
            'array description' => [['description' => ['notes']], 'description'],
            'boolean description' => [['description' => false], 'description'],
        ] as $case => [$payload, $field]) {
            $before = $this->protectedRowsSnapshot();
            $decoded = $this->assertErrorContract(
                $this->rawJsonProfilePatch($token, $payload),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $case);
            $this->assertSame($before, $this->protectedRowsSnapshot(), $case);
            $this->forgetAuthenticationGuards();
        }

        $protectedFields = [
            'id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'type' => InstitutionType::University->value,
            'status' => InstitutionStatus::Inactive->value,
            'created_by_user_id' => Str::uuid()->toString(),
            'deactivated_at' => '2026-08-10T12:00:00Z',
            'created_at' => '2026-08-10T12:00:00Z',
            'updated_at' => '2026-08-10T12:00:00Z',
            'settings' => ['timezone' => 'UTC'],
            'timezone' => 'UTC',
            'learning_material_max_mb' => 1,
            'student_submission_max_mb' => 1,
            'acceptable_score_difference' => 10,
            'blitz_timer_start_mode' => 'individual',
            'student_result_release_mode' => 'automatic',
            'parent_result_release_mode' => 'with_student',
            'role' => UserRole::PlatformOwner->value,
            'users' => [],
            'user_counts' => ['total' => 0],
            'unknown_future_field' => 'not allowed',
        ];

        foreach ($protectedFields as $field => $value) {
            $before = $this->protectedRowsSnapshot();
            $decoded = $this->assertErrorContract(
                $this->rawJsonProfilePatch($token, [
                    'name' => 'Must Not Partially Apply',
                    $field => $value,
                ]),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertSame($before, $this->protectedRowsSnapshot(), $field);
            $this->forgetAuthenticationGuards();
        }

        foreach (['institution_id', 'status', 'unknown'] as $queryKey) {
            $before = $this->protectedRowsSnapshot();
            $decoded = $this->assertErrorContract(
                $this->rawProfile(
                    'PATCH',
                    $token,
                    json_encode(['name' => 'Query Must Reject'], JSON_THROW_ON_ERROR),
                    [$queryKey => 'value'],
                ),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($before, $this->protectedRowsSnapshot(), $queryKey);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_exact_and_trimmed_name_no_ops_issue_no_institution_update_and_preserve_raw_updated_at(): void
    {
        $institution = Institution::factory()->create([
            'name' => 'No-op School',
            'contact_email' => 'same@example.uz',
            'updated_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
        ]);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);
        $institution->refresh();
        $rawUpdatedAt = $institution->getRawOriginal('updated_at');
        $rowsBefore = $this->protectedRowsSnapshot();

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            foreach ([
                'exact values' => ['name' => 'No-op School', 'contact_email' => 'same@example.uz'],
                'trimmed name' => ['name' => '  No-op School  '],
            ] as $case => $payload) {
                DB::flushQueryLog();
                DB::enableQueryLog();

                try {
                    $response = $this->rawJsonProfilePatch($token, $payload);
                    $queries = DB::getQueryLog();
                } finally {
                    DB::disableQueryLog();
                }

                $this->assertSuccessfulPatch($response, $institution->id);
                $this->assertSame('No-op School', $response->json('data.name'), $case);
                $this->assertCount(0, $this->institutionUpdateQueries($queries), $case);
                $institution->refresh();
                $this->assertSame($rawUpdatedAt, $institution->getRawOriginal('updated_at'), $case);
                $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case);
                $this->forgetAuthenticationGuards();
            }
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_dirty_patch_updates_only_allowed_fields_once_and_preserves_tenant_settings_users_tokens_and_lifecycle(): void
    {
        $creator = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create([
            'name' => 'Original School',
            'type' => InstitutionType::College,
            'status' => InstitutionStatus::Active,
            'contact_email' => 'original@example.uz',
            'contact_phone' => 'original phone',
            'address' => 'Original address',
            'description' => 'Original description',
            'created_by_user_id' => $creator->id,
            'deactivated_at' => null,
            'created_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
        ]);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $setting = InstitutionSetting::factory()->configuredEducationalPolicy()->create([
            'institution_id' => $institution->id,
            'updated_by_user_id' => $actor->id,
        ]);
        $this->createUserForRole(UserRole::Teacher, $institution);
        $otherInstitution = Institution::factory()->create(['name' => 'Other School']);
        $token = $this->tokenFor($actor);
        $protectedInstitutionBefore = $this->protectedInstitutionSnapshot($institution);
        $setting->refresh();
        $settingBefore = $setting->getRawOriginal();
        $usersBefore = $this->usersSnapshot($institution);
        $tokensBefore = $this->tableRowsSnapshot('personal_access_tokens');
        $otherInstitutionBefore = $this->rawInstitutionSnapshot($otherInstitution);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            DB::flushQueryLog();
            DB::enableQueryLog();

            try {
                $response = $this->rawJsonProfilePatch($token, [
                    'name' => '  Updated School  ',
                    'contact_email' => 'updated@example.uz',
                    'description' => null,
                ]);
                $queries = DB::getQueryLog();
            } finally {
                DB::disableQueryLog();
            }

            $this->assertSuccessfulPatch($response, $institution->id);
            $response->assertJsonPath('data.name', 'Updated School');
            $response->assertJsonPath('data.contact_email', 'updated@example.uz');
            $response->assertJsonPath('data.contact_phone', 'original phone');
            $response->assertJsonPath('data.address', 'Original address');
            $response->assertJsonPath('data.description', null);
            $response->assertJsonPath('data.updated_at', '2026-08-10T12:00:00Z');

            $institutionUpdates = $this->institutionUpdateQueries($queries);
            $this->assertCount(1, $institutionUpdates);
            $updateSql = strtolower($institutionUpdates[0]['query']);
            $this->assertStringContainsString('"name"', $updateSql);
            $this->assertStringContainsString('"contact_email"', $updateSql);
            $this->assertStringContainsString('"description"', $updateSql);
            $this->assertStringContainsString('"updated_at"', $updateSql);
            $setClause = Str::before($updateSql, ' where ');
            foreach (['"id"', '"type"', '"status"', '"created_by_user_id"', '"deactivated_at"', '"created_at"', '"contact_phone"', '"address"'] as $column) {
                $this->assertStringNotContainsString($column.' =', $setClause);
            }

            $institution->refresh();
            $this->assertSame($protectedInstitutionBefore, $this->protectedInstitutionSnapshot($institution));
            $this->assertSame($settingBefore, $setting->refresh()->getRawOriginal());
            $this->assertSame($usersBefore, $this->usersSnapshot($institution));
            $this->assertSame($tokensBefore, $this->tableRowsSnapshot('personal_access_tokens'));
            $this->assertSame($otherInstitutionBefore, $this->rawInstitutionSnapshot($otherInstitution));
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_tenant_like_headers_cannot_change_the_loaded_or_updated_institution(): void
    {
        $institution = Institution::factory()->create(['name' => 'Own School']);
        $otherInstitution = Institution::factory()->create(['name' => 'Foreign School']);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);
        $headers = [
            'HTTP_X_INSTITUTION_ID' => $otherInstitution->id,
            'HTTP_X_TENANT_ID' => $otherInstitution->id,
        ];
        $otherBefore = $this->rawInstitutionSnapshot($otherInstitution);

        $getResponse = $this->rawProfile('GET', $token, headers: $headers);
        $getResponse->assertOk()->assertJsonPath('data.id', $institution->id);
        $getResponse->assertJsonPath('data.name', 'Own School');

        $patchResponse = $this->rawProfile(
            'PATCH',
            $token,
            json_encode(['name' => 'Own School Updated'], JSON_THROW_ON_ERROR),
            headers: $headers,
        );
        $this->assertSuccessfulPatch($patchResponse, $institution->id);
        $patchResponse->assertJsonPath('data.name', 'Own School Updated');
        $this->assertSame('Own School Updated', $institution->refresh()->name);
        $this->assertSame($otherBefore, $this->rawInstitutionSnapshot($otherInstitution));
    }

    public function test_authentication_lifecycle_password_and_role_gates_have_required_precedence_without_writes(): void
    {
        $rowsBefore = $this->protectedRowsSnapshot();
        $this->assertErrorContract($this->rawProfile('GET'), 401, 'authentication_required');
        $this->assertErrorContract(
            $this->rawProfile('PATCH', content: '{"name":"Denied"}'),
            401,
            'authentication_required',
        );
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
        $this->forgetAuthenticationGuards();

        $institution = Institution::factory()->create();
        $inactiveUser = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertProfileGateWithoutWrites($inactiveUser, 403, 'user_inactive');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $inactiveInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $inactiveInstitution);
        $this->assertProfileGateWithoutWrites($inactiveInstitutionAdmin, 403, 'institution_inactive');

        $passwordIncompleteAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, [
            'must_change_password' => true,
        ]);
        $this->assertProfileGateWithoutWrites($passwordIncompleteAdmin, 403, 'password_change_required');

        foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole(
                $role,
                $role === UserRole::PlatformOwner ? null : $institution,
            );
            $this->assertProfileGateWithoutWrites($wrongRoleUser, 403, 'forbidden', $role->value);
        }
    }

    public function test_unexpected_profile_load_failure_uses_safe_server_error_without_writes_or_internal_details(): void
    {
        config(['app.debug' => false]);

        $institution = Institution::factory()->create();
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();
        $showProfile = Mockery::mock(ShowInstitutionProfile::class);
        $showProfile->shouldReceive('__invoke')
            ->once()
            ->with(Mockery::on(fn (mixed $value): bool => $value instanceof User && $value->is($actor)))
            ->andThrow(new RuntimeException('SQLSTATE load failure for tenant '.$institution->id.' actor '.$actor->id));
        $this->app->instance(ShowInstitutionProfile::class, $showProfile);

        $response = $this->rawProfile('GET', $token);
        $this->assertSafeServerError($response, [$institution->id, $actor->id, 'SQLSTATE', 'load failure']);
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot());
    }

    public function test_unexpected_profile_update_failure_uses_safe_server_error_without_writes_or_internal_details(): void
    {
        config(['app.debug' => false]);

        $institution = Institution::factory()->create(['name' => 'Unchanged School']);
        $actor = $this->createUserForRole(UserRole::InstitutionAdmin, $institution);
        $token = $this->tokenFor($actor);
        $rowsBefore = $this->protectedRowsSnapshot();
        $updateProfile = Mockery::mock(UpdateInstitutionProfile::class);
        $updateProfile->shouldReceive('__invoke')
            ->once()
            ->withArgs(fn (Institution $target, array $attributes): bool => $target->is($institution)
                && $attributes === ['name' => 'Failure Attempt'])
            ->andThrow(new RuntimeException('SQLSTATE update failure for tenant '.$institution->id.' actor '.$actor->id));
        $this->app->instance(UpdateInstitutionProfile::class, $updateProfile);

        $response = $this->rawJsonProfilePatch($token, ['name' => 'Failure Attempt']);
        $this->assertSafeServerError($response, [$institution->id, $actor->id, 'SQLSTATE', 'update failure']);
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

    private function rawJsonProfilePatch(string $token, array $payload): TestResponse
    {
        return $this->rawProfile(
            'PATCH',
            $token,
            json_encode($payload, JSON_THROW_ON_ERROR),
        );
    }

    /**
     * @param  array<string, mixed>  $query
     * @param  array<string, string>  $headers
     */
    private function rawProfile(
        string $method,
        ?string $token = null,
        string $content = '',
        array $query = [],
        array $headers = [],
    ): TestResponse {
        $uri = self::URI.($query === [] ? '' : '?'.http_build_query($query));
        $server = array_merge([
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
        ], $headers);

        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call($method, $uri, [], [], [], $server, $content);
    }

    private function tokenFor(User $user): string
    {
        return $user->createToken('institution-profile-api-test')->plainTextToken;
    }

    private function assertSuccessfulPatch(TestResponse $response, string $institutionId): void
    {
        $response->assertOk();
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame(self::PROFILE_KEYS, array_keys($response->json('data')));
        $this->assertSame($institutionId, $response->json('data.id'));
        $this->assertSame('Institution profile updated successfully.', $response->json('message'));
    }

    private function assertProfileGateWithoutWrites(
        User $user,
        int $status,
        string $code,
        string $case = '',
    ): void {
        $token = $this->tokenFor($user);
        $rowsBefore = $this->protectedRowsSnapshot();

        $this->assertErrorContract($this->rawProfile('GET', $token), $status, $code, $case.' GET');
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case.' GET');
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->rawProfile('PATCH', $token, '{"name":"Denied"}'),
            $status,
            $code,
            $case.' PATCH',
        );
        $this->assertSame($rowsBefore, $this->protectedRowsSnapshot(), $case.' PATCH');
        $this->forgetAuthenticationGuards();
    }

    /**
     * @param  list<string>  $internalDetails
     */
    private function assertSafeServerError(TestResponse $response, array $internalDetails): void
    {
        $decoded = $this->assertErrorContract($response, 500, 'server_error');
        $this->assertSame('An unexpected server error occurred.', $decoded->message);

        foreach (array_merge($internalDetails, ['trace', 'exception', 'vendor', 'app\\']) as $detail) {
            $this->assertStringNotContainsString($detail, $response->getContent());
        }
    }

    /**
     * @param  list<array{query: string, bindings: array<int, mixed>, time: float}>  $queries
     * @return list<array{query: string, bindings: array<int, mixed>, time: float}>
     */
    private function institutionUpdateQueries(array $queries): array
    {
        return array_values(array_filter(
            $queries,
            fn (array $query): bool => str_starts_with(strtolower(trim($query['query'])), 'update "institutions"'),
        ));
    }

    /**
     * @return array<string, list<array<string, mixed>>>
     */
    private function protectedRowsSnapshot(): array
    {
        return [
            'institutions' => $this->tableRowsSnapshot('institutions'),
            'institution_settings' => $this->tableRowsSnapshot('institution_settings', 'institution_id'),
            'users' => $this->tableRowsSnapshot('users'),
            'personal_access_tokens' => $this->tableRowsSnapshot('personal_access_tokens'),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function tableRowsSnapshot(string $table, string $orderBy = 'id'): array
    {
        return DB::table($table)
            ->orderBy($orderBy)
            ->get()
            ->map(fn (object $row): array => (array) $row)
            ->values()
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function rawInstitutionSnapshot(Institution $institution): array
    {
        return $institution->refresh()->getRawOriginal();
    }

    /**
     * @return array<string, mixed>
     */
    private function protectedInstitutionSnapshot(Institution $institution): array
    {
        $institution->refresh();

        return [
            'id' => $institution->id,
            'type' => $institution->type->value,
            'status' => $institution->status->value,
            'created_by_user_id' => $institution->created_by_user_id,
            'deactivated_at' => $institution->deactivated_at?->toJSON(),
            'created_at' => $institution->created_at?->toJSON(),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function usersSnapshot(Institution $institution): array
    {
        return User::query()
            ->where('institution_id', $institution->id)
            ->orderBy('id')
            ->get()
            ->map(fn (User $user): array => $user->getRawOriginal())
            ->values()
            ->all();
    }

    private function maximumLengthEmail(): string
    {
        return str_repeat('a', 64).'@'.str_repeat('b', 61).'.'.str_repeat('c', 61).'.'.str_repeat('d', 61).'.com';
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
