<?php

namespace Tests\Feature\Platform;

use App\Actions\Platform\ChangePlatformInstitutionLifecycle;
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
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class PlatformInstitutionLifecycleApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/platform/institutions';

    private const PASSWORD = 'Correct test password 93! with enough length';

    public function test_lifecycle_routes_are_registered_once_with_required_middleware_order(): void
    {
        $lifecycleRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => in_array($route['uri'], [
                'api/v1/platform/institutions/{institution}/activate',
                'api/v1/platform/institutions/{institution}/deactivate',
            ], true))
            ->filter(fn (array $route): bool => in_array('POST', $route['methods'], true))
            ->values()
            ->all();

        $expectedMiddleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:platform_owner'];

        $this->assertSame([
            [
                'methods' => ['POST'],
                'uri' => 'api/v1/platform/institutions/{institution}/activate',
                'middleware' => $expectedMiddleware,
            ],
            [
                'methods' => ['POST'],
                'uri' => 'api/v1/platform/institutions/{institution}/deactivate',
                'middleware' => $expectedMiddleware,
            ],
        ], $lifecycleRoutes);
    }

    public function test_authentication_account_password_role_and_uuid_gates_write_nothing(): void
    {
        $target = Institution::factory()->create(['name' => 'Lifecycle Gate Target']);
        $before = $this->rawInstitutionSnapshot($target);

        foreach ([$this->activateUri($target), $this->deactivateUri($target)] as $uri) {
            $this->assertNoInstitutionChange(
                $target,
                $before,
                fn (): TestResponse => $this->postJson($uri),
                401,
                'authentication_required',
                $uri,
            );
        }

        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertNoInstitutionChange(
            $target,
            $before,
            fn (): TestResponse => $this->authorizedPost($inactivePlatformOwner, $this->deactivateUri($target)),
            403,
            'user_inactive',
        );
        $this->forgetAuthenticationGuards();

        $passwordIncompletePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'must_change_password' => true,
        ]);
        $this->assertNoInstitutionChange(
            $target,
            $before,
            fn (): TestResponse => $this->authorizedPost($passwordIncompletePlatformOwner, $this->deactivateUri($target)),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole($role);

            foreach ([$this->activateUri($target), $this->deactivateUri($target)] as $uri) {
                $this->assertNoInstitutionChange(
                    $target,
                    $before,
                    fn (): TestResponse => $this->authorizedPost($wrongRoleUser, $uri),
                    403,
                    'forbidden',
                    $role->value.' '.$uri,
                );
                $this->forgetAuthenticationGuards();
            }
        }

        $inactiveActorInstitution = Institution::factory()->inactive()->create();
        $wrongRoleUserFromInactiveInstitution = $this->createUserForRole(UserRole::Teacher, $inactiveActorInstitution);
        $this->assertNoInstitutionChange(
            $target,
            $before,
            fn (): TestResponse => $this->authorizedPost($wrongRoleUserFromInactiveInstitution, $this->deactivateUri($target)),
            403,
            'institution_inactive',
        );
        $this->forgetAuthenticationGuards();

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        foreach ([Str::uuid()->toString(), 'not-a-uuid'] as $id) {
            $this->assertErrorContract(
                $this->authorizedPost($platformOwner, self::BASE_URI.'/'.$id.'/activate'),
                404,
                'resource_not_found',
                $id,
            );
            $this->forgetAuthenticationGuards();
        }

        $this->assertSame($before, $this->rawInstitutionSnapshot($target));
    }

    public function test_bodyless_and_empty_object_commands_succeed_while_payload_input_is_rejected_without_writes(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $inactiveInstitution = Institution::factory()->inactive()->create([
            'name' => 'No Body Activate',
            'updated_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
        ]);
        $activeInstitution = Institution::factory()->create([
            'name' => 'Empty Object Deactivate',
            'updated_at' => CarbonImmutable::parse('2026-08-07 16:00:00', 'UTC'),
        ]);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            $this->authorizedRawJsonPost($platformOwner, $this->activateUri($inactiveInstitution), '')
                ->assertOk()
                ->assertJsonPath('message', 'Institution activated successfully.')
                ->assertJsonPath('data.status', InstitutionStatus::Active->value);
            $this->forgetAuthenticationGuards();

            $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($activeInstitution), '{}')
                ->assertOk()
                ->assertJsonPath('message', 'Institution deactivated successfully.')
                ->assertJsonPath('data.status', InstitutionStatus::Inactive->value);
            $this->forgetAuthenticationGuards();
        } finally {
            CarbonImmutable::setTestNow();
        }

        $protectedFields = [
            'status' => InstitutionStatus::Inactive->value,
            'is_active' => false,
            'deactivated_at' => '2026-08-10T12:00:00Z',
            'institution_id' => Str::uuid()->toString(),
            'user_id' => Str::uuid()->toString(),
            'reason' => 'technical issue',
            'force' => true,
            'role' => UserRole::PlatformOwner->value,
            'created_by_user_id' => Str::uuid()->toString(),
            'settings' => ['timezone' => CreatePlatformInstitution::DEFAULT_TIMEZONE],
            'confirmation' => true,
            'unknown_future_field' => 'not allowed',
        ];

        foreach ($protectedFields as $field => $value) {
            $target = Institution::factory()->create(['name' => 'Protected '.$field]);
            $before = $this->rawInstitutionSnapshot($target);
            $decoded = $this->assertErrorContract(
                $this->authorizedPost($platformOwner, $this->deactivateUri($target), [$field => $value]),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertSame($before, $this->rawInstitutionSnapshot($target), $field);
            $this->forgetAuthenticationGuards();
        }

        foreach ([
            'array body' => fn (Institution $institution): TestResponse => $this->withToken($this->tokenFor($platformOwner))
                ->json('POST', $this->deactivateUri($institution), [['status' => InstitutionStatus::Inactive->value]]),
            'scalar body' => fn (Institution $institution): TestResponse => $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($institution), '"inactive"'),
            'query input' => fn (Institution $institution): TestResponse => $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($institution).'?status=inactive', '{}'),
        ] as $case => $request) {
            $target = Institution::factory()->create(['name' => $case]);
            $before = $this->rawInstitutionSnapshot($target);
            $decoded = $this->assertErrorContract($request($target), 422, 'validation_failed', $case);
            $this->assertSame($before, $this->rawInstitutionSnapshot($target), $case);
            $this->assertObjectHasProperty($case === 'query input' ? 'status' : 'body', $decoded->errors, $case);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_real_transitions_and_noop_retries_preserve_required_timestamps_and_response_contracts(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $createdAt = CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC');
        $initialUpdatedAt = CarbonImmutable::parse('2026-08-07 16:00:00', 'UTC');
        $originalDeactivatedAt = CarbonImmutable::parse('2026-08-08 10:15:00', 'UTC');
        $institution = Institution::factory()->inactive()->create([
            'name' => 'Lifecycle Timestamp School',
            'type' => InstitutionType::School,
            'status' => InstitutionStatus::Inactive,
            'contact_email' => 'lifecycle@example.uz',
            'contact_phone' => '+998 90 000 00 00',
            'address' => 'Samarkand',
            'description' => 'Optional notes',
            'deactivated_at' => $originalDeactivatedAt,
            'created_at' => $createdAt,
            'updated_at' => $initialUpdatedAt,
        ]);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            $activateResponse = $this->authorizedPost($platformOwner, $this->activateUri($institution));
            $activateResponse->assertOk();
            $this->assertLifecycleResponse(
                $activateResponse,
                $institution->id,
                InstitutionStatus::Active,
                'Institution activated successfully.',
                '2026-08-10T12:00:00Z',
            );

            $institution->refresh();
            $this->assertSame(InstitutionStatus::Active, $institution->status);
            $this->assertNull($institution->deactivated_at);
            $this->assertSame('2026-08-10T12:00:00.000000Z', $institution->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 13:00:00', 'UTC'));
            $activateNoopResponse = null;
            $activateNoopUpdateCount = $this->countInstitutionUpdatesDuring(
                function () use ($platformOwner, $institution, &$activateNoopResponse): TestResponse {
                    $activateNoopResponse = $this->authorizedPost($platformOwner, $this->activateUri($institution));

                    return $activateNoopResponse;
                }
            );
            $this->assertSame(0, $activateNoopUpdateCount);
            $this->assertInstanceOf(TestResponse::class, $activateNoopResponse);
            $activateNoopResponse->assertOk()
                ->assertJsonPath('message', 'Institution activated successfully.')
                ->assertJsonPath('data.updated_at', '2026-08-10T12:00:00Z');
            $institution->refresh();
            $this->assertSame(InstitutionStatus::Active, $institution->status);
            $this->assertNull($institution->deactivated_at);
            $this->assertSame('2026-08-10T12:00:00.000000Z', $institution->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 14:00:00', 'UTC'));
            $deactivateResponse = $this->authorizedPost($platformOwner, $this->deactivateUri($institution));
            $deactivateResponse->assertOk();
            $this->assertLifecycleResponse(
                $deactivateResponse,
                $institution->id,
                InstitutionStatus::Inactive,
                'Institution deactivated successfully.',
                '2026-08-10T14:00:00Z',
            );

            $institution->refresh();
            $this->assertSame(InstitutionStatus::Inactive, $institution->status);
            $this->assertSame('2026-08-10T14:00:00.000000Z', $institution->deactivated_at?->toJSON());
            $this->assertSame('2026-08-10T14:00:00.000000Z', $institution->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 15:00:00', 'UTC'));
            $deactivateNoopResponse = null;
            $deactivateNoopUpdateCount = $this->countInstitutionUpdatesDuring(
                function () use ($platformOwner, $institution, &$deactivateNoopResponse): TestResponse {
                    $deactivateNoopResponse = $this->authorizedPost($platformOwner, $this->deactivateUri($institution));

                    return $deactivateNoopResponse;
                }
            );
            $this->assertSame(0, $deactivateNoopUpdateCount);
            $this->assertInstanceOf(TestResponse::class, $deactivateNoopResponse);
            $deactivateNoopResponse->assertOk()
                ->assertJsonPath('message', 'Institution deactivated successfully.')
                ->assertJsonPath('data.updated_at', '2026-08-10T14:00:00Z');
            $institution->refresh();
            $this->assertSame(InstitutionStatus::Inactive, $institution->status);
            $this->assertSame('2026-08-10T14:00:00.000000Z', $institution->deactivated_at?->toJSON());
            $this->assertSame('2026-08-10T14:00:00.000000Z', $institution->updated_at?->toJSON());
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_lifecycle_action_uses_postgresql_transaction_row_lock_and_writes_only_on_real_transition(): void
    {
        $action = new ChangePlatformInstitutionLifecycle;
        $institution = Institution::factory()->create();

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));
        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $action->deactivate($institution);
            $transitionQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
            CarbonImmutable::setTestNow();
        }

        $this->assertTrue($this->queriesContainForUpdate($transitionQueries));
        $this->assertSame(1, $this->countInstitutionUpdateQueries($transitionQueries));
        $institution->refresh();
        $this->assertSame(InstitutionStatus::Inactive, $institution->status);
        $this->assertSame('2026-08-10T12:00:00.000000Z', $institution->deactivated_at?->toJSON());

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $action->deactivate($institution);
            $noopQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertTrue($this->queriesContainForUpdate($noopQueries));
        $this->assertSame(0, $this->countInstitutionUpdateQueries($noopQueries));
    }

    public function test_deactivation_blocks_institution_users_and_reactivation_restores_only_normal_eligibility(): void
    {
        $institution = $this->createInstitutionWithSettings(['name' => 'Access Lifecycle School']);
        $otherInstitution = $this->createInstitutionWithSettings(['name' => 'Other Active School']);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $loginUsersByRole = [];

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $loginUsersByRole[$role->value] = $this->createUserForRole(
                $role,
                $institution,
                loginName: 'blocked_'.$role->value,
            );
        }

        $existingTokenUser = $this->createUserForRole(UserRole::Teacher, $institution, loginName: 'existing_token_teacher');
        $logoutUser = $this->createUserForRole(UserRole::Parent, $institution, loginName: 'logout_parent');
        $inactiveUser = $this->createUserForRole(UserRole::Student, $institution, loginName: 'still_inactive_student', attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $passwordGatedUser = $this->createUserForRole(UserRole::Teacher, $institution, loginName: 'password_gate_teacher', attributes: [
            'must_change_password' => true,
        ]);
        $otherInstitutionUser = $this->createUserForRole(UserRole::Teacher, $otherInstitution, loginName: 'other_teacher');

        $existingToken = $this->loginAndReturnToken($existingTokenUser);
        $this->forgetAuthenticationGuards();
        $logoutToken = $this->loginAndReturnToken($logoutUser);
        $this->forgetAuthenticationGuards();

        $this->authorizedPost($platformOwner, $this->deactivateUri($institution))->assertOk();
        $this->forgetAuthenticationGuards();
        $tokenCountAfterDeactivation = PersonalAccessToken::query()->count();

        foreach ($loginUsersByRole as $role => $user) {
            $lastLoginBefore = $user->refresh()->last_login_at?->toJSON();
            $tokenCountBeforeDeniedLogin = PersonalAccessToken::query()->count();

            $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
                'login' => $user->login_name,
                'password' => self::PASSWORD,
            ]), 403, 'institution_inactive', $role);

            $this->assertSame($tokenCountBeforeDeniedLogin, PersonalAccessToken::query()->count(), $role);
            $this->assertSame($lastLoginBefore, $user->refresh()->last_login_at?->toJSON(), $role);
        }

        $this->assertSame($tokenCountAfterDeactivation, PersonalAccessToken::query()->count());

        $this->assertErrorContract(
            $this->withToken($existingToken)->getJson('/api/v1/auth/me'),
            403,
            'institution_inactive',
        );
        $this->forgetAuthenticationGuards();

        $this->withToken($logoutToken)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->forgetAuthenticationGuards();
        $this->assertSame(0, PersonalAccessToken::query()->where('tokenable_id', $logoutUser->id)->count());
        $this->assertSame(1, PersonalAccessToken::query()->where('tokenable_id', $existingTokenUser->id)->count());

        $otherInstitutionLogin = $this->postJson('/api/v1/auth/login', [
            'login' => $otherInstitutionUser->login_name,
            'password' => self::PASSWORD,
        ]);
        $otherInstitutionLogin->assertOk();
        $this->assertNotNull($otherInstitutionUser->refresh()->last_login_at);
        $this->forgetAuthenticationGuards();

        $this->authorizedPost($platformOwner, $this->activateUri($institution))->assertOk();
        $this->forgetAuthenticationGuards();

        $this->withToken($existingToken)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', $existingTokenUser->id);
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => $inactiveUser->login_name,
            'password' => self::PASSWORD,
        ]), 403, 'user_inactive');
        $this->assertNull($inactiveUser->refresh()->last_login_at);

        $passwordGateToken = $this->loginAndReturnToken($passwordGatedUser);
        $this->forgetAuthenticationGuards();
        $this->assertErrorContract(
            $this->withToken($passwordGateToken)->getJson(self::BASE_URI),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($existingToken)->getJson(self::BASE_URI),
            403,
            'forbidden',
        );
        $this->forgetAuthenticationGuards();

        $this->authorizedPost($platformOwner, $this->deactivateUri($institution))
            ->assertOk()
            ->assertJsonPath('data.status', InstitutionStatus::Inactive->value);
    }

    public function test_lifecycle_preserves_profile_settings_users_tokens_and_other_institution_data(): void
    {
        $creator = $this->createUserForRole(UserRole::PlatformOwner);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create([
            'name' => 'Retention School',
            'type' => InstitutionType::LearningCenter,
            'contact_email' => 'retention@example.uz',
            'contact_phone' => '+998 90 111 22 33',
            'address' => 'Retention address',
            'description' => 'Retention description',
            'created_by_user_id' => $creator->id,
        ]);
        $setting = InstitutionSetting::factory()
            ->configuredEducationalPolicy()
            ->uploadLimits(20, 10)
            ->create([
                'institution_id' => $institution->id,
                'timezone' => 'Asia/Samarkand',
                'updated_by_user_id' => $creator->id,
            ]);
        $institutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'retention_admin');
        $teacher = $this->createUserForRole(UserRole::Teacher, $institution, loginName: 'retention_teacher');
        $inactiveStudent = $this->createUserForRole(UserRole::Student, $institution, loginName: 'retention_student', attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->loginAndReturnToken($institutionAdmin);
        $this->forgetAuthenticationGuards();
        $this->loginAndReturnToken($teacher);
        $this->forgetAuthenticationGuards();

        $otherInstitution = $this->createInstitutionWithSettings(['name' => 'Untouched Other School']);
        $otherUser = $this->createUserForRole(UserRole::Teacher, $otherInstitution, loginName: 'retention_other_teacher');

        $profileBefore = $this->profileSnapshot($institution);
        $settingBefore = $this->settingSnapshot($setting);
        $usersBefore = $this->usersSnapshot($institution);
        $targetTokenRowsBefore = $this->tokenRowsForUsers([$institutionAdmin, $teacher, $inactiveStudent]);
        $otherInstitutionBefore = $this->rawInstitutionSnapshot($otherInstitution);
        $otherUsersBefore = $this->usersSnapshot($otherInstitution);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            $this->authorizedPost($platformOwner, $this->deactivateUri($institution))->assertOk();
            $this->forgetAuthenticationGuards();
            $this->authorizedPost($platformOwner, $this->activateUri($institution))->assertOk();
            $this->forgetAuthenticationGuards();
        } finally {
            CarbonImmutable::setTestNow();
        }

        $this->assertSame($profileBefore, $this->profileSnapshot($institution));
        $this->assertSame($settingBefore, $this->settingSnapshot($setting));
        $this->assertSame($usersBefore, $this->usersSnapshot($institution));
        $this->assertSame($targetTokenRowsBefore, $this->tokenRowsForUsers([$institutionAdmin, $teacher, $inactiveStudent]));
        $this->assertSame($otherInstitutionBefore, $this->rawInstitutionSnapshot($otherInstitution));
        $this->assertSame($otherUsersBefore, $this->usersSnapshot($otherInstitution));

        $institution->refresh();
        $this->assertSame(InstitutionStatus::Active, $institution->status);
        $this->assertNull($institution->deactivated_at);
        $this->assertSame($otherInstitution->id, $otherUser->refresh()->institution_id);
    }

    private function createInstitutionWithSettings(array $attributes = []): Institution
    {
        $institution = Institution::factory()->create($attributes);

        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'timezone' => 'Asia/Tashkent',
        ]);

        return $institution->refresh()->load('setting');
    }

    private function createUserForRole(
        UserRole $role,
        ?Institution $institution = null,
        ?string $loginName = null,
        array $attributes = [],
    ): User {
        $factory = match ($role) {
            UserRole::PlatformOwner => User::factory()->platformOwner(),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
        };

        return $factory
            ->withPassword(self::PASSWORD)
            ->create(array_merge([
                'login_name' => $loginName ?? 'lifecycle_'.strtolower(str_replace('_', '', $role->value)).'_'.bin2hex(random_bytes(3)),
                'must_change_password' => false,
            ], $attributes));
    }

    private function loginAndReturnToken(User $user): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => self::PASSWORD,
        ]);

        $response->assertOk();

        return (string) $response->json('data.token');
    }

    private function authorizedPost(User $user, string $uri, array $payload = []): TestResponse
    {
        if ($payload === []) {
            return $this->authorizedRawJsonPost($user, $uri, '');
        }

        return $this->withToken($this->tokenFor($user))->postJson($uri, $payload);
    }

    private function authorizedRawJsonPost(User $user, string $uri, string $content): TestResponse
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
        return $user->createToken('platform-institution-lifecycle-api-test', $abilities)->plainTextToken;
    }

    private function activateUri(Institution $institution): string
    {
        return self::BASE_URI.'/'.$institution->id.'/activate';
    }

    private function deactivateUri(Institution $institution): string
    {
        return self::BASE_URI.'/'.$institution->id.'/deactivate';
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
    private function profileSnapshot(Institution $institution): array
    {
        $institution->refresh();

        return [
            'id' => $institution->id,
            'name' => $institution->name,
            'type' => $institution->type->value,
            'contact_email' => $institution->contact_email,
            'contact_phone' => $institution->contact_phone,
            'address' => $institution->address,
            'description' => $institution->description,
            'created_by_user_id' => $institution->created_by_user_id,
            'created_at' => $institution->created_at?->toJSON(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function settingSnapshot(InstitutionSetting $setting): array
    {
        return $setting->refresh()->getRawOriginal();
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

    /**
     * @param  list<User>  $users
     * @return list<array<string, mixed>>
     */
    private function tokenRowsForUsers(array $users): array
    {
        return PersonalAccessToken::query()
            ->whereIn('tokenable_id', collect($users)->map->id->all())
            ->orderBy('id')
            ->get()
            ->map(fn (PersonalAccessToken $token): array => $token->getRawOriginal())
            ->values()
            ->all();
    }

    private function assertNoInstitutionChange(
        Institution $institution,
        array $before,
        callable $request,
        int $status,
        string $code,
        string $case = '',
    ): void {
        $this->assertErrorContract($request(), $status, $code, $case);
        $this->assertSame($before, $this->rawInstitutionSnapshot($institution), $case);
    }

    private function countInstitutionUpdatesDuring(callable $callback): int
    {
        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $callback();

            return $this->countInstitutionUpdateQueries(DB::getQueryLog());
        } finally {
            DB::disableQueryLog();
        }
    }

    /**
     * @param  list<array<string, mixed>>  $queries
     */
    private function countInstitutionUpdateQueries(array $queries): int
    {
        return collect($queries)
            ->filter(fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "institutions"'))
            ->count();
    }

    /**
     * @param  list<array<string, mixed>>  $queries
     */
    private function queriesContainForUpdate(array $queries): bool
    {
        return collect($queries)
            ->contains(fn (array $query): bool => str_contains(strtolower((string) $query['query']), 'for update'));
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    private function assertLifecycleResponse(
        TestResponse $response,
        string $institutionId,
        InstitutionStatus $status,
        string $message,
        string $updatedAt,
    ): void {
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame($message, $response->json('message'));

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
        $this->assertSame($institutionId, $data['id']);
        $this->assertSame('Lifecycle Timestamp School', $data['name']);
        $this->assertSame(InstitutionType::School->value, $data['type']);
        $this->assertSame($status->value, $data['status']);
        $this->assertSame('lifecycle@example.uz', $data['contact_email']);
        $this->assertSame('+998 90 000 00 00', $data['contact_phone']);
        $this->assertSame('Samarkand', $data['address']);
        $this->assertSame('Optional notes', $data['description']);
        $this->assertSame('2026-08-07T15:00:00Z', $data['created_at']);
        $this->assertSame($updatedAt, $data['updated_at']);

        $content = $response->getContent();
        $this->assertStringNotContainsString('created_by_user_id', $content);
        $this->assertStringNotContainsString('deactivated_at', $content);
        $this->assertStringNotContainsString('settings', $content);
        $this->assertStringNotContainsString('user_counts', $content);
        $this->assertStringNotContainsString('users', $content);
        $this->assertStringNotContainsString('tokens', $content);
        $this->assertStringNotContainsString('meta', $content);
        $this->assertStringNotContainsString('institution_already_', $content);
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
