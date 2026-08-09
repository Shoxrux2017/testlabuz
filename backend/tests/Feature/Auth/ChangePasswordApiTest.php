<?php

namespace Tests\Feature\Auth;

use App\Enums\InstitutionStatus;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class ChangePasswordApiTest extends TestCase
{
    use RefreshDatabase;

    private const CURRENT_PASSWORD = 'Correct test password 93! with enough length';

    private const NEW_PASSWORD = 'Changed test password 49! with enough length';

    private const PASSWORD_GATED_TEST_URI = '/api/v1/testing/password-gated';

    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware(['auth:sanctum', 'active.account', 'password.changed'])
            ->get(self::PASSWORD_GATED_TEST_URI, fn () => response()->json([
                'data' => ['ok' => true],
            ]));
    }

    public function test_change_password_requires_authentication(): void
    {
        $this->assertErrorContract(
            $this->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload()),
            401,
            'authentication_required',
        );
    }

    public function test_change_password_request_validation_uses_locked_error_contract(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'validation_teacher');
        $token = $this->loginAndReturnToken($user);

        $cases = [
            'missing current password' => [
                array_diff_key($this->validPasswordChangePayload(), ['current_password' => true]),
                'current_password',
            ],
            'missing new password' => [
                array_diff_key($this->validPasswordChangePayload(), ['new_password' => true]),
                'new_password',
            ],
            'missing confirmation' => [
                array_diff_key($this->validPasswordChangePayload(), ['new_password_confirmation' => true]),
                'new_password_confirmation',
            ],
            'confirmation mismatch' => [
                array_merge($this->validPasswordChangePayload(), ['new_password_confirmation' => 'different password']),
                'new_password',
            ],
            'too short new password' => [
                array_merge($this->validPasswordChangePayload(), [
                    'new_password' => 'short',
                    'new_password_confirmation' => 'short',
                ]),
                'new_password',
            ],
            'too long new password' => [
                array_merge($this->validPasswordChangePayload(), [
                    'new_password' => str_repeat('a', 256),
                    'new_password_confirmation' => str_repeat('a', 256),
                ]),
                'new_password',
            ],
            'new password equal to current password input' => [
                [
                    'current_password' => self::CURRENT_PASSWORD,
                    'new_password' => self::CURRENT_PASSWORD,
                    'new_password_confirmation' => self::CURRENT_PASSWORD,
                ],
                'new_password',
            ],
        ];

        foreach ($cases as $case => [$payload, $expectedField]) {
            $response = $this->withToken($token)->postJson('/api/v1/auth/change-password', $payload);

            $decoded = $this->assertErrorContract($response, 422, 'validation_failed', $case);
            $this->assertObjectHasProperty($expectedField, $decoded->errors, $case);
            $this->assertIsArray($decoded->errors->{$expectedField}, $case);

            $user->refresh();
            $this->assertTrue(Hash::check(self::CURRENT_PASSWORD, $user->password), $case);
            $this->assertTrue($user->must_change_password, $case);
        }
    }

    public function test_wrong_current_password_returns_conflict_without_changing_state(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'wrong_current_teacher');
        $token = $this->loginAndReturnToken($user);
        $originalHash = $user->password;

        $response = $this->withToken($token)->postJson('/api/v1/auth/change-password', [
            'current_password' => 'wrong current password',
            'new_password' => self::NEW_PASSWORD,
            'new_password_confirmation' => self::NEW_PASSWORD,
        ]);

        $decoded = $this->assertErrorContract($response, 409, 'current_password_invalid');
        $this->assertSame([], get_object_vars($decoded->errors));
        $this->assertStringNotContainsString('wrong current password', $response->getContent());
        $this->assertStringNotContainsString(self::NEW_PASSWORD, $response->getContent());

        $user->refresh();
        $this->assertSame($originalHash, $user->password);
        $this->assertTrue($user->must_change_password);
        $this->assertTrue(Hash::check(self::CURRENT_PASSWORD, $user->password));

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();
    }

    public function test_successful_first_login_change_works_for_each_institution_role(): void
    {
        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $this->forgetAuthenticationGuards();

            $institution = $this->createInstitutionWithSettings();
            $user = $this->createUserForRole($role, $institution, 'first_change_'.$role->value);
            $token = $this->loginAndReturnToken($user);

            $originalRole = $user->role;
            $originalInstitutionId = $user->institution_id;
            $originalActiveState = $user->is_active;

            $response = $this->withToken($token)->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload());

            $response->assertNoContent();
            $this->assertSame('', $response->getContent());

            $user->refresh();
            $this->assertFalse($user->must_change_password);
            $this->assertSame($originalRole, $user->role);
            $this->assertSame($originalInstitutionId, $user->institution_id);
            $this->assertSame($originalActiveState, $user->is_active);
            $this->assertNotSame(self::NEW_PASSWORD, $user->password);
            $this->assertTrue(Hash::check(self::NEW_PASSWORD, $user->password));
            $this->assertFalse(Hash::check(self::CURRENT_PASSWORD, $user->password));

            $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
                'login' => $user->login_name,
                'password' => self::CURRENT_PASSWORD,
            ]), 401, 'invalid_credentials');

            $newLoginResponse = $this->postJson('/api/v1/auth/login', [
                'login' => $user->login_name,
                'password' => self::NEW_PASSWORD,
            ]);

            $newLoginResponse->assertOk();
            $this->assertFalse($newLoginResponse->json('data.user.must_change_password'));

            $this->forgetAuthenticationGuards();
        }
    }

    public function test_platform_owner_can_change_password_without_first_login_flag(): void
    {
        $user = $this->createUserForRole(UserRole::PlatformOwner, loginName: 'normal_platform_owner');
        $token = $this->loginAndReturnToken($user);

        $this->assertFalse($user->must_change_password);

        $this->withToken($token)
            ->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload())
            ->assertNoContent();

        $user->refresh();
        $this->assertFalse($user->must_change_password);
        $this->assertNull($user->institution_id);
        $this->assertSame(UserRole::PlatformOwner, $user->role);
        $this->assertTrue($user->is_active);
        $this->assertTrue(Hash::check(self::NEW_PASSWORD, $user->password));

        $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => self::NEW_PASSWORD,
        ])->assertOk();
    }

    public function test_change_password_uses_active_user_and_institution_checks(): void
    {
        $inactiveUser = $this->createUserForRole(UserRole::Teacher, loginName: 'inactive_change_teacher');
        $inactiveUserToken = $this->loginAndReturnToken($inactiveUser);
        $inactiveUser->forceFill([
            'is_active' => false,
            'deactivated_at' => now(),
        ])->save();

        $this->assertErrorContract(
            $this->withToken($inactiveUserToken)->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload()),
            403,
            'user_inactive',
        );

        $this->withToken($inactiveUserToken)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->forgetAuthenticationGuards();

        $institution = $this->createInstitutionWithSettings();
        $inactiveInstitutionUser = $this->createUserForRole(UserRole::Teacher, $institution, 'inactive_institution_change');
        $inactiveInstitutionToken = $this->loginAndReturnToken($inactiveInstitutionUser);
        $institution->forceFill([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ])->save();

        $this->assertErrorContract(
            $this->withToken($inactiveInstitutionToken)->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload()),
            403,
            'institution_inactive',
        );

        $this->withToken($inactiveInstitutionToken)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->forgetAuthenticationGuards();
    }

    public function test_first_login_users_can_use_only_allowed_auth_endpoints(): void
    {
        $currentUser = $this->createUserForRole(UserRole::Teacher, loginName: 'allowed_me_teacher');
        $this->withToken($this->loginAndReturnToken($currentUser))
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.must_change_password', true);
        $this->forgetAuthenticationGuards();

        $passwordUser = $this->createUserForRole(UserRole::Student, loginName: 'allowed_change_student');
        $this->withToken($this->loginAndReturnToken($passwordUser))
            ->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload())
            ->assertNoContent();
        $this->forgetAuthenticationGuards();

        $logoutUser = $this->createUserForRole(UserRole::Parent, loginName: 'allowed_logout_parent');
        $this->withToken($this->loginAndReturnToken($logoutUser))
            ->postJson('/api/v1/auth/logout')
            ->assertNoContent();
        $this->forgetAuthenticationGuards();
    }

    public function test_password_gate_denies_until_successful_password_change(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'gated_teacher');
        $token = $this->loginAndReturnToken($user);

        $blocked = $this->withToken($token)->getJson(self::PASSWORD_GATED_TEST_URI);
        $decoded = $this->assertErrorContract($blocked, 403, 'password_change_required');
        $this->assertSame([], get_object_vars($decoded->errors));

        $this->withToken($token)
            ->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload())
            ->assertNoContent();
        $this->forgetAuthenticationGuards();

        $this->withToken($token)
            ->getJson(self::PASSWORD_GATED_TEST_URI)
            ->assertOk()
            ->assertJsonPath('data.ok', true);
    }

    public function test_password_gate_allows_users_who_already_changed_password(): void
    {
        $user = $this->createUserForRole(UserRole::Student, loginName: 'already_changed_student', attributes: [
            'must_change_password' => false,
        ]);
        $token = $this->loginAndReturnToken($user);

        $this->withToken($token)
            ->getJson(self::PASSWORD_GATED_TEST_URI)
            ->assertOk()
            ->assertJsonPath('data.ok', true);
    }

    public function test_password_gate_runs_after_authentication_and_active_state_checks(): void
    {
        $this->assertErrorContract($this->getJson(self::PASSWORD_GATED_TEST_URI), 401, 'authentication_required');

        $inactiveUser = $this->createUserForRole(UserRole::Teacher, loginName: 'gate_inactive_user');
        $inactiveUserToken = $this->loginAndReturnToken($inactiveUser);
        $inactiveUser->forceFill([
            'is_active' => false,
            'deactivated_at' => now(),
        ])->save();

        $this->assertErrorContract($this->withToken($inactiveUserToken)->getJson(self::PASSWORD_GATED_TEST_URI), 403, 'user_inactive');
        $this->forgetAuthenticationGuards();

        $institution = $this->createInstitutionWithSettings();
        $inactiveInstitutionUser = $this->createUserForRole(UserRole::Parent, $institution, 'gate_inactive_institution');
        $inactiveInstitutionToken = $this->loginAndReturnToken($inactiveInstitutionUser);
        $institution->forceFill([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ])->save();

        $this->assertErrorContract(
            $this->withToken($inactiveInstitutionToken)->getJson(self::PASSWORD_GATED_TEST_URI),
            403,
            'institution_inactive',
        );
        $this->forgetAuthenticationGuards();

        $mustChangeUser = $this->createUserForRole(UserRole::Teacher, loginName: 'gate_must_change');
        $mustChangeToken = $this->loginAndReturnToken($mustChangeUser);

        $this->assertErrorContract(
            $this->withToken($mustChangeToken)->getJson(self::PASSWORD_GATED_TEST_URI),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $changedUser = $this->createUserForRole(UserRole::Teacher, loginName: 'gate_changed', attributes: [
            'must_change_password' => false,
        ]);

        $this->withToken($this->loginAndReturnToken($changedUser))
            ->getJson(self::PASSWORD_GATED_TEST_URI)
            ->assertOk()
            ->assertJsonPath('data.ok', true);
    }

    public function test_password_change_preserves_existing_tokens_and_returns_no_new_token(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'token_preservation_teacher', attributes: [
            'must_change_password' => false,
        ]);
        $tokenA = $this->loginAndReturnToken($user);
        $tokenB = $this->loginAndReturnToken($user);

        $this->assertSame(2, PersonalAccessToken::query()->count());

        $response = $this->withToken($tokenA)->postJson('/api/v1/auth/change-password', $this->validPasswordChangePayload());

        $response->assertNoContent();
        $this->assertSame('', $response->getContent());
        $this->assertSame(2, PersonalAccessToken::query()->count());

        $this->forgetAuthenticationGuards();
        $this->withToken($tokenA)->getJson('/api/v1/auth/me')->assertOk();
        $this->forgetAuthenticationGuards();
        $this->withToken($tokenB)->getJson('/api/v1/auth/me')->assertOk();
    }

    /**
     * @return array<string, string>
     */
    private function validPasswordChangePayload(): array
    {
        return [
            'current_password' => self::CURRENT_PASSWORD,
            'new_password' => self::NEW_PASSWORD,
            'new_password_confirmation' => self::NEW_PASSWORD,
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
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution ?? $this->createInstitutionWithSettings()),
            UserRole::Teacher => User::factory()->teacher($institution ?? $this->createInstitutionWithSettings()),
            UserRole::Student => User::factory()->student($institution ?? $this->createInstitutionWithSettings()),
            UserRole::Parent => User::factory()->parent($institution ?? $this->createInstitutionWithSettings()),
        };

        return $factory
            ->withPassword(self::CURRENT_PASSWORD)
            ->create(array_merge([
                'login_name' => $loginName ?? 'login_'.strtolower(str_replace('_', '', $role->value)).'_'.bin2hex(random_bytes(3)),
            ], $attributes));
    }

    private function loginAndReturnToken(User $user, string $password = self::CURRENT_PASSWORD): string
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => $password,
        ]);

        $response->assertOk();

        return (string) $response->json('data.token');
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    private function assertErrorContract($response, int $status, string $code, string $case = ''): object
    {
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
