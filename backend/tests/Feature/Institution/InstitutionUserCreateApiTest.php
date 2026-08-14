<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\CreateInstitutionUser;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class InstitutionUserCreateApiTest extends TestCase
{
    use RefreshDatabase;

    private const CREATE_URI = '/api/v1/institution/users';

    private const INITIAL_PASSWORD = '  Initial user password 93!  ';

    private const NEW_PASSWORD = 'Changed user password 51!';

    public function test_create_route_is_registered_once_with_required_middleware_order(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/institution/users')
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
                'methods' => ['POST'],
                'uri' => 'api/v1/institution/users',
                'middleware' => $middleware,
            ],
        ], $routes);
    }

    public function test_teacher_student_and_parent_creation_persists_exact_server_owned_state_and_resource(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 09:30:00', 'UTC'));

        try {
            $institution = Institution::factory()->create();
            $otherInstitution = Institution::factory()->create();
            $setting = InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
            $actor = $this->institutionAdmin($institution);
            $existingUser = User::factory()->teacher($institution)->create([
                'login_name' => 'existing_user',
                'must_change_password' => false,
            ]);
            $token = $this->tokenFor($actor);

            $institutionRowsBefore = $this->institutionRowsSnapshot();
            $settingRowsBefore = $this->settingRowsSnapshot();
            $existingUserBefore = User::query()->findOrFail($existingUser->id)->getRawOriginal();
            $actorBefore = User::query()->findOrFail($actor->id)->getRawOriginal();
            $tokenRowsBefore = $this->tokenRowsSnapshot();

            foreach ([UserRole::Teacher, UserRole::Student, UserRole::Parent] as $index => $role) {
                $loginName = $role->value.'_created';
                $payload = $this->validPayload([
                    'role' => $role->value,
                    'full_name' => '  '.ucfirst($role->value).' Created  ',
                    'login_name' => '  '.$loginName.'  ',
                    'email' => 'shared@example.uz',
                    'phone' => '  +998901234567  ',
                ]);

                $response = $this->authorizedJsonPost($token, $payload);

                $response->assertCreated();
                $this->assertSame(['data', 'message'], array_keys($response->json()));
                $this->assertSame('Institution user created successfully.', $response->json('message'));
                $this->assertSame($this->resourceKeys(), array_keys($response->json('data')));
                $this->assertTrue(Str::isUuid((string) $response->json('data.id')));
                $this->assertSame($role->value, $response->json('data.role'));
                $this->assertSame(ucfirst($role->value).' Created', $response->json('data.full_name'));
                $this->assertSame($loginName, $response->json('data.login_name'));
                $this->assertSame('shared@example.uz', $response->json('data.email'));
                $this->assertSame('+998901234567', $response->json('data.phone'));
                $this->assertTrue($response->json('data.is_active'));
                $this->assertTrue($response->json('data.must_change_password'));
                $this->assertNull($response->json('data.last_login_at'));
                $this->assertNull($response->json('data.deactivated_at'));
                $this->assertSame('2026-08-14T09:30:00Z', $response->json('data.created_at'));
                $this->assertSame('2026-08-14T09:30:00Z', $response->json('data.updated_at'));

                $createdUser = User::query()->findOrFail($response->json('data.id'));
                $this->assertSame($institution->id, $createdUser->institution_id);
                $this->assertSame($actor->id, $createdUser->created_by_user_id);
                $this->assertSame($role, $createdUser->role);
                $this->assertTrue($createdUser->is_active);
                $this->assertTrue($createdUser->must_change_password);
                $this->assertNull($createdUser->last_login_at);
                $this->assertNull($createdUser->deactivated_at);
                $this->assertTrue(Hash::check(self::INITIAL_PASSWORD, $createdUser->password));
                $this->assertFalse(Hash::check(trim(self::INITIAL_PASSWORD), $createdUser->password));
                $this->assertSame($index + 1, User::query()->where('created_by_user_id', $actor->id)->count());

                $content = $response->getContent();
                foreach ([
                    self::INITIAL_PASSWORD,
                    $createdUser->password,
                    'institution_id',
                    'created_by_user_id',
                    'password_hash',
                    'remember_token',
                    'permissions',
                    'abilities',
                    'tokens',
                    'relationships',
                    'groups',
                    'settings',
                    'learning_data',
                    'meta',
                    'links',
                ] as $forbiddenText) {
                    $this->assertStringNotContainsString($forbiddenText, $content, $forbiddenText);
                }
            }

            $this->assertSame(3, User::query()->where('institution_id', $institution->id)->where('email', 'shared@example.uz')->count());
            $this->assertSame(3, User::query()->where('institution_id', $institution->id)->where('phone', '+998901234567')->count());
            $this->assertSame($institutionRowsBefore, $this->institutionRowsSnapshot());
            $this->assertSame($settingRowsBefore, $this->settingRowsSnapshot());
            $this->assertSame($existingUserBefore, User::query()->findOrFail($existingUser->id)->getRawOriginal());
            $this->assertSame($actorBefore, User::query()->findOrFail($actor->id)->getRawOriginal());
            $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot());
            $this->assertSame(0, User::query()->where('institution_id', $otherInstitution->id)->whereIn('role', $this->managedRoles())->count());

            $nullableResponse = $this->authorizedJsonPost($token, $this->validPayload([
                'role' => UserRole::Teacher->value,
                'login_name' => 'nullable_contacts',
                'email' => null,
                'phone' => null,
            ]));
            $nullableResponse->assertCreated()->assertJsonPath('data.email', null)->assertJsonPath('data.phone', null);

            $omittedResponse = $this->authorizedJsonPost($token, array_diff_key($this->validPayload([
                'role' => UserRole::Student->value,
                'login_name' => 'omitted_contacts',
            ]), ['email' => true, 'phone' => true]));
            $omittedResponse->assertCreated()->assertJsonPath('data.email', null)->assertJsonPath('data.phone', null);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_normalization_type_and_boundary_validation_is_exact_and_atomic(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $token = $this->tokenFor($actor);

        $validBoundaryCases = [
            'full name 200' => ['full_name' => str_repeat('F', 200), 'login_name' => 'boundary_full_name'],
            'login name 191' => ['full_name' => 'Login Boundary', 'login_name' => str_repeat('l', 191)],
            'email 254' => ['login_name' => 'boundary_email', 'email' => $this->emailOfLength254()],
            'phone 50' => ['login_name' => 'boundary_phone', 'phone' => str_repeat('5', 50)],
            'password 8' => ['login_name' => 'boundary_password_min', 'password' => '12345678'],
            'password 255' => ['login_name' => 'boundary_password_max', 'password' => str_repeat('p', 255)],
        ];

        foreach ($validBoundaryCases as $case => $overrides) {
            $response = $this->authorizedJsonPost($token, $this->validPayload($overrides));
            $response->assertCreated($case);
        }

        $invalidCases = [
            'role missing' => [array_diff_key($this->validPayload(), ['role' => true]), 'role'],
            'role null' => [$this->validPayload(['role' => null]), 'role'],
            'role array' => [$this->validPayload(['role' => ['teacher']]), 'role'],
            'role platform owner' => [$this->validPayload(['role' => UserRole::PlatformOwner->value]), 'role'],
            'role institution admin' => [$this->validPayload(['role' => UserRole::InstitutionAdmin->value]), 'role'],
            'role whitespace' => [$this->validPayload(['role' => ' teacher ']), 'role'],
            'role uppercase' => [$this->validPayload(['role' => 'TEACHER']), 'role'],
            'full name missing' => [array_diff_key($this->validPayload(), ['full_name' => true]), 'full_name'],
            'full name blank' => [$this->validPayload(['full_name' => '   ']), 'full_name'],
            'full name array' => [$this->validPayload(['full_name' => ['Teacher']]), 'full_name'],
            'full name 201' => [$this->validPayload(['full_name' => str_repeat('F', 201)]), 'full_name'],
            'login missing' => [array_diff_key($this->validPayload(), ['login_name' => true]), 'login_name'],
            'login blank' => [$this->validPayload(['login_name' => '   ']), 'login_name'],
            'login boolean' => [$this->validPayload(['login_name' => true]), 'login_name'],
            'login 192' => [$this->validPayload(['login_name' => str_repeat('l', 192)]), 'login_name'],
            'email empty' => [$this->validPayload(['email' => '']), 'email'],
            'email whitespace' => [$this->validPayload(['email' => '   ']), 'email'],
            'email padded' => [$this->validPayload(['email' => ' valid@example.uz ']), 'email'],
            'email invalid' => [$this->validPayload(['email' => 'not-an-email']), 'email'],
            'email boolean' => [$this->validPayload(['email' => false]), 'email'],
            'email 255' => [$this->validPayload(['email' => $this->emailOfLength254().'x']), 'email'],
            'phone empty' => [$this->validPayload(['phone' => '']), 'phone'],
            'phone whitespace' => [$this->validPayload(['phone' => '   ']), 'phone'],
            'phone array' => [$this->validPayload(['phone' => ['+998']]), 'phone'],
            'phone 51' => [$this->validPayload(['phone' => str_repeat('5', 51)]), 'phone'],
            'password missing' => [array_diff_key($this->validPayload(), ['password' => true]), 'password'],
            'password array' => [$this->validPayload(['password' => ['password']]), 'password'],
            'password 7' => [$this->validPayload(['password' => '1234567']), 'password'],
            'password 256' => [$this->validPayload(['password' => str_repeat('p', 256)]), 'password'],
        ];

        foreach ($invalidCases as $case => [$payload, $expectedField]) {
            $userRowsBefore = $this->userRowsSnapshot();
            $tokenRowsBefore = $this->tokenRowsSnapshot();
            $decoded = $this->assertErrorContract($this->authorizedJsonPost($token, $payload), 422, 'validation_failed', $case);
            $this->assertObjectHasProperty($expectedField, $decoded->errors, $case);
            $this->assertSame($userRowsBefore, $this->userRowsSnapshot(), $case);
            $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot(), $case);
        }

        $password = "  unchanged\tpassword!  ";
        $passwordResponse = $this->authorizedJsonPost($token, $this->validPayload([
            'login_name' => 'exact_password_bytes',
            'password' => $password,
        ]));
        $passwordResponse->assertCreated();
        $passwordUser = User::query()->where('login_name', 'exact_password_bytes')->firstOrFail();
        $this->assertTrue(Hash::check($password, $passwordUser->password));
        $this->assertFalse(Hash::check(trim($password), $passwordUser->password));
    }

    public function test_body_transport_unknown_protected_and_query_inputs_are_rejected_without_side_effects(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $token = $this->tokenFor($actor);

        $bodyCases = [
            'absent' => ['', 'application/json'],
            'whitespace' => [" \r\n\t ", 'application/json'],
            'malformed' => ['{"role":', 'application/json'],
            'scalar' => ['"teacher"', 'application/json'],
            'array' => ['[]', 'application/json'],
            'null' => ['null', 'application/json'],
            'form encoded' => ['role=teacher&full_name=Teacher', 'application/x-www-form-urlencoded'],
            'multipart' => ['--boundary', 'multipart/form-data; boundary=boundary'],
            'text' => [json_encode($this->validPayload(), JSON_THROW_ON_ERROR), 'text/plain'],
            'json suffix media' => [json_encode($this->validPayload(), JSON_THROW_ON_ERROR), 'application/problem+json'],
        ];

        foreach ($bodyCases as $case => [$content, $contentType]) {
            $userRowsBefore = $this->userRowsSnapshot();
            $tokenRowsBefore = $this->tokenRowsSnapshot();
            $decoded = $this->assertErrorContract(
                $this->authorizedRawPost($token, $content, $contentType),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($userRowsBefore, $this->userRowsSnapshot(), $case);
            $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot(), $case);
        }

        $emptyObject = $this->authorizedRawPost($token, '{}');
        $emptyDecoded = $this->assertErrorContract($emptyObject, 422, 'validation_failed', 'empty object');
        $this->assertObjectNotHasProperty('body', $emptyDecoded->errors);
        foreach (['role', 'full_name', 'login_name', 'password'] as $requiredField) {
            $this->assertObjectHasProperty($requiredField, $emptyDecoded->errors);
        }

        $protectedInputs = [
            'id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'created_by_user_id' => Str::uuid()->toString(),
            'is_active' => false,
            'must_change_password' => false,
            'last_login_at' => '2026-08-14T09:30:00Z',
            'deactivated_at' => '2026-08-14T09:30:00Z',
            'created_at' => '2026-08-14T09:30:00Z',
            'updated_at' => '2026-08-14T09:30:00Z',
            'password_confirmation' => self::INITIAL_PASSWORD,
            'permissions' => ['*'],
            'abilities' => ['*'],
            'token' => 'forged-token',
            'tokens' => ['forged-token'],
            'institution' => ['id' => Str::uuid()->toString()],
            'creator' => ['id' => Str::uuid()->toString()],
            'relationships' => [],
            'groups' => [],
            'settings' => [],
            'learning_data' => [],
            'arbitrary_unknown' => 'not-allowed',
        ];

        foreach ($protectedInputs as $field => $value) {
            $userRowsBefore = $this->userRowsSnapshot();
            $decoded = $this->assertErrorContract($this->authorizedJsonPost($token, array_merge(
                $this->validPayload(['login_name' => 'protected_'.$field]),
                [$field => $value],
            )), 422, 'validation_failed', $field);
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertSame($userRowsBefore, $this->userRowsSnapshot(), $field);
        }

        foreach (array_merge($this->allowedInputKeys(), ['institution_id', 'created_by_user_id', 'unknown']) as $queryKey) {
            $userRowsBefore = $this->userRowsSnapshot();
            $decoded = $this->assertErrorContract(
                $this->authorizedJsonPost($token, $this->validPayload([
                    'login_name' => 'query_'.str_replace('_', '', $queryKey),
                ]), [$queryKey => 'override']),
                422,
                'validation_failed',
                'query '.$queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($userRowsBefore, $this->userRowsSnapshot(), $queryKey);
        }
    }

    public function test_global_login_conflicts_and_controlled_unique_race_use_safe_field_validation(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $token = $this->tokenFor($actor);

        User::factory()->teacher($institution)->create(['login_name' => 'same_tenant_duplicate']);
        User::factory()->parent($otherInstitution)->create(['login_name' => 'foreign_tenant_duplicate']);
        User::factory()->platformOwner()->create(['login_name' => 'platform_duplicate']);

        foreach (['same_tenant_duplicate', 'foreign_tenant_duplicate', 'platform_duplicate'] as $loginName) {
            $userRowsBefore = $this->userRowsSnapshot();
            $decoded = $this->assertErrorContract($this->authorizedJsonPost($token, $this->validPayload([
                'login_name' => $loginName,
            ])), 422, 'validation_failed', $loginName);
            $this->assertObjectHasProperty('login_name', $decoded->errors);
            $this->assertSame($userRowsBefore, $this->userRowsSnapshot(), $loginName);
            $this->assertNoInternalOrPasswordDisclosure($decoded, self::INITIAL_PASSWORD);
        }

        $this->app->instance(CreateInstitutionUser::class, new class extends CreateInstitutionUser
        {
            public function __invoke(
                User $actor,
                UserRole $role,
                string $fullName,
                string $loginName,
                ?string $email,
                ?string $phone,
                string $password,
            ): User {
                User::query()->create([
                    'institution_id' => $actor->institution_id,
                    'role' => $role,
                    'full_name' => 'Concurrent Winner',
                    'login_name' => $loginName,
                    'email' => null,
                    'phone' => null,
                    'password' => Hash::make('winner-password'),
                    'is_active' => true,
                    'must_change_password' => true,
                    'last_login_at' => null,
                    'deactivated_at' => null,
                    'created_by_user_id' => $actor->id,
                ]);

                return parent::__invoke($actor, $role, $fullName, $loginName, $email, $phone, $password);
            }
        });

        $raceLoginName = 'controlled_race_login';
        $tokenRowsBefore = $this->tokenRowsSnapshot();
        $response = $this->authorizedJsonPost($token, $this->validPayload(['login_name' => $raceLoginName]));
        $decoded = $this->assertErrorContract($response, 422, 'validation_failed', 'race loser');
        $this->assertObjectHasProperty('login_name', $decoded->errors);
        $this->assertSame(1, User::query()->where('login_name', $raceLoginName)->count());
        $this->assertSame('Concurrent Winner', User::query()->where('login_name', $raceLoginName)->value('full_name'));
        $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot());
        $this->assertNoInternalOrPasswordDisclosure($decoded, self::INITIAL_PASSWORD);
    }

    public function test_unexpected_database_failure_after_insert_rolls_back_and_returns_safe_server_error(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $token = $this->tokenFor($actor);
        $failedLoginName = 'rollback_after_insert';
        $userRowsBefore = $this->userRowsSnapshot();
        $tokenRowsBefore = $this->tokenRowsSnapshot();

        Event::listen('eloquent.created: '.User::class, function (User $user) use ($failedLoginName): void {
            if ($user->login_name === $failedLoginName) {
                DB::table('stage3_missing_table_for_controlled_failure')->first();
            }
        });

        try {
            $response = $this->authorizedJsonPost($token, $this->validPayload([
                'login_name' => $failedLoginName,
            ]));
        } finally {
            Event::forget('eloquent.created: '.User::class);
        }

        $decoded = $this->assertErrorContract($response, 500, 'server_error');
        $this->assertSame('An unexpected server error occurred.', $decoded->message);
        $this->assertSame($userRowsBefore, $this->userRowsSnapshot());
        $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot());
        $this->assertSame(0, User::query()->where('login_name', $failedLoginName)->count());
        $this->assertNoInternalOrPasswordDisclosure($decoded, self::INITIAL_PASSWORD);
    }

    public function test_authentication_lifecycle_password_and_role_gates_precede_invalid_input_without_writes(): void
    {
        $institution = Institution::factory()->create();

        $this->assertErrorContract($this->postJson(self::CREATE_URI, []), 401, 'authentication_required');

        $inactiveActor = $this->institutionAdmin($institution, [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertGateResponse($inactiveActor, 'user_inactive');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $inactiveInstitutionActor = $this->institutionAdmin($inactiveInstitution);
        $this->assertGateResponse($inactiveInstitutionActor, 'institution_inactive');

        $firstLoginActor = $this->institutionAdmin($institution, ['must_change_password' => true]);
        $this->assertGateResponse($firstLoginActor, 'password_change_required');

        foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRole = $this->userForRole($role, $institution);
            $this->assertGateResponse($wrongRole, 'forbidden');
        }
    }

    public function test_forged_headers_cannot_change_tenant_creator_or_server_state_and_read_apis_see_committed_user(): void
    {
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $forgedCreator = $this->institutionAdmin($otherInstitution);
        $token = $this->tokenFor($actor);

        $response = $this->authorizedRawPost(
            $token,
            json_encode($this->validPayload([
                'role' => UserRole::Student->value,
                'login_name' => 'forged_headers_user',
            ]), JSON_THROW_ON_ERROR),
            'application/json; charset=UTF-8',
            [],
            [
                'HTTP_X_INSTITUTION_ID' => $otherInstitution->id,
                'HTTP_X_CREATED_BY_USER_ID' => $forgedCreator->id,
                'HTTP_X_ROLE' => UserRole::PlatformOwner->value,
                'HTTP_X_IS_ACTIVE' => 'false',
                'HTTP_X_MUST_CHANGE_PASSWORD' => 'false',
                'HTTP_X_CREATED_AT' => '1999-01-01T00:00:00Z',
            ],
        );

        $response->assertCreated();
        $created = User::query()->findOrFail($response->json('data.id'));
        $this->assertSame($institution->id, $created->institution_id);
        $this->assertSame($actor->id, $created->created_by_user_id);
        $this->assertSame(UserRole::Student, $created->role);
        $this->assertTrue($created->is_active);
        $this->assertTrue($created->must_change_password);
        $this->assertNull($created->last_login_at);
        $this->assertNull($created->deactivated_at);

        $this->authorizedRawGet($token, self::CREATE_URI.'?search=forged_headers_user')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $created->id)
            ->assertJsonPath('data.0.login_name', 'forged_headers_user');
        $this->forgetAuthenticationGuards();

        $this->authorizedRawGet($token, self::CREATE_URI.'/'.$created->id)
            ->assertOk()
            ->assertJsonPath('data.id', $created->id)
            ->assertJsonPath('data.role', UserRole::Student->value);

        $this->assertSame(0, User::query()->where('institution_id', $otherInstitution->id)->where('login_name', 'forged_headers_user')->count());
    }

    public function test_each_created_role_authenticates_and_representative_first_login_change_flow_is_complete(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $actorToken = $this->tokenFor($actor);
        $createdUsers = [];

        foreach ([UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $loginName = 'login_'.$role->value;
            $tokenRowsBeforeCreate = $this->tokenRowsSnapshot();
            $this->authorizedJsonPost($actorToken, $this->validPayload([
                'role' => $role->value,
                'login_name' => $loginName,
            ]))->assertCreated();
            $this->assertSame($tokenRowsBeforeCreate, $this->tokenRowsSnapshot(), $role->value.' creation token rows');
            $this->forgetAuthenticationGuards();

            $loginResponse = $this->postJson('/api/v1/auth/login', [
                'login' => $loginName,
                'password' => self::INITIAL_PASSWORD,
            ]);
            $loginResponse->assertOk();
            $loginResponse->assertJsonPath('data.user.role', $role->value);
            $loginResponse->assertJsonPath('data.user.must_change_password', true);
            $createdUsers[$role->value] = [
                'user' => User::query()->where('login_name', $loginName)->firstOrFail(),
                'token' => (string) $loginResponse->json('data.token'),
            ];
            $this->forgetAuthenticationGuards();
        }

        $teacher = $createdUsers[UserRole::Teacher->value]['user'];
        $teacherToken = $createdUsers[UserRole::Teacher->value]['token'];

        $this->assertErrorContract(
            $this->withToken($teacherToken)->getJson('/api/v1/institution/dashboard'),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $this->withToken($teacherToken)
            ->postJson('/api/v1/auth/change-password', [
                'current_password' => self::INITIAL_PASSWORD,
                'new_password' => self::NEW_PASSWORD,
                'new_password_confirmation' => self::NEW_PASSWORD,
            ])
            ->assertNoContent();
        $this->forgetAuthenticationGuards();

        $this->assertFalse($teacher->refresh()->must_change_password);
        $this->assertFalse(Hash::check(self::INITIAL_PASSWORD, $teacher->password));
        $this->assertTrue(Hash::check(self::NEW_PASSWORD, $teacher->password));

        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => $teacher->login_name,
            'password' => self::INITIAL_PASSWORD,
        ]), 401, 'invalid_credentials');
        $this->forgetAuthenticationGuards();

        $this->postJson('/api/v1/auth/login', [
            'login' => $teacher->login_name,
            'password' => self::NEW_PASSWORD,
        ])
            ->assertOk()
            ->assertJsonPath('data.user.must_change_password', false);
    }

    public function test_controlled_smoke_covers_three_roles_duplicate_forgery_visibility_and_password_gate(): void
    {
        $institution = Institution::factory()->create(['name' => 'Create API Smoke Institution']);
        $actor = $this->institutionAdmin($institution);
        $token = $this->tokenFor($actor);
        $createdIds = [];

        foreach ([UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $response = $this->authorizedJsonPost($token, $this->validPayload([
                'role' => $role->value,
                'full_name' => 'Smoke '.ucfirst($role->value),
                'login_name' => 'smoke_'.$role->value,
            ]));
            $response->assertCreated();
            $createdIds[] = $response->json('data.id');
        }

        $this->authorizedRawGet($token, self::CREATE_URI.'?search=smoke_&per_page=10')
            ->assertOk()
            ->assertJsonCount(3, 'data');
        $this->forgetAuthenticationGuards();

        foreach ($createdIds as $createdId) {
            $this->authorizedRawGet($token, self::CREATE_URI.'/'.$createdId)
                ->assertOk()
                ->assertJsonPath('data.id', $createdId);
            $this->forgetAuthenticationGuards();
        }

        $duplicate = $this->authorizedJsonPost($token, $this->validPayload([
            'login_name' => 'smoke_teacher',
        ]));
        $this->assertErrorContract($duplicate, 422, 'validation_failed');

        $forged = $this->authorizedJsonPost($token, array_merge($this->validPayload([
            'login_name' => 'smoke_forged',
        ]), ['institution_id' => Str::uuid()->toString()]));
        $this->assertErrorContract($forged, 422, 'validation_failed');

        $this->forgetAuthenticationGuards();
        $login = $this->postJson('/api/v1/auth/login', [
            'login' => 'smoke_teacher',
            'password' => self::INITIAL_PASSWORD,
        ]);
        $login->assertOk()->assertJsonPath('data.user.must_change_password', true);
        $newUserToken = (string) $login->json('data.token');
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($newUserToken)->getJson('/api/v1/institution/dashboard'),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $this->withToken($newUserToken)
            ->postJson('/api/v1/auth/change-password', [
                'current_password' => self::INITIAL_PASSWORD,
                'new_password' => self::NEW_PASSWORD,
                'new_password_confirmation' => self::NEW_PASSWORD,
            ])
            ->assertNoContent();
        $this->assertFalse(User::query()->where('login_name', 'smoke_teacher')->firstOrFail()->must_change_password);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'role' => UserRole::Teacher->value,
            'full_name' => 'Institution User',
            'login_name' => 'user_'.Str::lower(Str::random(12)),
            'email' => 'user@example.uz',
            'phone' => '+998901234567',
            'password' => self::INITIAL_PASSWORD,
        ], $overrides);
    }

    /**
     * @param  array<string, mixed>  $query
     */
    private function authorizedJsonPost(string $token, array $payload, array $query = []): TestResponse
    {
        $uri = self::CREATE_URI.($query === [] ? '' : '?'.http_build_query($query));

        return $this->withToken($token)->postJson($uri, $payload);
    }

    /**
     * @param  array<string, mixed>  $query
     * @param  array<string, string>  $headers
     */
    private function authorizedRawPost(
        string $token,
        string $content,
        string $contentType = 'application/json',
        array $query = [],
        array $headers = [],
    ): TestResponse {
        $uri = self::CREATE_URI.($query === [] ? '' : '?'.http_build_query($query));

        return $this->call(
            'POST',
            $uri,
            [],
            [],
            [],
            array_merge([
                'CONTENT_TYPE' => $contentType,
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ], $headers),
            $content,
        );
    }

    private function authorizedRawGet(string $token, string $uri): TestResponse
    {
        return $this->call(
            'GET',
            $uri,
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            '',
        );
    }

    private function assertGateResponse(User $actor, string $expectedCode): void
    {
        $userRowsBefore = $this->userRowsSnapshot();
        $token = $this->tokenFor($actor);
        $tokenRowsBefore = $this->tokenRowsSnapshot();

        $response = $this->authorizedRawPost($token, '');
        $this->assertErrorContract($response, 403, $expectedCode, $actor->role->value);
        $this->assertSame($userRowsBefore, $this->userRowsSnapshot(), $actor->role->value);
        $this->assertSame($tokenRowsBefore, $this->tokenRowsSnapshot(), $actor->role->value);
        $this->forgetAuthenticationGuards();
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
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
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
        };

        return $factory->create(['must_change_password' => false]);
    }

    private function tokenFor(User $user): string
    {
        return $user->createToken('institution-user-create-api-test')->plainTextToken;
    }

    /**
     * @return list<string>
     */
    private function resourceKeys(): array
    {
        return [
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
        ];
    }

    /**
     * @return list<string>
     */
    private function allowedInputKeys(): array
    {
        return ['role', 'full_name', 'login_name', 'email', 'phone', 'password'];
    }

    /**
     * @return list<string>
     */
    private function managedRoles(): array
    {
        return [UserRole::Teacher->value, UserRole::Student->value, UserRole::Parent->value];
    }

    private function emailOfLength254(): string
    {
        return str_repeat('a', 63).'@'.str_repeat('b', 62).'.'.str_repeat('c', 62).'.'.str_repeat('d', 60).'.com';
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
    private function settingRowsSnapshot(): array
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
            ->map(fn (PersonalAccessToken $token): array => $token->getRawOriginal())
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
        $this->assertSame(['message', 'code', 'errors'], array_keys(get_object_vars($decoded)), $case);
        $this->assertIsString($decoded->message, $case);
        $this->assertSame($code, $decoded->code, $case);
        $this->assertIsObject($decoded->errors, $case);

        return $decoded;
    }

    private function assertNoInternalOrPasswordDisclosure(object $decoded, string $password): void
    {
        $content = json_encode($decoded, JSON_THROW_ON_ERROR);

        foreach ([$password, 'SQLSTATE', 'users_login_name_unique', 'duplicate key', 'stage3_missing_table', 'password_hash'] as $forbiddenText) {
            $this->assertStringNotContainsString($forbiddenText, $content, $forbiddenText);
        }
    }
}
