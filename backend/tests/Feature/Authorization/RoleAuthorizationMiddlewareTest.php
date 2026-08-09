<?php

namespace Tests\Feature\Authorization;

use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class RoleAuthorizationMiddlewareTest extends TestCase
{
    use RefreshDatabase;

    private const ROUTE_PREFIX = '/api/v1/testing/authorization';

    protected function setUp(): void
    {
        parent::setUp();

        foreach (UserRole::cases() as $role) {
            Route::middleware($this->protectedMiddleware('role:'.$role->value))
                ->get(self::ROUTE_PREFIX.'/'.$role->value, fn () => response()->json([
                    'data' => ['allowed_role' => $role->value],
                ]));
        }

        Route::middleware($this->protectedMiddleware('role:teacher,student'))
            ->get(self::ROUTE_PREFIX.'/teacher-student', fn () => response()->json([
                'data' => ['allowed_roles' => [UserRole::Teacher->value, UserRole::Student->value]],
            ]));

        Route::middleware($this->protectedMiddleware('role:not_a_real_role'))
            ->get(self::ROUTE_PREFIX.'/invalid-role', fn () => response()->json([
                'data' => ['should_not_be_reached' => true],
            ]));
    }

    public function test_single_role_surfaces_allow_only_matching_persisted_roles(): void
    {
        $usersByRole = $this->createUsersByRole();
        $tokensByRole = $this->tokensByRole($usersByRole);
        $allowedResponses = 0;
        $deniedResponses = 0;

        foreach (UserRole::cases() as $surfaceRole) {
            foreach (UserRole::cases() as $actorRole) {
                $response = $this->withToken($tokensByRole[$actorRole->value])
                    ->getJson($this->singleRoleUri($surfaceRole));

                if ($surfaceRole === $actorRole) {
                    $response->assertOk()
                        ->assertJsonPath('data.allowed_role', $surfaceRole->value);
                    $allowedResponses++;
                } else {
                    $this->assertForbidden($response, $surfaceRole->value.' surface denied '.$actorRole->value);
                    $deniedResponses++;
                }

                $this->forgetAuthenticationGuards();
            }
        }

        $this->assertSame(5, $allowedResponses);
        $this->assertSame(20, $deniedResponses);
    }

    public function test_multi_role_surface_allows_only_teacher_and_student(): void
    {
        $usersByRole = $this->createUsersByRole();
        $tokensByRole = $this->tokensByRole($usersByRole);
        $allowedRoles = [UserRole::Teacher, UserRole::Student];

        foreach (UserRole::cases() as $actorRole) {
            $response = $this->withToken($tokensByRole[$actorRole->value])
                ->getJson(self::ROUTE_PREFIX.'/teacher-student');

            if (in_array($actorRole, $allowedRoles, true)) {
                $response->assertOk()
                    ->assertJsonPath('data.allowed_roles', [UserRole::Teacher->value, UserRole::Student->value]);
            } else {
                $this->assertForbidden($response, 'teacher+student surface denied '.$actorRole->value);
            }

            $this->forgetAuthenticationGuards();
        }
    }

    public function test_role_security_order_preserves_accepted_precedence(): void
    {
        $this->assertErrorContract(
            $this->getJson($this->singleRoleUri(UserRole::Teacher)),
            401,
            'authentication_required',
        );

        $inactiveUser = $this->createUserForRole(UserRole::Teacher, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertErrorContract(
            $this->withToken($this->tokenFor($inactiveUser))->getJson($this->singleRoleUri(UserRole::Teacher)),
            403,
            'user_inactive',
        );
        $this->forgetAuthenticationGuards();

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $inactiveInstitutionUser = $this->createUserForRole(UserRole::Teacher, $inactiveInstitution);
        $this->assertErrorContract(
            $this->withToken($this->tokenFor($inactiveInstitutionUser))->getJson($this->singleRoleUri(UserRole::Teacher)),
            403,
            'institution_inactive',
        );
        $this->forgetAuthenticationGuards();

        $mustChangeWrongRoleUser = $this->createUserForRole(UserRole::Student, attributes: [
            'must_change_password' => true,
        ]);
        $this->assertErrorContract(
            $this->withToken($this->tokenFor($mustChangeWrongRoleUser))->getJson($this->singleRoleUri(UserRole::Teacher)),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        $wrongRoleUser = $this->createUserForRole(UserRole::Student);
        $this->assertForbidden(
            $this->withToken($this->tokenFor($wrongRoleUser))->getJson($this->singleRoleUri(UserRole::Teacher)),
            'password-complete wrong role',
        );
        $this->forgetAuthenticationGuards();

        $correctRoleUser = $this->createUserForRole(UserRole::Teacher);
        $this->withToken($this->tokenFor($correctRoleUser))
            ->getJson($this->singleRoleUri(UserRole::Teacher))
            ->assertOk()
            ->assertJsonPath('data.allowed_role', UserRole::Teacher->value);
    }

    public function test_client_supplied_role_values_and_token_abilities_cannot_elevate_persisted_role(): void
    {
        $student = $this->createUserForRole(UserRole::Student);
        $teacher = $this->createUserForRole(UserRole::Teacher);
        $studentTokenWithTeacherAbilities = $this->tokenFor($student, ['teacher', 'role:teacher']);
        $spoofedRequestHeaders = [
            'X-User-Role' => UserRole::Teacher->value,
            'X-Role' => UserRole::Teacher->value,
        ];

        $this->assertForbidden(
            $this->withToken($studentTokenWithTeacherAbilities)
                ->withHeaders($spoofedRequestHeaders)
                ->getJson($this->singleRoleUri(UserRole::Teacher).'?role=teacher&institution_id='.$teacher->institution_id),
            'persisted student cannot spoof teacher capability',
        );
        $this->forgetAuthenticationGuards();

        $this->withToken($studentTokenWithTeacherAbilities)
            ->withHeaders($spoofedRequestHeaders)
            ->getJson($this->singleRoleUri(UserRole::Student).'?role=teacher&institution_id='.$teacher->institution_id)
            ->assertOk()
            ->assertJsonPath('data.allowed_role', UserRole::Student->value);
    }

    public function test_platform_owner_is_explicit_not_a_universal_bypass(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $token = $this->tokenFor($platformOwner);

        $this->withToken($token)
            ->getJson($this->singleRoleUri(UserRole::PlatformOwner))
            ->assertOk()
            ->assertJsonPath('data.allowed_role', UserRole::PlatformOwner->value);
        $this->forgetAuthenticationGuards();

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $surfaceRole) {
            $this->assertForbidden(
                $this->withToken($token)->getJson($this->singleRoleUri($surfaceRole)),
                'platform owner denied '.$surfaceRole->value.' surface',
            );
            $this->forgetAuthenticationGuards();
        }

        $this->assertForbidden(
            $this->withToken($token)->getJson(self::ROUTE_PREFIX.'/teacher-student'),
            'platform owner denied teacher+student surface',
        );
    }

    public function test_invalid_server_role_configuration_fails_closed_for_every_role(): void
    {
        foreach ($this->createUsersByRole() as $roleValue => $user) {
            $this->assertForbidden(
                $this->withToken($this->tokenFor($user))->getJson(self::ROUTE_PREFIX.'/invalid-role'),
                'invalid role configuration denied '.$roleValue,
            );
            $this->forgetAuthenticationGuards();
        }
    }

    /**
     * @param  list<string>  $additionalMiddleware
     * @return list<string>
     */
    private function protectedMiddleware(string ...$additionalMiddleware): array
    {
        return array_merge(['auth:sanctum', 'active.account', 'password.changed'], $additionalMiddleware);
    }

    /**
     * @return array<string, User>
     */
    private function createUsersByRole(): array
    {
        $usersByRole = [];

        foreach (UserRole::cases() as $role) {
            $usersByRole[$role->value] = $this->createUserForRole($role);
        }

        return $usersByRole;
    }

    /**
     * @param  array<string, User>  $usersByRole
     * @return array<string, string>
     */
    private function tokensByRole(array $usersByRole): array
    {
        $tokensByRole = [];

        foreach ($usersByRole as $roleValue => $user) {
            $tokensByRole[$roleValue] = $this->tokenFor($user);
        }

        return $tokensByRole;
    }

    private function createUserForRole(
        UserRole $role,
        ?Institution $institution = null,
        array $attributes = [],
    ): User {
        $factory = match ($role) {
            UserRole::PlatformOwner => User::factory()->platformOwner(),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution ?? Institution::factory()->create()),
            UserRole::Teacher => User::factory()->teacher($institution ?? Institution::factory()->create()),
            UserRole::Student => User::factory()->student($institution ?? Institution::factory()->create()),
            UserRole::Parent => User::factory()->parent($institution ?? Institution::factory()->create()),
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
        return $user->createToken('role-authorization-test', $abilities)->plainTextToken;
    }

    private function singleRoleUri(UserRole $role): string
    {
        return self::ROUTE_PREFIX.'/'.$role->value;
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    private function assertForbidden($response, string $case = ''): object
    {
        return $this->assertErrorContract($response, 403, 'forbidden', $case);
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
        $this->assertSame([], get_object_vars($decoded->errors), $case);

        return $decoded;
    }
}
