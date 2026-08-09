<?php

namespace Tests\Feature\Auth;

use App\Enums\InstitutionStatus;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use App\Support\Auth\LoginRateLimitKey;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class AuthenticationSessionApiTest extends TestCase
{
    use RefreshDatabase;

    private const PASSWORD = 'Correct test password 93! with enough length';

    public function test_login_validation_returns_locked_error_contract(): void
    {
        $cases = [
            'missing login' => [[], 'login'],
            'empty login' => [['login' => ''], 'login'],
            'oversized login' => [['login' => str_repeat('a', 192)], 'login'],
            'missing password' => [['login' => 'teacher01'], 'password'],
            'empty password' => [['login' => 'teacher01', 'password' => ''], 'password'],
        ];

        foreach ($cases as $case => [$payload, $expectedField]) {
            $response = $this->postJson('/api/v1/auth/login', $payload);

            $decoded = $this->assertErrorContract($response, 422, 'validation_failed', $case);
            $this->assertObjectHasProperty($expectedField, $decoded->errors, $case);
            $this->assertIsArray($decoded->errors->{$expectedField}, $case);
        }
    }

    public function test_successful_login_returns_locked_shape_for_every_role(): void
    {
        foreach (UserRole::cases() as $role) {
            $user = $this->createUserForRole($role, loginName: 'login_'.$role->value);

            $response = $this->postJson('/api/v1/auth/login', [
                'login' => $user->login_name,
                'password' => self::PASSWORD,
            ]);

            $response->assertOk();
            $data = $response->json('data');

            $this->assertSame(['token', 'token_type', 'user'], array_keys($data));
            $this->assertIsString($data['token']);
            $this->assertNotSame('', $data['token']);
            $this->assertSame('Bearer', $data['token_type']);

            $this->assertLoginUserPayloadMatches($data['user'], $user->refresh());
            $this->assertSame($role === UserRole::PlatformOwner ? null : $user->institution_id, $data['user']['institution_id']);

            $this->assertArrayNotHasKey('password', $data['user']);
            $this->assertArrayNotHasKey('remember_token', $data['user']);
            $this->assertArrayNotHasKey('tokens', $data['user']);
            $this->assertArrayNotHasKey('created_by_user_id', $data['user']);

            if ($role !== UserRole::PlatformOwner) {
                $this->assertTrue($data['user']['must_change_password']);
            }
        }
    }

    public function test_unknown_login_and_wrong_password_return_indistinguishable_invalid_credentials(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'known_teacher');

        $unknownLoginResponse = $this->postJson('/api/v1/auth/login', [
            'login' => 'unknown_teacher',
            'password' => 'wrong password',
        ]);

        $wrongPasswordResponse = $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => 'wrong password',
        ]);

        $unknownLoginError = $this->assertErrorContract($unknownLoginResponse, 401, 'invalid_credentials');
        $wrongPasswordError = $this->assertErrorContract($wrongPasswordResponse, 401, 'invalid_credentials');

        $this->assertSame($unknownLoginError->message, $wrongPasswordError->message);
        $this->assertEquals($unknownLoginError->errors, $wrongPasswordError->errors);
        $this->assertSame(0, PersonalAccessToken::query()->count());
        $this->assertNull($user->refresh()->last_login_at);
    }

    public function test_inactive_user_with_valid_credentials_is_denied_without_token_or_login_timestamp(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'inactive_teacher', attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => self::PASSWORD,
        ]);

        $this->assertErrorContract($response, 403, 'user_inactive');
        $this->assertSame(0, PersonalAccessToken::query()->count());
        $this->assertNull($user->refresh()->last_login_at);
    }

    public function test_inactive_institution_user_with_valid_credentials_is_denied_without_token_or_login_timestamp(): void
    {
        $institution = $this->createInstitutionWithSettings([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ]);
        $user = $this->createUserForRole(UserRole::Teacher, $institution, 'inactive_institution_teacher');

        $response = $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => self::PASSWORD,
        ]);

        $this->assertErrorContract($response, 403, 'institution_inactive');
        $this->assertSame(0, PersonalAccessToken::query()->count());
        $this->assertNull($user->refresh()->last_login_at);
    }

    public function test_client_supplied_role_and_institution_never_become_authority(): void
    {
        $realInstitution = $this->createInstitutionWithSettings();
        $otherInstitution = $this->createInstitutionWithSettings();
        $user = $this->createUserForRole(UserRole::Teacher, $realInstitution, 'real_teacher');

        $response = $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => self::PASSWORD,
            'role' => UserRole::PlatformOwner->value,
            'institution_id' => $otherInstitution->id,
            'is_active' => false,
            'must_change_password' => false,
        ]);

        $response->assertOk();
        $payload = $response->json('data.user');

        $this->assertSame(UserRole::Teacher->value, $payload['role']);
        $this->assertSame($realInstitution->id, $payload['institution_id']);
        $this->assertTrue($payload['is_active']);
        $this->assertTrue($payload['must_change_password']);
    }

    public function test_successful_login_persists_hashed_sanctum_token_and_updates_last_login_at(): void
    {
        $user = $this->createUserForRole(UserRole::Student, loginName: 'token_student');

        $response = $this->postJson('/api/v1/auth/login', [
            'login' => $user->login_name,
            'password' => self::PASSWORD,
        ]);

        $response->assertOk();
        $plainTextToken = $response->json('data.token');
        $persistedToken = PersonalAccessToken::query()->sole();

        $this->assertSame(User::class, $persistedToken->tokenable_type);
        $this->assertSame($user->id, $persistedToken->tokenable_id);
        $this->assertSame('flutter-client', $persistedToken->name);
        $this->assertSame(['*'], $persistedToken->abilities);
        $this->assertNotSame($plainTextToken, $persistedToken->token);
        $this->assertSame(64, strlen($persistedToken->token));
        $this->assertNotNull($user->refresh()->last_login_at);
    }

    public function test_login_rate_limiter_preserves_invalid_credentials_before_threshold_then_returns_rate_limited(): void
    {
        $login = 'rate_limited_unknown';
        $ip = '198.51.100.10';
        $password = 'not the password';

        $this->clearLoginLimiter($login, $ip);

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->postLoginFromIp($ip, [
                'login' => $login,
                'password' => $password,
            ])->assertUnauthorized();
        }

        $response = $this->postLoginFromIp($ip, [
            'login' => $login,
            'password' => $password,
        ]);

        $this->assertErrorContract($response, 429, 'rate_limited');
        $this->assertStringNotContainsString($password, LoginRateLimitKey::limiterKey($login, $ip));
        $this->assertStringNotContainsString($password, LoginRateLimitKey::throttleCacheKey($login, $ip));
    }

    public function test_successful_login_clears_the_matching_login_rate_limiter_key(): void
    {
        $ip = '198.51.100.11';
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'reset_limiter_teacher');

        $this->clearLoginLimiter($user->login_name, $ip);

        for ($attempt = 1; $attempt <= 4; $attempt++) {
            $this->postLoginFromIp($ip, [
                'login' => $user->login_name,
                'password' => 'wrong password',
            ])->assertUnauthorized();
        }

        $this->postLoginFromIp($ip, [
            'login' => $user->login_name,
            'password' => self::PASSWORD,
        ])->assertOk();

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->postLoginFromIp($ip, [
                'login' => $user->login_name,
                'password' => 'wrong password',
            ])->assertUnauthorized();
        }

        $this->assertErrorContract($this->postLoginFromIp($ip, [
            'login' => $user->login_name,
            'password' => 'wrong password',
        ]), 429, 'rate_limited');
    }

    public function test_current_user_requires_token_and_returns_exact_institution_context(): void
    {
        $institution = $this->createInstitutionWithSettings();
        $user = $this->createUserForRole(UserRole::Teacher, $institution, 'current_teacher');

        $this->assertErrorContract($this->getJson('/api/v1/auth/me'), 401, 'authentication_required');

        $token = $this->loginAndReturnToken($user);
        $response = $this->withToken($token)->getJson('/api/v1/auth/me');

        $response->assertOk();
        $data = $response->json('data');

        $this->assertSame([
            'id',
            'institution_id',
            'role',
            'full_name',
            'login_name',
            'email',
            'phone',
            'is_active',
            'must_change_password',
            'institution',
        ], array_keys($data));

        $this->assertCurrentUserPayloadMatches($data, $user->refresh());
        $this->assertSame([
            'id' => $institution->id,
            'name' => $institution->name,
            'status' => InstitutionStatus::Active->value,
            'timezone' => $institution->setting->timezone,
        ], $data['institution']);
        $this->assertSame('Asia/Tashkent', $data['institution']['timezone']);
        $this->assertArrayNotHasKey('password', $data);
        $this->assertArrayNotHasKey('token', $data);
        $this->assertArrayNotHasKey('created_by_user_id', $data);
    }

    public function test_current_user_returns_null_institution_for_platform_owner(): void
    {
        $user = $this->createUserForRole(UserRole::PlatformOwner, loginName: 'current_platform_owner');
        $token = $this->loginAndReturnToken($user);

        $response = $this->withToken($token)->getJson('/api/v1/auth/me');

        $response->assertOk();
        $data = $response->json('data');

        $this->assertCurrentUserPayloadMatches($data, $user->refresh());
        $this->assertNull($data['institution_id']);
        $this->assertNull($data['institution']);
    }

    public function test_existing_token_loses_normal_access_after_user_deactivation(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'deactivated_token_teacher');
        $token = $this->loginAndReturnToken($user);

        $user->forceFill([
            'is_active' => false,
            'deactivated_at' => now(),
        ])->save();

        $response = $this->withToken($token)->getJson('/api/v1/auth/me');

        $this->assertErrorContract($response, 403, 'user_inactive');
    }

    public function test_existing_token_loses_normal_access_after_institution_deactivation(): void
    {
        $institution = $this->createInstitutionWithSettings();
        $user = $this->createUserForRole(UserRole::Parent, $institution, 'deactivated_institution_parent');
        $token = $this->loginAndReturnToken($user);

        $institution->forceFill([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ])->save();

        $response = $this->withToken($token)->getJson('/api/v1/auth/me');

        $this->assertErrorContract($response, 403, 'institution_inactive');
    }

    public function test_logout_revokes_current_token_and_returns_empty_no_content_response(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'logout_teacher');
        $token = $this->loginAndReturnToken($user);

        $response = $this->withToken($token)->postJson('/api/v1/auth/logout');

        $response->assertNoContent();
        $this->assertSame('', $response->getContent());
        $this->assertSame(0, PersonalAccessToken::query()->count());

        $this->forgetAuthenticationGuards();

        $this->assertErrorContract($this->withToken($token)->getJson('/api/v1/auth/me'), 401, 'authentication_required');
    }

    public function test_logout_revokes_only_the_current_token(): void
    {
        $user = $this->createUserForRole(UserRole::Student, loginName: 'multi_token_student');
        $tokenA = $this->loginAndReturnToken($user);
        $tokenB = $this->loginAndReturnToken($user);

        $this->assertSame(2, PersonalAccessToken::query()->count());

        $this->withToken($tokenA)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->forgetAuthenticationGuards();
        $this->assertErrorContract($this->withToken($tokenA)->getJson('/api/v1/auth/me'), 401, 'authentication_required');

        $this->forgetAuthenticationGuards();
        $this->withToken($tokenB)->getJson('/api/v1/auth/me')->assertOk();
        $this->assertSame(1, PersonalAccessToken::query()->count());
    }

    public function test_logout_remains_available_after_user_or_institution_deactivation(): void
    {
        $user = $this->createUserForRole(UserRole::Teacher, loginName: 'cleanup_inactive_user');
        $userToken = $this->loginAndReturnToken($user);

        $user->forceFill([
            'is_active' => false,
            'deactivated_at' => now(),
        ])->save();

        $this->withToken($userToken)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->forgetAuthenticationGuards();

        $institution = $this->createInstitutionWithSettings();
        $institutionUser = $this->createUserForRole(UserRole::Parent, $institution, 'cleanup_inactive_institution');
        $institutionToken = $this->loginAndReturnToken($institutionUser);

        $institution->forceFill([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ])->save();

        $this->withToken($institutionToken)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->assertSame(0, PersonalAccessToken::query()->count());
    }

    public function test_must_change_password_flag_is_returned_but_not_enforced_yet(): void
    {
        $user = $this->createUserForRole(UserRole::InstitutionAdmin, loginName: 'must_change_admin', attributes: [
            'must_change_password' => true,
        ]);

        $token = $this->loginAndReturnToken($user);

        $response = $this->withToken($token)->getJson('/api/v1/auth/me');

        $response->assertOk();
        $this->assertTrue($response->json('data.must_change_password'));
        $this->assertErrorContract($this->postJson('/api/v1/auth/change-password'), 404, 'resource_not_found');
    }

    public function test_only_locked_auth_routes_are_registered(): void
    {
        $authRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
            ])
            ->filter(fn (array $route): bool => str_starts_with($route['uri'], 'api/v1/auth'))
            ->values()
            ->all();

        $this->assertSame([
            ['methods' => ['POST'], 'uri' => 'api/v1/auth/login'],
            ['methods' => ['POST'], 'uri' => 'api/v1/auth/logout'],
            ['methods' => ['GET'], 'uri' => 'api/v1/auth/me'],
        ], $authRoutes);
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
            ->withPassword(self::PASSWORD)
            ->create(array_merge([
                'login_name' => $loginName ?? 'login_'.strtolower(str_replace('_', '', $role->value)).'_'.bin2hex(random_bytes(3)),
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

    private function postLoginFromIp(string $ip, array $payload)
    {
        return $this->withServerVariables(['REMOTE_ADDR' => $ip])
            ->postJson('/api/v1/auth/login', $payload);
    }

    private function clearLoginLimiter(string $login, string $ip): void
    {
        RateLimiter::clear(LoginRateLimitKey::throttleCacheKey($login, $ip));
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    private function assertLoginUserPayloadMatches(array $payload, User $user): void
    {
        $this->assertSame([
            'id',
            'institution_id',
            'role',
            'full_name',
            'login_name',
            'email',
            'phone',
            'is_active',
            'must_change_password',
        ], array_keys($payload));
        $this->assertSame($user->id, $payload['id']);
        $this->assertSame($user->institution_id, $payload['institution_id']);
        $this->assertSame($user->role->value, $payload['role']);
        $this->assertSame($user->full_name, $payload['full_name']);
        $this->assertSame($user->login_name, $payload['login_name']);
        $this->assertSame($user->email, $payload['email']);
        $this->assertSame($user->phone, $payload['phone']);
        $this->assertSame($user->is_active, $payload['is_active']);
        $this->assertSame($user->must_change_password, $payload['must_change_password']);
    }

    private function assertCurrentUserPayloadMatches(array $payload, User $user): void
    {
        $this->assertSame($user->id, $payload['id']);
        $this->assertSame($user->institution_id, $payload['institution_id']);
        $this->assertSame($user->role->value, $payload['role']);
        $this->assertSame($user->full_name, $payload['full_name']);
        $this->assertSame($user->login_name, $payload['login_name']);
        $this->assertSame($user->email, $payload['email']);
        $this->assertSame($user->phone, $payload['phone']);
        $this->assertSame($user->is_active, $payload['is_active']);
        $this->assertSame($user->must_change_password, $payload['must_change_password']);
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
