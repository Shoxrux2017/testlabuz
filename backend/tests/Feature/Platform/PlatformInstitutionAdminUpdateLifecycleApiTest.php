<?php

namespace Tests\Feature\Platform;

use App\Actions\Platform\ChangePlatformInstitutionAdminLifecycle;
use App\Actions\Platform\UpdatePlatformInstitutionAdmin;
use App\Enums\InstitutionStatus;
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

class PlatformInstitutionAdminUpdateLifecycleApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/platform/institution-admins';

    private const PASSWORD = 'Correct admin password 93!';

    public function test_update_and_lifecycle_routes_are_registered_once_with_required_middleware_order(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => in_array($route['uri'], [
                'api/v1/platform/institution-admins/{user}',
                'api/v1/platform/institution-admins/{user}/activate',
                'api/v1/platform/institution-admins/{user}/deactivate',
            ], true))
            ->values()
            ->all();

        $expectedMiddleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:platform_owner'];

        $this->assertSame([
            [
                'methods' => ['PATCH'],
                'uri' => 'api/v1/platform/institution-admins/{user}',
                'middleware' => $expectedMiddleware,
            ],
            [
                'methods' => ['POST'],
                'uri' => 'api/v1/platform/institution-admins/{user}/activate',
                'middleware' => $expectedMiddleware,
            ],
            [
                'methods' => ['POST'],
                'uri' => 'api/v1/platform/institution-admins/{user}/deactivate',
                'middleware' => $expectedMiddleware,
            ],
        ], $routes);
    }

    public function test_authentication_account_institution_password_role_and_target_gates_write_nothing(): void
    {
        $institution = Institution::factory()->create();
        $target = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'gate_target_admin');

        foreach ($this->endpointRequestsForTarget($target) as $case => $request) {
            $before = $this->userSnapshot($target);
            $this->assertErrorContract($request(null), 401, 'authentication_required', $case.' unauthenticated');
            $this->assertSame($before, $this->userSnapshot($target), $case.' unauthenticated');
        }

        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        foreach ($this->endpointRequestsForTarget($target) as $case => $request) {
            $this->assertNoUserChange(
                $target,
                fn (): TestResponse => $request($inactivePlatformOwner),
                403,
                'user_inactive',
                $case.' inactive platform owner',
            );
            $this->forgetAuthenticationGuards();
        }

        $passwordIncompletePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'must_change_password' => true,
        ]);
        foreach ($this->endpointRequestsForTarget($target) as $case => $request) {
            $this->assertNoUserChange(
                $target,
                fn (): TestResponse => $request($passwordIncompletePlatformOwner),
                403,
                'password_change_required',
                $case.' password incomplete platform owner',
            );
            $this->forgetAuthenticationGuards();
        }

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $actor = $this->createUserForRole($role);

            foreach ($this->endpointRequestsForTarget($target) as $case => $request) {
                $this->assertNoUserChange(
                    $target,
                    fn (): TestResponse => $request($actor),
                    403,
                    'forbidden',
                    $role->value.' '.$case,
                );
                $this->forgetAuthenticationGuards();
            }
        }

        $inactiveActorInstitution = Institution::factory()->inactive()->create();
        $wrongRoleFromInactiveInstitution = $this->createUserForRole(UserRole::Teacher, $inactiveActorInstitution);
        foreach ($this->endpointRequestsForTarget($target) as $case => $request) {
            $this->assertNoUserChange(
                $target,
                fn (): TestResponse => $request($wrongRoleFromInactiveInstitution),
                403,
                'institution_inactive',
                $case.' inactive actor institution',
            );
            $this->forgetAuthenticationGuards();
        }

        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $this->authorizedPatch($platformOwner, $target, ['full_name' => 'Authorized Updated Admin'])
            ->assertOk()
            ->assertJsonPath('message', 'Institution admin updated successfully.');
        $this->forgetAuthenticationGuards();

        $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($target), '')
            ->assertOk()
            ->assertJsonPath('message', 'Institution admin deactivated successfully.');
        $this->forgetAuthenticationGuards();

        $this->authorizedRawJsonPost($platformOwner, $this->activateUri($target), '')
            ->assertOk()
            ->assertJsonPath('message', 'Institution admin activated successfully.');
        $this->forgetAuthenticationGuards();

        foreach (['not-a-uuid', Str::uuid()->toString()] as $id) {
            foreach ($this->endpointRequestsForRawId($id) as $case => $request) {
                $before = $this->userSnapshot($target);
                $this->assertErrorContract($request($platformOwner), 404, 'resource_not_found', $id.' '.$case);
                $this->assertSame($before, $this->userSnapshot($target), $id.' '.$case);
                $this->forgetAuthenticationGuards();
            }
        }

        foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $nonAdmin = $this->createUserForRole($role, $role === UserRole::PlatformOwner ? null : $institution);

            foreach ($this->endpointRequestsForRawId($nonAdmin->id) as $case => $request) {
                $before = $this->userSnapshot($nonAdmin);
                $this->assertErrorContract($request($platformOwner), 404, 'resource_not_found', $role->value.' '.$case);
                $this->assertSame($before, $this->userSnapshot($nonAdmin), $role->value.' '.$case);
                $this->forgetAuthenticationGuards();
            }
        }
    }

    public function test_patch_allows_partial_updates_nullable_duplicate_contacts_and_preserves_protected_state(): void
    {
        $creator = $this->createUserForRole(UserRole::PlatformOwner);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = $this->createInstitutionWithSettings();
        $otherInstitution = $this->createInstitutionWithSettings(['name' => 'Other Admin Update Institution']);
        $admin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'patch_admin', attributes: [
            'full_name' => 'Original Admin',
            'email' => 'original@example.uz',
            'phone' => '+998900000001',
            'created_by_user_id' => $creator->id,
            'must_change_password' => true,
            'last_login_at' => CarbonImmutable::parse('2026-08-07 10:00:00', 'UTC'),
            'created_at' => CarbonImmutable::parse('2026-08-07 08:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 09:00:00', 'UTC'),
        ]);
        $otherAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $otherInstitution, loginName: 'other_patch_admin', attributes: [
            'email' => 'shared@example.uz',
            'phone' => '+998900000099',
        ]);
        $token = $this->tokenFor($admin);

        $protectedBefore = $this->protectedUserSnapshot($admin);
        $settingsBefore = $this->settingsSnapshot();
        $otherUsersBefore = $this->usersSnapshot($otherInstitution);
        $adminTokenRowsBefore = $this->tokenRowsSnapshot($admin);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            $nameResponse = $this->authorizedPatch($platformOwner, $admin, ['full_name' => '  Updated Admin  ']);
            $nameResponse->assertOk();
            $this->assertAdminResource(
                $nameResponse,
                $admin->id,
                'Updated Admin',
                'patch_admin',
                'original@example.uz',
                '+998900000001',
                true,
                true,
                '2026-08-07T10:00:00Z',
                null,
                '2026-08-07T08:00:00Z',
                '2026-08-10T12:00:00Z',
                'Institution admin updated successfully.',
            );
            $this->forgetAuthenticationGuards();

            $emailResponse = $this->authorizedPatch($platformOwner, $admin, ['email' => 'shared@example.uz']);
            $emailResponse->assertOk()
                ->assertJsonPath('data.full_name', 'Updated Admin')
                ->assertJsonPath('data.email', 'shared@example.uz');
            $this->forgetAuthenticationGuards();

            $phoneResponse = $this->authorizedPatch($platformOwner, $admin, ['phone' => '  +998900000099  ']);
            $phoneResponse->assertOk()
                ->assertJsonPath('data.phone', '+998900000099');
            $this->forgetAuthenticationGuards();

            $clearContacts = $this->authorizedPatch($platformOwner, $admin, [
                'email' => null,
                'phone' => null,
            ]);
            $clearContacts->assertOk()
                ->assertJsonPath('data.email', null)
                ->assertJsonPath('data.phone', null);
            $this->forgetAuthenticationGuards();
        } finally {
            CarbonImmutable::setTestNow();
        }

        $admin->refresh();
        $this->assertSame('Updated Admin', $admin->full_name);
        $this->assertNull($admin->email);
        $this->assertNull($admin->phone);
        $this->assertSame($protectedBefore, $this->protectedUserSnapshot($admin));
        $this->assertSame($settingsBefore, $this->settingsSnapshot());
        $this->assertSame($otherUsersBefore, $this->usersSnapshot($otherInstitution));
        $this->assertSame($otherAdmin->id, $otherAdmin->refresh()->id);
        $this->assertSame($adminTokenRowsBefore, $this->tokenRowsSnapshot($admin));
        $this->assertSame(1, PersonalAccessToken::query()->where('tokenable_id', $admin->id)->count());
        $this->assertNotEmpty($token);
    }

    public function test_patch_validation_rejects_empty_non_object_unknown_protected_and_invalid_input_without_partial_mutation(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = $this->createInstitutionWithSettings();
        $admin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'validation_admin', attributes: [
            'full_name' => 'Validation Admin',
            'email' => 'validation@example.uz',
            'phone' => '+998900000002',
        ]);

        $invalidCases = [
            'empty object' => ['{}', 'body'],
            'array root' => ['[]', 'body'],
            'scalar root' => ['"scalar"', 'body'],
            'blank full name' => ['{"full_name":"   "}', 'full_name'],
            'null full name' => ['{"full_name":null}', 'full_name'],
            'long full name' => [json_encode(['full_name' => str_repeat('a', 201)], JSON_THROW_ON_ERROR), 'full_name'],
            'invalid email' => ['{"email":"not-an-email"}', 'email'],
            'long email' => [json_encode(['email' => str_repeat('a', 245).'@example.uz'], JSON_THROW_ON_ERROR), 'email'],
            'empty phone' => ['{"phone":"   "}', 'phone'],
            'long phone' => [json_encode(['phone' => str_repeat('1', 51)], JSON_THROW_ON_ERROR), 'phone'],
            'array phone' => ['{"phone":["+998"]}', 'phone'],
            'unknown field' => ['{"full_name":"Allowed","nickname":"Nope"}', 'nickname'],
        ];

        foreach ($invalidCases as $case => [$content, $expectedField]) {
            $before = $this->userSnapshot($admin);
            $decoded = $this->assertErrorContract(
                $this->authorizedRawJsonPatch($platformOwner, $this->adminUri($admin), $content),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($expectedField, $decoded->errors, $case);
            $this->assertSame($before, $this->userSnapshot($admin), $case);
            $this->forgetAuthenticationGuards();
        }

        foreach ($this->protectedUpdateKeys() as $field => $value) {
            $before = $this->userSnapshot($admin);
            $decoded = $this->assertErrorContract(
                $this->authorizedPatch($platformOwner, $admin, [
                    'full_name' => 'Should Not Apply',
                    $field => $value,
                ]),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertSame($before, $this->userSnapshot($admin), $field);
            $this->forgetAuthenticationGuards();
        }

        $queryBefore = $this->userSnapshot($admin);
        $queryError = $this->assertErrorContract(
            $this->authorizedRawJsonPatch($platformOwner, $this->adminUri($admin).'?role='.UserRole::Teacher->value, '{"full_name":"Query Nope"}'),
            422,
            'validation_failed',
            'query role',
        );
        $this->assertObjectHasProperty('role', $queryError->errors);
        $this->assertSame($queryBefore, $this->userSnapshot($admin));
    }

    public function test_patch_noop_inactive_target_and_inactive_institution_preserve_lifecycle_and_timestamps(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $activeInstitution = $this->createInstitutionWithSettings();
        $inactiveInstitution = $this->createInstitutionWithSettings(['status' => InstitutionStatus::Inactive, 'deactivated_at' => CarbonImmutable::parse('2026-08-07 11:00:00', 'UTC')]);
        $activeAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $activeInstitution, loginName: 'noop_admin', attributes: [
            'full_name' => 'Noop Admin',
            'email' => 'noop@example.uz',
            'phone' => '+998900000003',
            'created_at' => CarbonImmutable::parse('2026-08-07 08:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 09:00:00', 'UTC'),
        ]);
        $inactiveAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $activeInstitution, loginName: 'inactive_target_admin', attributes: [
            'is_active' => false,
            'deactivated_at' => CarbonImmutable::parse('2026-08-07 12:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 12:00:00', 'UTC'),
        ]);
        $inactiveInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $inactiveInstitution, loginName: 'inactive_institution_update_admin', attributes: [
            'full_name' => 'Inactive Institution Admin',
            'updated_at' => CarbonImmutable::parse('2026-08-07 13:00:00', 'UTC'),
        ]);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            $noopUpdateCount = $this->countUserUpdatesDuring(
                fn (): TestResponse => $this->authorizedPatch($platformOwner, $activeAdmin, [
                    'full_name' => 'Noop Admin',
                    'email' => 'noop@example.uz',
                    'phone' => '+998900000003',
                ])
            );
            $this->assertSame(0, $noopUpdateCount);
            $activeAdmin->refresh();
            $this->assertSame('2026-08-07T09:00:00.000000Z', $activeAdmin->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            $this->authorizedPatch($platformOwner, $inactiveAdmin, ['phone' => '+998900000004'])
                ->assertOk()
                ->assertJsonPath('data.is_active', false)
                ->assertJsonPath('data.deactivated_at', '2026-08-07T12:00:00Z')
                ->assertJsonPath('data.phone', '+998900000004');
            $inactiveAdmin->refresh();
            $this->assertFalse($inactiveAdmin->is_active);
            $this->assertSame('2026-08-07T12:00:00.000000Z', $inactiveAdmin->deactivated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            $this->authorizedPatch($platformOwner, $inactiveInstitutionAdmin, ['full_name' => 'Still Managed Admin'])
                ->assertOk()
                ->assertJsonPath('data.full_name', 'Still Managed Admin');
            $this->forgetAuthenticationGuards();
        } finally {
            CarbonImmutable::setTestNow();
        }

        $this->assertSame(InstitutionStatus::Inactive, $inactiveInstitution->refresh()->status);
        $this->assertSame('2026-08-07T11:00:00.000000Z', $inactiveInstitution->deactivated_at?->toJSON());
        $this->assertTrue($activeAdmin->refresh()->is_active);
    }

    public function test_lifecycle_body_validation_transitions_noop_timestamps_and_response_contracts(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = $this->createInstitutionWithSettings();
        $admin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'lifecycle_admin', attributes: [
            'full_name' => 'Lifecycle Admin',
            'email' => null,
            'phone' => '+998900000005',
            'must_change_password' => true,
            'created_at' => CarbonImmutable::parse('2026-08-07 08:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 09:00:00', 'UTC'),
        ]);

        foreach ($this->protectedLifecycleKeys() as $field => $value) {
            $before = $this->userSnapshot($admin);
            $decoded = $this->assertErrorContract(
                $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($admin), json_encode([$field => $value], JSON_THROW_ON_ERROR)),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors);
            $this->assertSame($before, $this->userSnapshot($admin), $field);
            $this->forgetAuthenticationGuards();
        }

        foreach ([
            'array body' => '[{"is_active":false}]',
            'scalar body' => '"inactive"',
        ] as $case => $content) {
            $before = $this->userSnapshot($admin);
            $decoded = $this->assertErrorContract(
                $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($admin), $content),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($before, $this->userSnapshot($admin), $case);
            $this->forgetAuthenticationGuards();
        }

        $queryBefore = $this->userSnapshot($admin);
        $queryError = $this->assertErrorContract(
            $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($admin).'?force=1', '{}'),
            422,
            'validation_failed',
            'query force',
        );
        $this->assertObjectHasProperty('force', $queryError->errors);
        $this->assertSame($queryBefore, $this->userSnapshot($admin));
        $this->forgetAuthenticationGuards();

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            $deactivate = $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($admin), '{}');
            $deactivate->assertOk();
            $this->assertAdminResource(
                $deactivate,
                $admin->id,
                'Lifecycle Admin',
                'lifecycle_admin',
                null,
                '+998900000005',
                false,
                true,
                null,
                '2026-08-10T12:00:00Z',
                '2026-08-07T08:00:00Z',
                '2026-08-10T12:00:00Z',
                'Institution admin deactivated successfully.',
            );
            $admin->refresh();
            $this->assertFalse($admin->is_active);
            $this->assertSame('2026-08-10T12:00:00.000000Z', $admin->deactivated_at?->toJSON());
            $this->assertSame('2026-08-10T12:00:00.000000Z', $admin->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 13:00:00', 'UTC'));
            $deactivateNoopUpdateCount = $this->countUserUpdatesDuring(
                fn (): TestResponse => $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($admin), '')
            );
            $this->assertSame(0, $deactivateNoopUpdateCount);
            $admin->refresh();
            $this->assertSame('2026-08-10T12:00:00.000000Z', $admin->deactivated_at?->toJSON());
            $this->assertSame('2026-08-10T12:00:00.000000Z', $admin->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 14:00:00', 'UTC'));
            $activate = $this->authorizedRawJsonPost($platformOwner, $this->activateUri($admin), '');
            $activate->assertOk()
                ->assertJsonPath('message', 'Institution admin activated successfully.')
                ->assertJsonPath('data.is_active', true)
                ->assertJsonPath('data.deactivated_at', null)
                ->assertJsonPath('data.updated_at', '2026-08-10T14:00:00Z');
            $admin->refresh();
            $this->assertTrue($admin->is_active);
            $this->assertNull($admin->deactivated_at);
            $this->assertSame('2026-08-10T14:00:00.000000Z', $admin->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 15:00:00', 'UTC'));
            $activateNoopUpdateCount = $this->countUserUpdatesDuring(
                fn (): TestResponse => $this->authorizedRawJsonPost($platformOwner, $this->activateUri($admin), '{}')
            );
            $this->assertSame(0, $activateNoopUpdateCount);
            $admin->refresh();
            $this->assertNull($admin->deactivated_at);
            $this->assertSame('2026-08-10T14:00:00.000000Z', $admin->updated_at?->toJSON());
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_lifecycle_access_enforcement_token_retention_reactivation_and_first_login_gates(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = $this->createInstitutionWithSettings();
        $inactiveInstitution = $this->createInstitutionWithSettings([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ]);
        $target = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'access_admin');
        $targetProtectedToken = $this->loginAndReturnToken($target);
        $targetLogoutToken = $this->tokenFor($target);
        $targetTokenRowsBefore = $this->tokenRowsSnapshot($target);
        $lastLoginBeforeDeactivation = $target->refresh()->last_login_at?->toJSON();
        $targetTokenCountBeforeDeactivation = PersonalAccessToken::query()->where('tokenable_id', $target->id)->count();

        $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($target), '')
            ->assertOk()
            ->assertJsonPath('data.is_active', false);
        $this->forgetAuthenticationGuards();

        $this->assertSame($targetTokenCountBeforeDeactivation, PersonalAccessToken::query()->where('tokenable_id', $target->id)->count());
        $this->assertSame($lastLoginBeforeDeactivation, $target->refresh()->last_login_at?->toJSON());
        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => 'access_admin',
            'password' => self::PASSWORD,
        ]), 403, 'user_inactive');
        $this->assertSame($targetTokenCountBeforeDeactivation, PersonalAccessToken::query()->where('tokenable_id', $target->id)->count());
        $this->assertSame($lastLoginBeforeDeactivation, $target->refresh()->last_login_at?->toJSON());
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($targetProtectedToken)->getJson('/api/v1/auth/me'),
            403,
            'user_inactive',
        );
        $this->forgetAuthenticationGuards();

        $this->withToken($targetLogoutToken)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->forgetAuthenticationGuards();
        $this->assertSame(1, PersonalAccessToken::query()->where('tokenable_id', $target->id)->count());
        $this->assertNotSame($targetTokenRowsBefore, $this->tokenRowsSnapshot($target));

        $this->authorizedRawJsonPost($platformOwner, $this->activateUri($target), '')
            ->assertOk()
            ->assertJsonPath('data.is_active', true)
            ->assertJsonPath('data.deactivated_at', null);
        $this->forgetAuthenticationGuards();

        $this->withToken($targetProtectedToken)
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', $target->id);
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($targetProtectedToken)->getJson('/api/v1/platform/dashboard'),
            403,
            'forbidden',
        );
        $this->forgetAuthenticationGuards();

        $firstLoginAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'first_login_lifecycle_admin', attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
            'must_change_password' => true,
        ]);
        $this->authorizedRawJsonPost($platformOwner, $this->activateUri($firstLoginAdmin), '')->assertOk();
        $this->forgetAuthenticationGuards();
        $firstLoginToken = $this->loginAndReturnToken($firstLoginAdmin);
        $this->forgetAuthenticationGuards();
        $this->assertErrorContract(
            $this->withToken($firstLoginToken)->getJson('/api/v1/platform/dashboard'),
            403,
            'password_change_required',
        );
        $this->assertTrue($firstLoginAdmin->refresh()->must_change_password);
        $this->forgetAuthenticationGuards();

        $inactiveInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $inactiveInstitution, loginName: 'inactive_inst_lifecycle_admin', attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->authorizedRawJsonPost($platformOwner, $this->activateUri($inactiveInstitutionAdmin), '')->assertOk();
        $this->forgetAuthenticationGuards();
        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => 'inactive_inst_lifecycle_admin',
            'password' => self::PASSWORD,
        ]), 403, 'institution_inactive');
        $this->assertNull($inactiveInstitutionAdmin->refresh()->last_login_at);
    }

    public function test_actions_use_postgresql_row_locks_noop_no_writes_preserve_overlapping_fields_and_rollback_on_failure(): void
    {
        $institution = $this->createInstitutionWithSettings();
        $admin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'action_admin', attributes: [
            'full_name' => 'Action Admin',
            'email' => 'action@example.uz',
            'phone' => '+998900000006',
        ]);

        $updateAction = new UpdatePlatformInstitutionAdmin;
        $lifecycleAction = new ChangePlatformInstitutionAdminLifecycle;

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $updated = $updateAction($admin, ['full_name' => 'Action Updated Admin']);
            $updateQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame('Action Updated Admin', $updated->full_name);
        $this->assertTrue($this->queriesContainForUpdate($updateQueries));
        $this->assertSame(1, $this->countUserUpdateQueries($updateQueries));

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $updateAction($admin->refresh(), ['full_name' => 'Action Updated Admin']);
            $noopUpdateQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertTrue($this->queriesContainForUpdate($noopUpdateQueries));
        $this->assertSame(0, $this->countUserUpdateQueries($noopUpdateQueries));

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));
        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $lifecycleAction->deactivate($admin->refresh());
            $deactivateQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
            CarbonImmutable::setTestNow();
        }

        $admin->refresh();
        $this->assertFalse($admin->is_active);
        $this->assertSame('Action Updated Admin', $admin->full_name);
        $this->assertSame('action@example.uz', $admin->email);
        $this->assertTrue($this->queriesContainForUpdate($deactivateQueries));
        $this->assertSame(1, $this->countUserUpdateQueries($deactivateQueries));

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $lifecycleAction->deactivate($admin);
            $noopLifecycleQueries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertTrue($this->queriesContainForUpdate($noopLifecycleQueries));
        $this->assertSame(0, $this->countUserUpdateQueries($noopLifecycleQueries));

        $rollbackAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'rollback_admin', attributes: [
            'full_name' => 'Rollback Admin',
        ]);
        $rollbackBefore = $this->userSnapshot($rollbackAdmin);
        DB::statement("ALTER TABLE users ADD CONSTRAINT users_s02_be_007_full_name_failure CHECK (full_name <> 'Rollback Failure Admin') NOT VALID");

        try {
            $this->assertErrorContract(
                $this->authorizedPatch($this->createUserForRole(UserRole::PlatformOwner), $rollbackAdmin, ['full_name' => 'Rollback Failure Admin']),
                500,
                'server_error',
                'rollback update',
            );
            $this->assertSame($rollbackBefore, $this->userSnapshot($rollbackAdmin));
        } finally {
            DB::statement('ALTER TABLE users DROP CONSTRAINT users_s02_be_007_full_name_failure');
            $this->forgetAuthenticationGuards();
        }

        $lifecycleRollbackAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $institution, loginName: 'lifecycle_rollback_admin');
        $lifecycleRollbackBefore = $this->userSnapshot($lifecycleRollbackAdmin);
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_s02_be_007_deactivate_failure CHECK (is_active = true) NOT VALID');

        try {
            $this->assertErrorContract(
                $this->authorizedRawJsonPost($this->createUserForRole(UserRole::PlatformOwner), $this->deactivateUri($lifecycleRollbackAdmin), ''),
                500,
                'server_error',
                'rollback lifecycle',
            );
            $this->assertSame($lifecycleRollbackBefore, $this->userSnapshot($lifecycleRollbackAdmin));
        } finally {
            DB::statement('ALTER TABLE users DROP CONSTRAINT users_s02_be_007_deactivate_failure');
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_controlled_smoke_covers_update_protected_non_admin_lifecycle_access_inactive_institution_and_retention(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $activeInstitution = $this->createInstitutionWithSettings(['name' => 'Smoke Active Institution']);
        $inactiveInstitution = $this->createInstitutionWithSettings([
            'name' => 'Smoke Inactive Institution',
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => CarbonImmutable::parse('2026-08-07 12:00:00', 'UTC'),
        ]);
        $admin = $this->createUserForRole(UserRole::InstitutionAdmin, $activeInstitution, loginName: 'smoke_lifecycle_admin', attributes: [
            'full_name' => 'Smoke Admin',
            'email' => 'smoke@example.uz',
            'phone' => '+998900000007',
        ]);
        $teacher = $this->createUserForRole(UserRole::Teacher, $activeInstitution, loginName: 'smoke_teacher');
        $inactiveInstitutionAdmin = $this->createUserForRole(UserRole::InstitutionAdmin, $inactiveInstitution, loginName: 'smoke_inactive_institution_admin', attributes: [
            'is_active' => false,
            'deactivated_at' => CarbonImmutable::parse('2026-08-07 13:00:00', 'UTC'),
        ]);
        $adminToken = $this->loginAndReturnToken($admin);
        $this->forgetAuthenticationGuards();

        $institutionsBefore = $this->institutionRowsSnapshot();
        $settingsBefore = $this->settingsSnapshot();
        $teacherBefore = $this->userSnapshot($teacher);

        $this->authorizedPatch($platformOwner, $admin, [
            'full_name' => 'Smoke Updated Admin',
            'email' => null,
            'phone' => '+998900000008',
        ])->assertOk()
            ->assertJsonPath('message', 'Institution admin updated successfully.')
            ->assertJsonPath('data.full_name', 'Smoke Updated Admin')
            ->assertJsonPath('data.email', null);
        $this->forgetAuthenticationGuards();

        $noopCount = $this->countUserUpdatesDuring(
            fn (): TestResponse => $this->authorizedPatch($platformOwner, $admin, [
                'full_name' => 'Smoke Updated Admin',
                'email' => null,
                'phone' => '+998900000008',
            ])
        );
        $this->assertSame(0, $noopCount);
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->authorizedPatch($platformOwner, $admin, ['is_active' => false]),
            422,
            'validation_failed',
            'smoke protected',
        );
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->authorizedPatch($platformOwner, $teacher, ['full_name' => 'Nope']),
            404,
            'resource_not_found',
            'smoke non admin',
        );
        $this->assertSame($teacherBefore, $this->userSnapshot($teacher));
        $this->forgetAuthenticationGuards();

        $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($admin), '')->assertOk();
        $this->forgetAuthenticationGuards();
        $deactivatedAt = $admin->refresh()->deactivated_at?->toJSON();
        $deactivatedUpdatedAt = $admin->updated_at?->toJSON();
        $this->assertFalse($admin->is_active);

        $repeatDeactivateCount = $this->countUserUpdatesDuring(
            fn (): TestResponse => $this->authorizedRawJsonPost($platformOwner, $this->deactivateUri($admin), '')
        );
        $this->assertSame(0, $repeatDeactivateCount);
        $this->assertSame($deactivatedAt, $admin->refresh()->deactivated_at?->toJSON());
        $this->assertSame($deactivatedUpdatedAt, $admin->updated_at?->toJSON());
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($adminToken)->getJson('/api/v1/auth/me'),
            403,
            'user_inactive',
            'smoke inactive token',
        );
        $this->forgetAuthenticationGuards();

        $this->authorizedRawJsonPost($platformOwner, $this->activateUri($admin), '')->assertOk();
        $this->forgetAuthenticationGuards();
        $this->withToken($adminToken)->getJson('/api/v1/auth/me')->assertOk();
        $this->forgetAuthenticationGuards();

        $repeatActivateCount = $this->countUserUpdatesDuring(
            fn (): TestResponse => $this->authorizedRawJsonPost($platformOwner, $this->activateUri($admin), '')
        );
        $this->assertSame(0, $repeatActivateCount);
        $this->forgetAuthenticationGuards();

        $this->authorizedRawJsonPost($platformOwner, $this->activateUri($inactiveInstitutionAdmin), '')->assertOk();
        $this->forgetAuthenticationGuards();
        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => 'smoke_inactive_institution_admin',
            'password' => self::PASSWORD,
        ]), 403, 'institution_inactive', 'smoke inactive institution');

        $this->assertSame($institutionsBefore, $this->institutionRowsSnapshot());
        $this->assertSame($settingsBefore, $this->settingsSnapshot());
        $this->assertSame($teacherBefore, $this->userSnapshot($teacher));
        $this->assertSame('Smoke Updated Admin', $admin->refresh()->full_name);
        $this->assertTrue($admin->is_active);
        $this->assertNull($admin->deactivated_at);
    }

    /**
     * @return array<string, callable(?User): TestResponse>
     */
    private function endpointRequestsForTarget(User $target): array
    {
        return [
            'update' => fn (?User $actor): TestResponse => $actor instanceof User
                ? $this->authorizedPatch($actor, $target, ['full_name' => 'Denied Update'])
                : $this->patchJson($this->adminUri($target), ['full_name' => 'Denied Update']),
            'activate' => fn (?User $actor): TestResponse => $actor instanceof User
                ? $this->authorizedRawJsonPost($actor, $this->activateUri($target), '')
                : $this->postJson($this->activateUri($target)),
            'deactivate' => fn (?User $actor): TestResponse => $actor instanceof User
                ? $this->authorizedRawJsonPost($actor, $this->deactivateUri($target), '')
                : $this->postJson($this->deactivateUri($target)),
        ];
    }

    /**
     * @return array<string, callable(User): TestResponse>
     */
    private function endpointRequestsForRawId(string $targetId): array
    {
        return [
            'update' => fn (User $actor): TestResponse => $this->authorizedRawJsonPatch($actor, self::BASE_URI.'/'.$targetId, '{"full_name":"Denied Update"}'),
            'activate' => fn (User $actor): TestResponse => $this->authorizedRawJsonPost($actor, self::BASE_URI.'/'.$targetId.'/activate', ''),
            'deactivate' => fn (User $actor): TestResponse => $this->authorizedRawJsonPost($actor, self::BASE_URI.'/'.$targetId.'/deactivate', ''),
        ];
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
                'login_name' => $loginName ?? 'admin_update_'.strtolower(str_replace('_', '', $role->value)).'_'.bin2hex(random_bytes(3)),
                'must_change_password' => false,
            ], $attributes));
    }

    /**
     * @return array<string, mixed>
     */
    private function protectedUpdateKeys(): array
    {
        return [
            'id' => Str::uuid()->toString(),
            'user_id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'role' => UserRole::Teacher->value,
            'login_name' => 'new_login',
            'password' => 'new password',
            'password_confirmation' => 'new password',
            'is_active' => false,
            'must_change_password' => false,
            'last_login_at' => '2026-08-10T10:00:00Z',
            'deactivated_at' => '2026-08-10T10:00:00Z',
            'created_by_user_id' => Str::uuid()->toString(),
            'created_at' => '2026-08-10T10:00:00Z',
            'updated_at' => '2026-08-10T10:00:00Z',
            'permissions' => ['all'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function protectedLifecycleKeys(): array
    {
        return [
            'is_active' => false,
            'status' => 'inactive',
            'deactivated_at' => '2026-08-10T10:00:00Z',
            'user_id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'role' => UserRole::Teacher->value,
            'reason' => 'support',
            'force' => true,
            'must_change_password' => false,
            'idempotency_key' => Str::uuid()->toString(),
        ];
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

    private function authorizedPatch(User $user, User $admin, array $payload): TestResponse
    {
        return $this->withToken($this->tokenFor($user))->patchJson($this->adminUri($admin), $payload);
    }

    private function authorizedRawJsonPatch(User $user, string $uri, string $content): TestResponse
    {
        return $this->call(
            'PATCH',
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
        return $user->createToken('platform-institution-admin-update-lifecycle-api-test', $abilities)->plainTextToken;
    }

    private function adminUri(User $admin): string
    {
        return self::BASE_URI.'/'.$admin->id;
    }

    private function activateUri(User $admin): string
    {
        return $this->adminUri($admin).'/activate';
    }

    private function deactivateUri(User $admin): string
    {
        return $this->adminUri($admin).'/deactivate';
    }

    /**
     * @return array<string, mixed>
     */
    private function userSnapshot(User $user): array
    {
        return $user->refresh()->getRawOriginal();
    }

    /**
     * @return array<string, mixed>
     */
    private function protectedUserSnapshot(User $user): array
    {
        $user->refresh();

        return [
            'id' => $user->id,
            'institution_id' => $user->institution_id,
            'role' => $user->role->value,
            'login_name' => $user->login_name,
            'password' => $user->password,
            'is_active' => $user->is_active,
            'must_change_password' => $user->must_change_password,
            'last_login_at' => $user->last_login_at?->toJSON(),
            'deactivated_at' => $user->deactivated_at?->toJSON(),
            'created_by_user_id' => $user->created_by_user_id,
            'created_at' => $user->created_at?->toJSON(),
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
    private function settingsSnapshot(): array
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
    private function tokenRowsSnapshot(?User $user = null): array
    {
        $query = PersonalAccessToken::query()
            ->when($user, fn ($query) => $query->where('tokenable_id', $user->id))
            ->orderBy('id')
            ->get();

        return $query
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

    private function assertNoUserChange(
        User $user,
        callable $request,
        int $status,
        string $code,
        string $case,
    ): void {
        $before = $this->userSnapshot($user);
        $this->assertErrorContract($request(), $status, $code, $case);
        $this->assertSame($before, $this->userSnapshot($user), $case);
    }

    private function countUserUpdatesDuring(callable $callback): int
    {
        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $callback();

            return $this->countUserUpdateQueries(DB::getQueryLog());
        } finally {
            DB::disableQueryLog();
        }
    }

    /**
     * @param  list<array<string, mixed>>  $queries
     */
    private function countUserUpdateQueries(array $queries): int
    {
        return collect($queries)
            ->filter(fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "users"'))
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

    private function assertAdminResource(
        TestResponse $response,
        string $id,
        string $fullName,
        string $loginName,
        ?string $email,
        ?string $phone,
        bool $isActive,
        bool $mustChangePassword,
        ?string $lastLoginAt,
        ?string $deactivatedAt,
        string $createdAt,
        string $updatedAt,
        string $message,
    ): void {
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame($message, $response->json('message'));

        $data = $response->json('data');
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
        ], array_keys($data));

        $this->assertSame($id, $data['id']);
        $this->assertSame($fullName, $data['full_name']);
        $this->assertSame($loginName, $data['login_name']);
        $this->assertSame($email, $data['email']);
        $this->assertSame($phone, $data['phone']);
        $this->assertSame($isActive, $data['is_active']);
        $this->assertSame($mustChangePassword, $data['must_change_password']);
        $this->assertSame($lastLoginAt, $data['last_login_at']);
        $this->assertSame($deactivatedAt, $data['deactivated_at']);
        $this->assertSame($createdAt, $data['created_at']);
        $this->assertSame($updatedAt, $data['updated_at']);

        $content = $response->getContent();
        foreach ([
            'institution_id',
            'role',
            'created_by_user_id',
            'password_hash',
            'password_confirmation',
            'remember_token',
            'token',
            'permissions',
            'institution_settings',
            'user_counts',
            'learning',
            'meta',
        ] as $forbiddenText) {
            $this->assertStringNotContainsString($forbiddenText, $content, $forbiddenText);
        }
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
