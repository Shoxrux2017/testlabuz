<?php

namespace Tests\Feature\Platform;

use App\Actions\Platform\CreatePlatformInstitution;
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

class PlatformInstitutionCreateApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/platform/institutions';

    private const SETTINGS_FAILURE_FUNCTION = 'testlabuz_fail_institution_settings_insert';

    private const SETTINGS_FAILURE_TRIGGER = 'testlabuz_fail_institution_settings_insert_trigger';

    public function test_post_route_is_registered_with_required_middleware_order(): void
    {
        $platformInstitutionCreateRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/platform/institutions')
            ->filter(fn (array $route): bool => in_array('POST', $route['methods'], true))
            ->values()
            ->all();

        $this->assertSame([
            [
                'methods' => ['POST'],
                'uri' => 'api/v1/platform/institutions',
                'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:platform_owner'],
            ],
        ], $platformInstitutionCreateRoutes);
    }

    public function test_active_password_complete_platform_owner_can_create_complete_active_institution(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'));

        try {
            $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

            $response = $this->authorizedPost($platformOwner, $this->validPayload([
                'name' => 'Example School',
                'type' => InstitutionType::School->value,
                'status' => InstitutionStatus::Active->value,
                'contact_email' => 'info@example.uz',
                'contact_phone' => '+998 90 123 45 67',
                'address' => 'Samarkand',
                'description' => 'Optional notes',
            ]));

            $response->assertCreated();
            $this->assertSame(['data', 'message'], array_keys($response->json()));
            $this->assertSame('Institution created successfully.', $response->json('message'));

            $data = $response->json('data');
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
            ], array_keys($data));
            $this->assertTrue(Str::isUuid($data['id']));
            $this->assertSame('Example School', $data['name']);
            $this->assertSame(InstitutionType::School->value, $data['type']);
            $this->assertSame(InstitutionStatus::Active->value, $data['status']);
            $this->assertSame('info@example.uz', $data['contact_email']);
            $this->assertSame('+998 90 123 45 67', $data['contact_phone']);
            $this->assertSame('Samarkand', $data['address']);
            $this->assertSame('Optional notes', $data['description']);
            $this->assertSame('2026-08-07T15:00:00Z', $data['created_at']);
            $this->assertSame('2026-08-07T15:00:00Z', $data['updated_at']);

            $institution = Institution::query()->findOrFail($data['id']);
            $this->assertSame($platformOwner->id, $institution->created_by_user_id);
            $this->assertSame(InstitutionStatus::Active, $institution->status);
            $this->assertNull($institution->deactivated_at);

            $this->assertSettingsInitializedFor($institution);
            $this->assertSame(1, Institution::query()->count());
            $this->assertSame(1, InstitutionSetting::query()->count());
            $this->assertSame(1, User::query()->count());

            $content = $response->getContent();
            $this->assertStringNotContainsString('created_by_user_id', $content);
            $this->assertStringNotContainsString('deactivated_at', $content);
            $this->assertStringNotContainsString('institution_settings', $content);
            $this->assertStringNotContainsString('acceptable_score_difference', $content);
            $this->assertStringNotContainsString('user_counts', $content);
            $this->assertStringNotContainsString('users', $content);
            $this->assertStringNotContainsString('meta', $content);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_valid_minimal_payload_persists_nullable_public_fields_as_null(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $response = $this->authorizedPost($platformOwner, $this->minimalPayload([
            'name' => 'Minimal Institution',
        ]));

        $response->assertCreated();
        $response->assertJsonPath('data.contact_email', null);
        $response->assertJsonPath('data.contact_phone', null);
        $response->assertJsonPath('data.address', null);
        $response->assertJsonPath('data.description', null);

        $institution = Institution::query()->findOrFail($response->json('data.id'));
        $this->assertNull($institution->contact_email);
        $this->assertNull($institution->contact_phone);
        $this->assertNull($institution->address);
        $this->assertNull($institution->description);
        $this->assertSettingsInitializedFor($institution);
    }

    public function test_initial_inactive_status_sets_server_deactivated_timestamp_and_same_settings_defaults(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-07 16:30:00', 'UTC'));

        try {
            $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

            $response = $this->authorizedPost($platformOwner, $this->minimalPayload([
                'name' => 'Inactive Institution',
                'status' => InstitutionStatus::Inactive->value,
            ]));

            $response->assertCreated();
            $response->assertJsonPath('data.status', InstitutionStatus::Inactive->value);
            $this->assertArrayNotHasKey('deactivated_at', $response->json('data'));

            $institution = Institution::query()->findOrFail($response->json('data.id'));
            $this->assertSame(InstitutionStatus::Inactive, $institution->status);
            $this->assertNotNull($institution->deactivated_at);
            $this->assertSame('2026-08-07T16:30:00.000000Z', $institution->deactivated_at->toJSON());
            $this->assertSettingsInitializedFor($institution);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_authentication_account_password_and_role_gates_create_no_data(): void
    {
        $this->assertNoInstitutionPersistenceChange(
            $this->institutionPersistenceCounts(),
            fn (): TestResponse => $this->postJson(self::URI, $this->validPayload()),
            401,
            'authentication_required',
        );

        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertNoInstitutionPersistenceChange(
            $this->institutionPersistenceCounts(),
            fn (): TestResponse => $this->authorizedPost($inactivePlatformOwner, $this->validPayload()),
            403,
            'user_inactive',
        );
        $this->forgetAuthenticationGuards();

        $passwordIncompletePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'must_change_password' => true,
        ]);
        $this->assertNoInstitutionPersistenceChange(
            $this->institutionPersistenceCounts(),
            fn (): TestResponse => $this->authorizedPost($passwordIncompletePlatformOwner, $this->validPayload()),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole($role);

            $this->assertNoInstitutionPersistenceChange(
                $this->institutionPersistenceCounts(),
                fn (): TestResponse => $this->authorizedPost($wrongRoleUser, $this->validPayload([
                    'name' => 'Denied '.$role->value,
                ])),
                403,
                'forbidden',
                $role->value,
            );
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_client_supplied_role_actor_query_and_body_authority_create_no_data(): void
    {
        $teacher = $this->createUserForRole(UserRole::Teacher);
        $spoofedToken = $this->tokenFor($teacher, ['platform_owner', 'role:platform_owner']);

        $this->assertNoInstitutionPersistenceChange(
            $this->institutionPersistenceCounts(),
            fn (): TestResponse => $this->withToken($spoofedToken)
                ->withHeaders([
                    'X-Role' => UserRole::PlatformOwner->value,
                    'X-User-Role' => UserRole::PlatformOwner->value,
                ])
                ->json('POST', self::URI.'?role='.UserRole::PlatformOwner->value, $this->validPayload([
                    'role' => UserRole::PlatformOwner->value,
                ])),
            403,
            'forbidden',
        );
        $this->forgetAuthenticationGuards();

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $before = $this->institutionPersistenceCounts();
        $queryResponse = $this->authorizedPost(
            $platformOwner,
            $this->validPayload(['name' => 'Query Actor Override']),
            self::URI.'?created_by_user_id='.Str::uuid()->toString(),
        );

        $decoded = $this->assertErrorContract($queryResponse, 422, 'validation_failed');
        $this->assertObjectHasProperty('created_by_user_id', $decoded->errors);
        $this->assertInstitutionPersistenceCounts($before);
    }

    public function test_query_parameters_cannot_supply_override_or_extend_create_payload(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $queryOnlyResponse = $this->authorizedRawJsonPost(
            $platformOwner,
            '{}',
            self::URI.'?'.http_build_query([
                'name' => 'Query Only Institution',
                'type' => InstitutionType::School->value,
                'status' => InstitutionStatus::Active->value,
                'contact_email' => 'query-only@example.uz',
            ]),
        );
        $decodedQueryOnly = $this->assertErrorContract($queryOnlyResponse, 422, 'validation_failed');
        $this->assertObjectHasProperty('name', $decodedQueryOnly->errors);
        $this->assertObjectHasProperty('type', $decodedQueryOnly->errors);
        $this->assertObjectHasProperty('status', $decodedQueryOnly->errors);
        $this->assertObjectHasProperty('contact_email', $decodedQueryOnly->errors);
        $this->assertSame(0, Institution::query()->count());
        $this->assertSame(0, InstitutionSetting::query()->count());

        $conflictingQueryResponse = $this->authorizedPost(
            $platformOwner,
            $this->validPayload([
                'name' => 'Body Institution',
                'type' => InstitutionType::School->value,
                'status' => InstitutionStatus::Active->value,
                'contact_email' => 'body@example.uz',
            ]),
            self::URI.'?'.http_build_query([
                'name' => 'Query Override Institution',
                'type' => InstitutionType::University->value,
                'status' => InstitutionStatus::Inactive->value,
                'contact_email' => 'query-override@example.uz',
            ]),
        );
        $decodedConflictingQuery = $this->assertErrorContract($conflictingQueryResponse, 422, 'validation_failed');
        $this->assertObjectHasProperty('name', $decodedConflictingQuery->errors);
        $this->assertObjectHasProperty('type', $decodedConflictingQuery->errors);
        $this->assertObjectHasProperty('status', $decodedConflictingQuery->errors);
        $this->assertObjectHasProperty('contact_email', $decodedConflictingQuery->errors);
        $this->assertSame(0, Institution::query()->count());
        $this->assertSame(0, InstitutionSetting::query()->count());
        $this->assertDatabaseMissing('institutions', ['name' => 'Body Institution']);
        $this->assertDatabaseMissing('institutions', ['name' => 'Query Override Institution']);

        foreach ([
            'created_by_user_id' => Str::uuid()->toString(),
            'role' => UserRole::PlatformOwner->value,
            'timezone' => CreatePlatformInstitution::DEFAULT_TIMEZONE,
        ] as $field => $value) {
            $before = $this->institutionPersistenceCounts();

            $decoded = $this->assertErrorContract(
                $this->authorizedPost(
                    $platformOwner,
                    $this->validPayload(['name' => 'Disallowed Query '.$field]),
                    self::URI.'?'.http_build_query([$field => $value]),
                ),
                422,
                'validation_failed',
                $field,
            );

            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertInstitutionPersistenceCounts($before);
        }

        $validBodyOnly = $this->authorizedPost($platformOwner, $this->validPayload([
            'name' => 'Body Only Institution',
            'type' => InstitutionType::School->value,
            'status' => InstitutionStatus::Active->value,
            'contact_email' => 'body-only@example.uz',
        ]));
        $validBodyOnly->assertCreated();
        $validBodyOnly->assertJsonPath('message', 'Institution created successfully.');
        $validBodyOnly->assertJsonPath('data.name', 'Body Only Institution');
        $validBodyOnly->assertJsonPath('data.type', InstitutionType::School->value);
        $validBodyOnly->assertJsonPath('data.status', InstitutionStatus::Active->value);
        $validBodyOnly->assertJsonPath('data.contact_email', 'body-only@example.uz');
        $this->assertSame(1, Institution::query()->where('name', 'Body Only Institution')->count());
        $this->assertSame(1, Institution::query()->count());
        $this->assertSame(1, InstitutionSetting::query()->count());
    }

    public function test_missing_required_and_non_object_payloads_fail_validation_without_writes(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        foreach (['name', 'type', 'status'] as $field) {
            $payload = $this->validPayload(['name' => 'Missing '.$field]);
            unset($payload[$field]);

            $before = $this->institutionPersistenceCounts();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $payload),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertInstitutionPersistenceCounts($before);
        }

        $arrayPayloadResponse = $this->withToken($this->tokenFor($platformOwner))
            ->json('POST', self::URI, [$this->validPayload(['name' => 'Array Root'])]);
        $decodedArray = $this->assertErrorContract($arrayPayloadResponse, 422, 'validation_failed');
        $this->assertObjectHasProperty('body', $decodedArray->errors);

        $scalarPayloadResponse = $this->withToken($this->tokenFor($platformOwner))
            ->call(
                'POST',
                self::URI,
                [],
                [],
                [],
                ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'],
                '"scalar"',
            );
        $decodedScalar = $this->assertErrorContract($scalarPayloadResponse, 422, 'validation_failed');
        $this->assertObjectHasProperty('body', $decodedScalar->errors);
        $this->assertSame(0, InstitutionSetting::query()->count());
    }

    public function test_name_validation_trims_outer_whitespace_and_enforces_non_empty_and_length(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $trimmed = $this->authorizedPost($platformOwner, $this->minimalPayload([
            'name' => '  Trimmed Institution  ',
        ]));
        $trimmed->assertCreated();
        $trimmed->assertJsonPath('data.name', 'Trimmed Institution');
        $this->assertDatabaseHas('institutions', [
            'id' => $trimmed->json('data.id'),
            'name' => 'Trimmed Institution',
        ]);

        $maxName = str_repeat('A', 200);
        $this->authorizedPost($platformOwner, $this->minimalPayload([
            'name' => $maxName,
        ]))
            ->assertCreated()
            ->assertJsonPath('data.name', $maxName);

        foreach ([
            'whitespace only' => ['name' => '   ', 'field' => 'name'],
            'name too long' => ['name' => str_repeat('B', 201), 'field' => 'name'],
        ] as $case => $input) {
            $before = $this->institutionPersistenceCounts();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $this->minimalPayload(['name' => $input['name']])),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($input['field'], $decoded->errors, $case);
            $this->assertInstitutionPersistenceCounts($before);
        }
    }

    public function test_current_institution_type_and_status_enums_are_enforced(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        foreach (InstitutionType::cases() as $type) {
            $this->authorizedPost($platformOwner, $this->minimalPayload([
                'name' => 'Type '.$type->value,
                'type' => $type->value,
            ]))
                ->assertCreated()
                ->assertJsonPath('data.type', $type->value);
        }

        foreach (InstitutionStatus::cases() as $status) {
            $this->authorizedPost($platformOwner, $this->minimalPayload([
                'name' => 'Status '.$status->value,
                'status' => $status->value,
            ]))
                ->assertCreated()
                ->assertJsonPath('data.status', $status->value);
        }

        foreach ([
            'unknown type' => ['type' => 'academy', 'field' => 'type'],
            'unknown status' => ['status' => 'suspended', 'field' => 'status'],
        ] as $case => $input) {
            $before = $this->institutionPersistenceCounts();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $this->minimalPayload([
                    'name' => $case,
                    $input['field'] => $input[$input['field']],
                ])),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($input['field'], $decoded->errors, $case);
            $this->assertInstitutionPersistenceCounts($before);
        }
    }

    public function test_optional_public_fields_validate_without_invented_phone_or_text_limits(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $longAddress = str_repeat('A', 1200);
        $longDescription = str_repeat('D', 1300);

        $this->authorizedPost($platformOwner, $this->validPayload([
            'name' => 'Public Optional Fields',
            'contact_email' => 'contact@example.uz',
            'contact_phone' => 'local phone ext 123',
            'address' => $longAddress,
            'description' => $longDescription,
        ]))
            ->assertCreated()
            ->assertJsonPath('data.contact_phone', 'local phone ext 123')
            ->assertJsonPath('data.address', $longAddress)
            ->assertJsonPath('data.description', $longDescription);

        $this->authorizedPost($platformOwner, $this->validPayload([
            'name' => 'Phone Length',
            'contact_phone' => str_repeat('9', 50),
        ]))
            ->assertCreated()
            ->assertJsonPath('data.contact_phone', str_repeat('9', 50));

        foreach ([
            'malformed email' => ['contact_email' => 'not an email', 'field' => 'contact_email'],
            'email too long' => ['contact_email' => str_repeat('a', 245).'@example.uz', 'field' => 'contact_email'],
            'phone too long' => ['contact_phone' => str_repeat('9', 51), 'field' => 'contact_phone'],
            'address array' => ['address' => ['Samarkand'], 'field' => 'address'],
            'address object' => ['address' => ['city' => 'Samarkand'], 'field' => 'address'],
            'description bool' => ['description' => true, 'field' => 'description'],
            'nullable string bool' => ['contact_phone' => false, 'field' => 'contact_phone'],
        ] as $case => $input) {
            $before = $this->institutionPersistenceCounts();
            $field = $input['field'];
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $this->validPayload([
                    'name' => $case,
                    $field => $input[$field],
                ])),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $case);
            $this->assertInstitutionPersistenceCounts($before);
        }

        $this->authorizedPost($platformOwner, $this->validPayload([
            'name' => 'Nullable Public Fields',
            'contact_email' => null,
            'contact_phone' => null,
            'address' => null,
            'description' => null,
        ]))
            ->assertCreated()
            ->assertJsonPath('data.contact_email', null)
            ->assertJsonPath('data.contact_phone', null)
            ->assertJsonPath('data.address', null)
            ->assertJsonPath('data.description', null);
    }

    public function test_disallowed_system_settings_policy_and_learning_keys_are_rejected_without_writes(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $disallowedFields = [
            'id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'created_by_user_id' => $platformOwner->id,
            'deactivated_at' => '2026-08-07T15:00:00Z',
            'created_at' => '2026-08-07T15:00:00Z',
            'updated_at' => '2026-08-07T15:00:00Z',
            'settings' => ['timezone' => CreatePlatformInstitution::DEFAULT_TIMEZONE],
            'timezone' => CreatePlatformInstitution::DEFAULT_TIMEZONE,
            'learning_material_max_mb' => CreatePlatformInstitution::DEFAULT_LEARNING_MATERIAL_MAX_MB,
            'student_submission_max_mb' => CreatePlatformInstitution::DEFAULT_STUDENT_SUBMISSION_MAX_MB,
            'acceptable_score_difference' => null,
            'blitz_timer_start_mode' => 'synchronized',
            'student_result_release_mode' => 'automatic',
            'parent_result_release_mode' => 'with_student',
            'role' => UserRole::PlatformOwner->value,
            'user_counts' => ['total' => 0, 'active' => 0],
        ];

        foreach ($disallowedFields as $field => $value) {
            $before = $this->institutionPersistenceCounts();
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, array_merge($this->validPayload([
                    'name' => 'Disallowed '.$field,
                ]), [
                    $field => $value,
                ])),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertInstitutionPersistenceCounts($before);
        }
    }

    public function test_duplicate_institution_names_are_not_rejected_by_invented_uniqueness_rule(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $first = $this->authorizedPost($platformOwner, $this->minimalPayload([
            'name' => 'Same Name Institution',
        ]));
        $second = $this->authorizedPost($platformOwner, $this->minimalPayload([
            'name' => 'Same Name Institution',
        ]));

        $first->assertCreated();
        $second->assertCreated();
        $this->assertSame(2, Institution::query()->where('name', 'Same Name Institution')->count());
        $this->assertSame(2, InstitutionSetting::query()->count());
    }

    public function test_settings_persistence_failure_rolls_back_institution_and_returns_server_error(): void
    {
        config(['app.debug' => false]);

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $before = $this->institutionPersistenceCounts();

        $this->installSettingsFailureTrigger();

        try {
            $response = $this->authorizedPost($platformOwner, $this->validPayload([
                'name' => 'Rollback Institution',
            ]));

            $decoded = $this->assertErrorContract($response, 500, 'server_error');
            $this->assertSame('An unexpected server error occurred.', $decoded->message);

            $content = $response->getContent();
            $this->assertStringNotContainsString('controlled institution settings insert failure', $content);
            $this->assertStringNotContainsString('institution_settings', $content);
            $this->assertStringNotContainsString('SQLSTATE', $content);
            $this->assertStringNotContainsString('trace', $content);
            $this->assertInstitutionPersistenceCounts($before);
        } finally {
            $this->dropSettingsFailureTrigger();
        }

        $this->assertNull(DB::selectOne(
            'select tgname from pg_trigger where tgname = ?',
            [self::SETTINGS_FAILURE_TRIGGER],
        ));
        $this->assertNull(DB::selectOne(
            'select proname from pg_proc where proname = ?',
            [self::SETTINGS_FAILURE_FUNCTION],
        ));
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Example School',
            'type' => InstitutionType::School->value,
            'contact_email' => 'info@example.uz',
            'contact_phone' => '+998 90 123 45 67',
            'address' => 'Samarkand',
            'description' => 'Optional notes',
            'status' => InstitutionStatus::Active->value,
        ], $overrides);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function minimalPayload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Example School',
            'type' => InstitutionType::School->value,
            'status' => InstitutionStatus::Active->value,
        ], $overrides);
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

    private function authorizedPost(User $user, array $payload, string $uri = self::URI): TestResponse
    {
        return $this->withToken($this->tokenFor($user))->postJson($uri, $payload);
    }

    private function authorizedRawJsonPost(User $user, string $content, string $uri = self::URI): TestResponse
    {
        return $this->call(
            'POST',
            $uri,
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$this->tokenFor($user),
            ],
            $content,
        );
    }

    /**
     * @param  list<string>  $abilities
     */
    private function tokenFor(User $user, array $abilities = ['*']): string
    {
        return $user->createToken('platform-institution-create-api-test', $abilities)->plainTextToken;
    }

    /**
     * @return array{institutions: int, settings: int}
     */
    private function institutionPersistenceCounts(): array
    {
        return [
            'institutions' => Institution::query()->count(),
            'settings' => InstitutionSetting::query()->count(),
        ];
    }

    /**
     * @param  array{institutions: int, settings: int}  $expected
     */
    private function assertInstitutionPersistenceCounts(array $expected): void
    {
        $this->assertSame($expected['institutions'], Institution::query()->count());
        $this->assertSame($expected['settings'], InstitutionSetting::query()->count());
    }

    /**
     * @param  array{institutions: int, settings: int}  $before
     */
    private function assertNoInstitutionPersistenceChange(
        array $before,
        callable $request,
        int $status,
        string $code,
        string $case = '',
    ): void {
        $this->assertErrorContract($request(), $status, $code, $case);
        $this->assertInstitutionPersistenceCounts($before);
    }

    private function assertSettingsInitializedFor(Institution $institution): void
    {
        $setting = InstitutionSetting::query()->whereKey($institution->id)->firstOrFail();

        $this->assertSame($institution->id, $setting->institution_id);
        $this->assertSame(CreatePlatformInstitution::DEFAULT_TIMEZONE, $setting->timezone);
        $this->assertSame(CreatePlatformInstitution::DEFAULT_LEARNING_MATERIAL_MAX_MB, $setting->learning_material_max_mb);
        $this->assertSame(CreatePlatformInstitution::DEFAULT_STUDENT_SUBMISSION_MAX_MB, $setting->student_submission_max_mb);
        $this->assertNull($setting->acceptable_score_difference);
        $this->assertNull($setting->blitz_timer_start_mode);
        $this->assertNull($setting->student_result_release_mode);
        $this->assertNull($setting->parent_result_release_mode);
        $this->assertNull($setting->updated_by_user_id);
    }

    private function installSettingsFailureTrigger(): void
    {
        DB::unprepared(sprintf(
            <<<'SQL'
create or replace function %s()
returns trigger
language plpgsql
as $$
begin
    raise exception 'controlled institution settings insert failure';
end;
$$;

drop trigger if exists %s on institution_settings;

create trigger %s
before insert on institution_settings
for each row
execute function %s();
SQL,
            self::SETTINGS_FAILURE_FUNCTION,
            self::SETTINGS_FAILURE_TRIGGER,
            self::SETTINGS_FAILURE_TRIGGER,
            self::SETTINGS_FAILURE_FUNCTION,
        ));
    }

    private function dropSettingsFailureTrigger(): void
    {
        DB::unprepared(sprintf(
            <<<'SQL'
drop trigger if exists %s on institution_settings;
drop function if exists %s();
SQL,
            self::SETTINGS_FAILURE_TRIGGER,
            self::SETTINGS_FAILURE_FUNCTION,
        ));
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
