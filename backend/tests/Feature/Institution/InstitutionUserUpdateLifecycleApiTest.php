<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ChangeInstitutionUserLifecycle;
use App\Actions\Institution\UpdateInstitutionUser;
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
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Tests\TestCase;

class InstitutionUserUpdateLifecycleApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/institution/users';

    private const PASSWORD = 'Correct user password 93!';

    /** @var array<string, string> */
    private array $actorTokens = [];

    public function test_update_and_lifecycle_routes_are_registered_once_with_required_middleware_order(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => in_array($route['uri'], [
                'api/v1/institution/users/{user}',
                'api/v1/institution/users/{user}/activate',
                'api/v1/institution/users/{user}/deactivate',
            ], true) && in_array($route['methods'][0], ['PATCH', 'POST'], true))
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'];

        $this->assertSame([
            ['methods' => ['PATCH'], 'uri' => 'api/v1/institution/users/{user}', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/institution/users/{user}/activate', 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => 'api/v1/institution/users/{user}/deactivate', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_patch_updates_all_eligible_roles_and_active_states_with_exact_resource_and_preservation(): void
    {
        $institution = $this->institutionWithSettings();
        $otherInstitution = $this->institutionWithSettings(['name' => 'Foreign Institution']);
        $actor = $this->institutionAdmin($institution);
        $creator = User::factory()->institutionAdmin($institution)->create();
        User::factory()->teacher($otherInstitution)->create([
            'email' => 'shared@example.uz',
            'phone' => '+998901111111',
        ]);
        $unrelated = User::factory()->teacher($institution)->create(['login_name' => 'unrelated_patch_user']);
        $unrelatedBefore = $this->userSnapshot($unrelated);
        $institutionsBefore = $this->tableRowsSnapshot('institutions');
        $settingsBefore = $this->tableRowsSnapshot('institution_settings');

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 08:30:00', 'UTC'));

        try {
            foreach ($this->managedRoles() as $index => $role) {
                $target = $this->createUserForRole($role, $institution, [
                    'login_name' => 'patch_'.$role->value,
                    'full_name' => 'Original '.$role->value,
                    'email' => 'original'.$index.'@example.uz',
                    'phone' => '+99890000000'.$index,
                    'is_active' => $index !== 1,
                    'deactivated_at' => $index === 1 ? CarbonImmutable::parse('2026-08-10 10:00:00', 'UTC') : null,
                    'must_change_password' => true,
                    'last_login_at' => CarbonImmutable::parse('2026-08-11 10:00:00', 'UTC'),
                    'created_by_user_id' => $creator->id,
                    'created_at' => CarbonImmutable::parse('2026-08-01 10:00:00', 'UTC'),
                    'updated_at' => CarbonImmutable::parse('2026-08-12 10:00:00', 'UTC'),
                ]);
                $target->createToken('preserved-target-token-'.$index);
                $protectedBefore = $this->protectedUserSnapshot($target);
                $tokensBefore = $this->tokenRowsSnapshot($target);

                $response = $this->authorizedPatch($actor, $target->id, [
                    'full_name' => '  Updated '.$role->value.'  ',
                    'email' => 'shared@example.uz',
                    'phone' => '  +998901111111  ',
                ]);

                $response->assertOk();
                $this->assertInstitutionUserResource(
                    $response,
                    $target->id,
                    $role,
                    'Updated '.$role->value,
                    'patch_'.$role->value,
                    'shared@example.uz',
                    '+998901111111',
                    $index !== 1,
                    'Institution user updated successfully.',
                );

                $target->refresh();
                $this->assertSame($protectedBefore, $this->protectedUserSnapshot($target));
                $this->assertSame($tokensBefore, $this->tokenRowsSnapshot($target));
                $this->assertSame('2026-08-14T08:30:00.000000Z', $target->updated_at?->toJSON());
                $this->forgetAuthenticationGuards();

                $this->authorizedPatch($actor, $target->id, ['email' => null, 'phone' => null])
                    ->assertOk()
                    ->assertJsonPath('data.email', null)
                    ->assertJsonPath('data.phone', null);
                $this->forgetAuthenticationGuards();

                $this->authorizedGet($actor, self::BASE_URI.'/'.$target->id)
                    ->assertOk()
                    ->assertJsonPath('data.full_name', 'Updated '.$role->value)
                    ->assertJsonPath('data.is_active', $index !== 1);
                $this->forgetAuthenticationGuards();
            }

            $partialTarget = User::factory()->parent($institution)->create([
                'login_name' => 'partial_patch_user',
                'full_name' => 'Partial Original',
                'email' => 'partial-original@example.uz',
                'phone' => '+998900000090',
            ]);
            $this->authorizedPatch($actor, $partialTarget->id, ['full_name' => 'Partial Name'])
                ->assertOk()
                ->assertJsonPath('data.full_name', 'Partial Name')
                ->assertJsonPath('data.email', 'partial-original@example.uz')
                ->assertJsonPath('data.phone', '+998900000090');
            $this->forgetAuthenticationGuards();
            $this->authorizedPatch($actor, $partialTarget->id, ['email' => 'partial-new@example.uz'])
                ->assertOk()
                ->assertJsonPath('data.full_name', 'Partial Name')
                ->assertJsonPath('data.email', 'partial-new@example.uz')
                ->assertJsonPath('data.phone', '+998900000090');
            $this->forgetAuthenticationGuards();
            $this->authorizedPatch($actor, $partialTarget->id, ['phone' => '+998900000091'])
                ->assertOk()
                ->assertJsonPath('data.full_name', 'Partial Name')
                ->assertJsonPath('data.email', 'partial-new@example.uz')
                ->assertJsonPath('data.phone', '+998900000091');
            $this->forgetAuthenticationGuards();

            $boundaryTarget = User::factory()->teacher($institution)->create(['login_name' => 'boundary_patch_user']);
            $this->authorizedPatch($actor, $boundaryTarget->id, [
                'full_name' => str_repeat('n', 200),
                'email' => $this->emailOfLength254(),
                'phone' => str_repeat('1', 50),
            ])->assertOk()
                ->assertJsonPath('data.full_name', str_repeat('n', 200))
                ->assertJsonPath('data.email', $this->emailOfLength254())
                ->assertJsonPath('data.phone', str_repeat('1', 50));
            $this->forgetAuthenticationGuards();

            $this->authorizedGet($actor, self::BASE_URI.'?search=Updated')
                ->assertOk()
                ->assertJsonCount(3, 'data');
        } finally {
            CarbonImmutable::setTestNow();
        }

        $this->assertSame($unrelatedBefore, $this->userSnapshot($unrelated));
        $this->assertSame($institutionsBefore, $this->tableRowsSnapshot('institutions'));
        $this->assertSame($settingsBefore, $this->tableRowsSnapshot('institution_settings'));
    }

    public function test_patch_transport_shape_fields_unknown_protected_and_query_validation_is_atomic(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $target = User::factory()->teacher($institution)->create([
            'full_name' => 'Validation Target',
            'email' => 'validation@example.uz',
            'phone' => '+998900000001',
        ]);

        $bodyCases = [
            'absent' => ['', 'application/json', 'body'],
            'whitespace' => [" \r\n ", 'application/json', 'body'],
            'malformed' => ['{"full_name":', 'application/json', 'body'],
            'scalar' => ['"name"', 'application/json', 'body'],
            'array' => ['[]', 'application/json', 'body'],
            'null' => ['null', 'application/json', 'body'],
            'empty object' => ['{}', 'application/json', 'body'],
            'form' => ['full_name=Nope', 'application/x-www-form-urlencoded', 'body'],
            'multipart' => ['--boundary', 'multipart/form-data; boundary=boundary', 'body'],
            'text object' => ['{"full_name":"Nope"}', 'text/plain', 'body'],
        ];

        foreach ($bodyCases as $case => [$content, $contentType, $field]) {
            $this->assertPatchValidationWithoutMutation($actor, $target, $content, $contentType, $field, $case);
        }

        $fieldCases = [
            'null name' => [['full_name' => null], 'full_name'],
            'blank name' => [['full_name' => '   '], 'full_name'],
            'long name' => [['full_name' => str_repeat('a', 201)], 'full_name'],
            'array name' => [['full_name' => ['name']], 'full_name'],
            'blank email' => [['email' => '   '], 'email'],
            'invalid email' => [['email' => 'not-an-email'], 'email'],
            'long email' => [['email' => str_repeat('a', 244).'@example.uz'], 'email'],
            'array email' => [['email' => ['email']], 'email'],
            'blank phone' => [['phone' => '   '], 'phone'],
            'long phone' => [['phone' => str_repeat('1', 51)], 'phone'],
            'array phone' => [['phone' => ['phone']], 'phone'],
            'unknown' => [['nickname' => 'Nope'], 'nickname'],
        ];

        foreach ($fieldCases as $case => [$payload, $field]) {
            $before = $this->userSnapshot($target);
            $decoded = $this->assertErrorContract($this->authorizedPatch($actor, $target->id, $payload), 422, 'validation_failed', $case);
            $this->assertObjectHasProperty($field, $decoded->errors, $case);
            $this->assertSame($before, $this->userSnapshot($target), $case);
            $this->forgetAuthenticationGuards();
        }

        foreach ($this->protectedUpdateKeys() as $field => $value) {
            $before = $this->userSnapshot($target);
            $decoded = $this->assertErrorContract(
                $this->authorizedPatch($actor, $target->id, ['full_name' => 'Must Not Apply', $field => $value]),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertSame($before, $this->userSnapshot($target), $field);
            $this->forgetAuthenticationGuards();
        }

        foreach (['institution_id', 'full_name', 'force'] as $queryKey) {
            $before = $this->userSnapshot($target);
            $decoded = $this->assertErrorContract(
                $this->authorizedRawRequest($actor, 'PATCH', self::BASE_URI.'/'.$target->id.'?'.$queryKey.'=x', '{"full_name":"Nope"}'),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors);
            $this->assertSame($before, $this->userSnapshot($target));
            $this->forgetAuthenticationGuards();
        }

        foreach (['not-a-uuid', Str::uuid()->toString()] as $hiddenTarget) {
            $decoded = $this->assertErrorContract(
                $this->authorizedPatch($actor, $hiddenTarget, ['is_active' => false]),
                422,
                'validation_failed',
                'validation precedence',
            );
            $this->assertObjectHasProperty('is_active', $decoded->errors);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_actor_tenant_target_and_middleware_precedence_are_scope_safe_for_all_mutations(): void
    {
        $institution = $this->institutionWithSettings();
        $foreignInstitution = $this->institutionWithSettings(['name' => 'Foreign Scope Institution']);
        $actor = $this->institutionAdmin($institution);
        $target = User::factory()->teacher($institution)->create(['login_name' => 'scope_target']);
        $foreign = User::factory()->teacher($foreignInstitution)->create();
        $platformOwnerTarget = User::factory()->platformOwner()->create();
        $adminTarget = User::factory()->institutionAdmin($institution)->create();

        $hiddenIds = [
            'malformed' => 'not-a-uuid',
            'unknown' => Str::uuid()->toString(),
            'foreign' => $foreign->id,
            'platform owner' => $platformOwnerTarget->id,
            'institution admin' => $adminTarget->id,
        ];
        $safeErrors = [];

        foreach ($hiddenIds as $case => $id) {
            foreach ($this->validRequestsForId($actor, $id) as $operation => $request) {
                $before = $this->tableRowsSnapshot('users');
                $decoded = $this->assertErrorContract($request(), 404, 'resource_not_found', $case.' '.$operation);
                $safeErrors[] = [$decoded->message, $decoded->code, (array) $decoded->errors];
                $this->assertSame($before, $this->tableRowsSnapshot('users'));
                $this->forgetAuthenticationGuards();
            }
        }

        foreach ($safeErrors as $safeError) {
            $this->assertSame($safeErrors[0], $safeError);
        }

        $before = $this->userSnapshot($foreign);
        $this->withHeaders([
            'Authorization' => 'Bearer '.$this->tokenFor($actor),
            'X-Institution-ID' => $foreignInstitution->id,
        ])->patchJson(self::BASE_URI.'/'.$foreign->id, ['full_name' => 'Forged'])
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
        $this->assertSame($before, $this->userSnapshot($foreign));
        $this->forgetAuthenticationGuards();

        foreach ($this->invalidActorCases($institution) as $case => [$invalidActor, $expectedCode]) {
            foreach ($this->requestsWithInvalidInputForTarget($invalidActor, $target) as $operation => $request) {
                $before = $this->userSnapshot($target);
                $this->assertErrorContract($request(), 403, $expectedCode, $case.' '.$operation);
                $this->assertSame($before, $this->userSnapshot($target));
                $this->forgetAuthenticationGuards();
            }
        }

        foreach ($this->managedRoles() as $role) {
            $wrongRole = $this->createUserForRole($role, $institution, ['must_change_password' => false]);
            foreach ($this->requestsWithInvalidInputForTarget($wrongRole, $target) as $operation => $request) {
                $before = $this->userSnapshot($target);
                $this->assertErrorContract($request(), 403, 'forbidden', $role->value.' '.$operation);
                $this->assertSame($before, $this->userSnapshot($target));
                $this->forgetAuthenticationGuards();
            }
        }

        $this->flushHeaders();
        foreach ($this->unauthenticatedRequestsForTarget($target) as $operation => $request) {
            $before = $this->userSnapshot($target);
            $this->assertErrorContract($request(), 401, 'authentication_required', $operation);
            $this->assertSame($before, $this->userSnapshot($target));
        }
    }

    public function test_lifecycle_input_state_machine_timestamps_noops_and_token_rows_are_exact(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $target = User::factory()->student($institution)->create([
            'login_name' => 'lifecycle_target',
            'full_name' => 'Lifecycle Target',
            'updated_at' => CarbonImmutable::parse('2026-08-10 10:00:00', 'UTC'),
        ]);
        $target->createToken('lifecycle-target-token');
        $tokensBefore = $this->tokenRowsSnapshot($target);
        $protectedBefore = $this->protectedLifecycleSnapshot($target);

        foreach ($this->protectedLifecycleKeys() as $field => $value) {
            foreach (['activate', 'deactivate'] as $operation) {
                $before = $this->userSnapshot($target);
                $decoded = $this->assertErrorContract(
                    $this->authorizedRawRequest(
                        $actor,
                        'POST',
                        self::BASE_URI.'/'.$target->id.'/'.$operation,
                        json_encode([$field => $value], JSON_THROW_ON_ERROR),
                    ),
                    422,
                    'validation_failed',
                    $field.' '.$operation,
                );
                $this->assertObjectHasProperty($field, $decoded->errors);
                $this->assertSame($before, $this->userSnapshot($target));
                $this->forgetAuthenticationGuards();
            }
        }

        $invalidBodies = [
            'malformed' => ['{"force":', 'application/json', 'body'],
            'scalar' => ['"deactivate"', 'application/json', 'body'],
            'array' => ['[]', 'application/json', 'body'],
            'null' => ['null', 'application/json', 'body'],
            'form' => ['force=1', 'application/x-www-form-urlencoded', 'body'],
            'text object' => ['{}', 'text/plain', 'body'],
            'multipart' => ['--boundary', 'multipart/form-data; boundary=boundary', 'body'],
        ];

        foreach ($invalidBodies as $case => [$content, $contentType, $field]) {
            foreach (['activate', 'deactivate'] as $operation) {
                $before = $this->userSnapshot($target);
                $decoded = $this->assertErrorContract(
                    $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/'.$operation, $content, $contentType),
                    422,
                    'validation_failed',
                    $case.' '.$operation,
                );
                $this->assertObjectHasProperty($field, $decoded->errors);
                $this->assertSame($before, $this->userSnapshot($target));
                $this->forgetAuthenticationGuards();
            }
        }

        foreach (['force', 'status', 'institution_id'] as $queryKey) {
            $before = $this->userSnapshot($target);
            $decoded = $this->assertErrorContract(
                $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/deactivate?'.$queryKey.'=x', ''),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors);
            $this->assertSame($before, $this->userSnapshot($target));
            $this->forgetAuthenticationGuards();
        }

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 09:00:00', 'UTC'));

        try {
            $deactivateUpdates = $this->countUserUpdatesDuring(function () use ($actor, $target): void {
                $response = $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/deactivate', " \r\n ");
                $response->assertOk();
                $this->assertInstitutionUserResource(
                    $response,
                    $target->id,
                    UserRole::Student,
                    'Lifecycle Target',
                    'lifecycle_target',
                    $target->email,
                    $target->phone,
                    false,
                    'Institution user deactivated successfully.',
                );
            });
            $this->assertSame(1, $deactivateUpdates);
            $target->refresh();
            $this->assertSame('2026-08-14T09:00:00.000000Z', $target->deactivated_at?->toJSON());
            $this->assertSame('2026-08-14T09:00:00.000000Z', $target->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 10:00:00', 'UTC'));
            $deactivateNoopUpdates = $this->countUserUpdatesDuring(
                fn () => $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/deactivate', '')
                    ->assertOk()
                    ->assertJsonPath('message', 'Institution user deactivated successfully.')
            );
            $this->assertSame(0, $deactivateNoopUpdates);
            $target->refresh();
            $this->assertSame('2026-08-14T09:00:00.000000Z', $target->deactivated_at?->toJSON());
            $this->assertSame('2026-08-14T09:00:00.000000Z', $target->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 11:00:00', 'UTC'));
            $activateUpdates = $this->countUserUpdatesDuring(
                fn () => $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/activate', '{}')
                    ->assertOk()
                    ->assertJsonPath('message', 'Institution user activated successfully.')
            );
            $this->assertSame(1, $activateUpdates);
            $target->refresh();
            $this->assertTrue($target->is_active);
            $this->assertNull($target->deactivated_at);
            $this->assertSame('2026-08-14T11:00:00.000000Z', $target->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 12:00:00', 'UTC'));
            $activateNoopUpdates = $this->countUserUpdatesDuring(
                fn () => $this->authorizedRawRequest(
                    $actor,
                    'POST',
                    self::BASE_URI.'/'.$target->id.'/activate',
                    '{}',
                    'application/json; charset=utf-8',
                )->assertOk()
                    ->assertJsonPath('message', 'Institution user activated successfully.')
            );
            $this->assertSame(0, $activateNoopUpdates);
            $this->assertSame('2026-08-14T11:00:00.000000Z', $target->refresh()->updated_at?->toJSON());
        } finally {
            CarbonImmutable::setTestNow();
        }

        $this->assertSame($tokensBefore, $this->tokenRowsSnapshot($target));
        $this->assertSame($protectedBefore, $this->protectedLifecycleSnapshot($target));
    }

    public function test_deactivation_blocks_login_and_retained_token_until_reactivation_without_token_reconstruction(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $target = User::factory()->teacher($institution)
            ->withPassword(self::PASSWORD)
            ->create(['login_name' => 'retained_token_teacher', 'must_change_password' => false]);
        $retainedToken = $this->loginAndReturnToken($target);
        $logoutToken = $target->createToken('separately-logged-out')->plainTextToken;
        $rowsBeforeLifecycle = $this->tokenRowsSnapshot($target);
        $lastLoginBefore = $target->refresh()->last_login_at?->toJSON();

        $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/deactivate', '')
            ->assertOk()
            ->assertJsonPath('data.is_active', false);
        $this->forgetAuthenticationGuards();
        $this->assertSame($rowsBeforeLifecycle, $this->tokenRowsSnapshot($target));

        $this->assertErrorContract($this->postJson('/api/v1/auth/login', [
            'login' => $target->login_name,
            'password' => self::PASSWORD,
        ]), 403, 'user_inactive');
        $this->assertSame($lastLoginBefore, $target->refresh()->last_login_at?->toJSON());
        $this->assertSame($rowsBeforeLifecycle, $this->tokenRowsSnapshot($target));
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract($this->withToken($retainedToken)->getJson('/api/v1/auth/me'), 403, 'user_inactive');
        $this->forgetAuthenticationGuards();

        $this->withToken($logoutToken)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->forgetAuthenticationGuards();
        $rowsAfterLogout = $this->tokenRowsSnapshot($target);
        $this->assertCount(count($rowsBeforeLifecycle) - 1, $rowsAfterLogout);

        $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/activate', '')
            ->assertOk()
            ->assertJsonPath('data.is_active', true);
        $this->forgetAuthenticationGuards();
        $this->assertSame($rowsAfterLogout, $this->tokenRowsSnapshot($target));

        $this->withToken($retainedToken)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', $target->id);
        $this->forgetAuthenticationGuards();
        $this->assertErrorContract($this->withToken($retainedToken)->getJson('/api/v1/platform/dashboard'), 403, 'forbidden');
        $this->forgetAuthenticationGuards();

        $firstLoginTarget = User::factory()->student($institution)->inactive()->withPassword(self::PASSWORD)->create([
            'login_name' => 'first_login_reactivated_student',
            'must_change_password' => true,
        ]);
        $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$firstLoginTarget->id.'/activate', '')->assertOk();
        $this->forgetAuthenticationGuards();
        $firstLoginToken = $this->loginAndReturnToken($firstLoginTarget);
        $this->forgetAuthenticationGuards();
        $this->assertErrorContract($this->withToken($firstLoginToken)->getJson('/api/v1/institution/dashboard'), 403, 'password_change_required');
        $this->assertTrue($firstLoginTarget->refresh()->must_change_password);
        $this->forgetAuthenticationGuards();

        $inactiveInstitution = $this->institutionWithSettings([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ]);
        $inactiveInstitutionTarget = User::factory()->parent($inactiveInstitution)->inactive()->withPassword(self::PASSWORD)->create([
            'login_name' => 'inactive_institution_reactivated_parent',
            'must_change_password' => false,
        ]);
        $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$inactiveInstitutionTarget->id.'/activate', '')
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
        $this->assertFalse($inactiveInstitutionTarget->refresh()->is_active);
    }

    public function test_actions_use_scoped_postgresql_row_locks_fresh_state_noop_writes_and_safe_rollback(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $target = User::factory()->teacher($institution)->create([
            'full_name' => 'Action Target',
            'email' => 'action@example.uz',
            'phone' => '+998900000010',
        ]);
        $foreign = User::factory()->teacher($this->institutionWithSettings())->create();
        $update = new UpdateInstitutionUser;
        $lifecycle = new ChangeInstitutionUserLifecycle;

        $staleTarget = $target->fresh();
        [$updated, $updateQueries] = $this->captureQueries(fn (): User => $update($actor, $target->id, ['full_name' => 'Fresh Name']));
        $this->assertSame('Fresh Name', $updated->full_name);
        $this->assertTrue($this->queriesContainScopedForUpdate($updateQueries, $institution->id, $target->id));
        $this->assertSame(1, $this->countUserUpdateQueries($updateQueries));

        [$noop, $noopQueries] = $this->captureQueries(fn (): User => $update($actor, $target->id, ['full_name' => 'Fresh Name']));
        $this->assertSame('Fresh Name', $noop->full_name);
        $this->assertTrue($this->queriesContainScopedForUpdate($noopQueries, $institution->id, $target->id));
        $this->assertSame(0, $this->countUserUpdateQueries($noopQueries));

        $update($actor, $target->id, ['phone' => '+998900000011']);
        $update($actor, $target->id, ['email' => 'fresh@example.uz']);
        $lifecycle->deactivate($actor, $target->id);
        $target->refresh();
        $this->assertSame('Fresh Name', $target->full_name);
        $this->assertSame('+998900000011', $target->phone);
        $this->assertSame('fresh@example.uz', $target->email);
        $this->assertFalse($target->is_active);
        $this->assertSame('Action Target', $staleTarget?->full_name);

        [, $sameDirectionQueries] = $this->captureQueries(fn (): User => $lifecycle->deactivate($actor, $target->id));
        $this->assertSame(0, $this->countUserUpdateQueries($sameDirectionQueries));
        $lifecycle->activate($actor, $target->id);
        $this->assertTrue($target->refresh()->is_active);
        $this->assertNull($target->deactivated_at);

        foreach ([
            fn (): User => $update($actor, 'not-a-uuid', ['full_name' => 'Nope']),
            fn (): User => $update($actor, $foreign->id, ['full_name' => 'Nope']),
            fn (): User => $lifecycle->deactivate($actor, $foreign->id),
        ] as $operation) {
            try {
                $operation();
                $this->fail('Expected scope-safe not found exception.');
            } catch (NotFoundHttpException) {
                $this->addToAssertionCount(1);
            }
        }

        $updateFailureTarget = User::factory()->student($institution)->create(['full_name' => 'Rollback Update']);
        $updateBefore = $this->userSnapshot($updateFailureTarget);
        DB::statement("ALTER TABLE users ADD CONSTRAINT users_s03_be_005_update_failure CHECK (full_name <> 'Forced Update Failure') NOT VALID");

        try {
            $response = $this->authorizedPatch($actor, $updateFailureTarget->id, ['full_name' => 'Forced Update Failure']);
            $this->assertSafeServerError($response, 'Forced Update Failure');
            $this->assertSame($updateBefore, $this->userSnapshot($updateFailureTarget));
        } finally {
            DB::statement('ALTER TABLE users DROP CONSTRAINT users_s03_be_005_update_failure');
            $this->forgetAuthenticationGuards();
        }

        $lifecycleFailureTarget = User::factory()->parent($institution)->create();
        $lifecycleBefore = $this->userSnapshot($lifecycleFailureTarget);
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_s03_be_005_lifecycle_failure CHECK (is_active = true) NOT VALID');

        try {
            $response = $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$lifecycleFailureTarget->id.'/deactivate', '');
            $this->assertSafeServerError($response, 'users_s03_be_005_lifecycle_failure');
            $this->assertSame($lifecycleBefore, $this->userSnapshot($lifecycleFailureTarget));
        } finally {
            DB::statement('ALTER TABLE users DROP CONSTRAINT users_s03_be_005_lifecycle_failure');
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_controlled_postgresql_process_races_serialize_patch_and_lifecycle_operations(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $workerPath = tempnam(sys_get_temp_dir(), 's03_be_005_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $setup = $this->runWorker([$workerPath, base_path(), 'setup']);
        $ids = json_decode($setup, true, flags: JSON_THROW_ON_ERROR);

        try {
            $tokensBefore = PersonalAccessToken::query()
                ->whereIn('tokenable_id', array_values($ids['targets']))
                ->orderBy('id')
                ->get()
                ->map(fn (PersonalAccessToken $token): array => $token->getRawOriginal())
                ->all();

            $patchRace = $this->runRace($workerPath, $ids['actor'], $ids['targets']['patch'], 'name', 'phone');
            $patchTarget = User::query()->findOrFail($ids['targets']['patch']);
            $this->assertSame('Concurrent Name', $patchTarget->full_name);
            $this->assertSame('+998909999999', $patchTarget->phone);
            $this->assertSame([1, 1], [$patchRace['first_updates'], $patchRace['second_updates']]);

            $mixedRace = $this->runRace($workerPath, $ids['actor'], $ids['targets']['mixed'], 'email', 'deactivate');
            $mixedTarget = User::query()->findOrFail($ids['targets']['mixed']);
            $this->assertSame('concurrent@example.uz', $mixedTarget->email);
            $this->assertFalse($mixedTarget->is_active);
            $this->assertNotNull($mixedTarget->deactivated_at);
            $this->assertSame([1, 1], [$mixedRace['first_updates'], $mixedRace['second_updates']]);

            $sameRace = $this->runRace($workerPath, $ids['actor'], $ids['targets']['same'], 'deactivate', 'deactivate');
            $sameTarget = User::query()->findOrFail($ids['targets']['same']);
            $this->assertFalse($sameTarget->is_active);
            $this->assertNotNull($sameTarget->deactivated_at);
            $this->assertSame([1, 0], [$sameRace['first_updates'], $sameRace['second_updates']]);

            $oppositeRace = $this->runRace($workerPath, $ids['actor'], $ids['targets']['opposite'], 'deactivate', 'activate');
            $oppositeTarget = User::query()->findOrFail($ids['targets']['opposite']);
            $this->assertTrue($oppositeTarget->is_active);
            $this->assertNull($oppositeTarget->deactivated_at);
            $this->assertSame([1, 1], [$oppositeRace['first_updates'], $oppositeRace['second_updates']]);

            $tokensAfter = PersonalAccessToken::query()
                ->whereIn('tokenable_id', array_values($ids['targets']))
                ->orderBy('id')
                ->get()
                ->map(fn (PersonalAccessToken $token): array => $token->getRawOriginal())
                ->all();
            $this->assertSame($tokensBefore, $tokensAfter);
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            unlink($workerPath);
        }
    }

    public function test_controlled_smoke_covers_update_denial_lifecycle_retention_and_read_visibility(): void
    {
        $institution = $this->institutionWithSettings(['name' => 'Smoke Institution']);
        $foreignInstitution = $this->institutionWithSettings(['name' => 'Smoke Foreign Institution']);
        $actor = $this->institutionAdmin($institution);
        $active = User::factory()->teacher($institution)->create(['full_name' => 'Smoke Active']);
        $inactive = User::factory()->student($institution)->inactive()->create(['full_name' => 'Smoke Inactive']);
        $foreign = User::factory()->parent($foreignInstitution)->create();
        $active->createToken('smoke-preserved');
        $tokensBefore = $this->tokenRowsSnapshot($active);
        $foreignBefore = $this->userSnapshot($foreign);

        $this->authorizedPatch($actor, $active->id, ['full_name' => 'Smoke Updated'])
            ->assertOk()
            ->assertJsonPath('data.full_name', 'Smoke Updated');
        $this->forgetAuthenticationGuards();
        $updatedAt = $active->refresh()->updated_at?->toJSON();

        $this->authorizedPatch($actor, $active->id, ['full_name' => '  Smoke Updated  '])->assertOk();
        $this->assertSame($updatedAt, $active->refresh()->updated_at?->toJSON());
        $this->forgetAuthenticationGuards();

        $this->authorizedPatch($actor, $inactive->id, ['phone' => '+998900001212'])
            ->assertOk()
            ->assertJsonPath('data.is_active', false);
        $this->forgetAuthenticationGuards();

        $this->authorizedPatch($actor, $active->id, ['password' => 'forged'])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed');
        $this->forgetAuthenticationGuards();
        $this->authorizedPatch($actor, $foreign->id, ['full_name' => 'Forged'])
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
        $this->assertSame($foreignBefore, $this->userSnapshot($foreign));
        $this->forgetAuthenticationGuards();

        $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$active->id.'/deactivate', '')
            ->assertOk()
            ->assertJsonPath('data.is_active', false);
        $deactivatedAt = $active->refresh()->deactivated_at?->toJSON();
        $deactivatedUpdatedAt = $active->updated_at?->toJSON();
        $this->forgetAuthenticationGuards();

        $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$active->id.'/deactivate', '')->assertOk();
        $this->assertSame($deactivatedAt, $active->refresh()->deactivated_at?->toJSON());
        $this->assertSame($deactivatedUpdatedAt, $active->updated_at?->toJSON());
        $this->forgetAuthenticationGuards();

        $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$active->id.'/activate', '{}')
            ->assertOk()
            ->assertJsonPath('data.is_active', true);
        $this->forgetAuthenticationGuards();

        $this->authorizedGet($actor, self::BASE_URI.'/'.$active->id)
            ->assertOk()
            ->assertJsonPath('data.full_name', 'Smoke Updated')
            ->assertJsonPath('data.is_active', true);
        $this->assertSame($tokensBefore, $this->tokenRowsSnapshot($active));
    }

    /** @return list<UserRole> */
    private function managedRoles(): array
    {
        return [UserRole::Teacher, UserRole::Student, UserRole::Parent];
    }

    private function institutionWithSettings(array $attributes = []): Institution
    {
        $institution = Institution::factory()->create($attributes);
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);

        return $institution;
    }

    private function institutionAdmin(Institution $institution, array $attributes = []): User
    {
        return User::factory()->institutionAdmin($institution)->create(array_merge([
            'must_change_password' => false,
        ], $attributes));
    }

    private function createUserForRole(UserRole $role, Institution $institution, array $attributes = []): User
    {
        $factory = match ($role) {
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
            UserRole::PlatformOwner => User::factory()->platformOwner(),
        };

        return $factory->create($attributes);
    }

    private function authorizedPatch(User $actor, string $targetId, array $payload): TestResponse
    {
        return $this->withToken($this->tokenFor($actor))->patchJson(self::BASE_URI.'/'.$targetId, $payload);
    }

    private function authorizedGet(User $actor, string $uri): TestResponse
    {
        return $this->call(
            'GET',
            $uri,
            [],
            [],
            [],
            [
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$this->tokenFor($actor),
            ],
            '',
        );
    }

    private function authorizedRawRequest(
        User $actor,
        string $method,
        string $uri,
        string $content,
        string $contentType = 'application/json',
    ): TestResponse {
        return $this->call(
            $method,
            $uri,
            [],
            [],
            [],
            [
                'CONTENT_TYPE' => $contentType,
                'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$this->tokenFor($actor),
            ],
            $content,
        );
    }

    private function tokenFor(User $user): string
    {
        return $this->actorTokens[$user->id]
            ??= $user->createToken('institution-user-update-lifecycle-api-test')->plainTextToken;
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

    private function assertPatchValidationWithoutMutation(
        User $actor,
        User $target,
        string $content,
        string $contentType,
        string $field,
        string $case,
    ): void {
        $before = $this->userSnapshot($target);
        $decoded = $this->assertErrorContract(
            $this->authorizedRawRequest($actor, 'PATCH', self::BASE_URI.'/'.$target->id, $content, $contentType),
            422,
            'validation_failed',
            $case,
        );
        $this->assertObjectHasProperty($field, $decoded->errors, $case);
        $this->assertSame($before, $this->userSnapshot($target), $case);
        $this->forgetAuthenticationGuards();
    }

    /** @return array<string, mixed> */
    private function protectedUpdateKeys(): array
    {
        return [
            'id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'role' => UserRole::Parent->value,
            'login_name' => 'forged_login',
            'password' => 'forged password',
            'password_confirmation' => 'forged password',
            'is_active' => false,
            'must_change_password' => false,
            'last_login_at' => '2026-08-14T10:00:00Z',
            'deactivated_at' => '2026-08-14T10:00:00Z',
            'created_by_user_id' => Str::uuid()->toString(),
            'created_at' => '2026-08-14T10:00:00Z',
            'updated_at' => '2026-08-14T10:00:00Z',
            'remember_token' => 'secret',
            'permissions' => ['all'],
            'abilities' => ['all'],
            'token' => 'secret',
            'tokens' => ['secret'],
            'institution' => ['id' => Str::uuid()->toString()],
            'creator' => ['id' => Str::uuid()->toString()],
            'relationships' => [],
            'groups' => [],
            'settings' => [],
            'learning_data' => [],
        ];
    }

    /** @return array<string, mixed> */
    private function protectedLifecycleKeys(): array
    {
        return [
            'is_active' => false,
            'status' => 'inactive',
            'deactivated_at' => '2026-08-14T10:00:00Z',
            'user_id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'role' => UserRole::Teacher->value,
            'reason' => 'support',
            'force' => true,
            'must_change_password' => false,
            'idempotency_key' => Str::uuid()->toString(),
        ];
    }

    /** @return array<string, callable(): TestResponse> */
    private function validRequestsForId(User $actor, string $id): array
    {
        return [
            'update' => fn (): TestResponse => $this->authorizedPatch($actor, $id, ['full_name' => 'Valid Update']),
            'activate' => fn (): TestResponse => $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$id.'/activate', ''),
            'deactivate' => fn (): TestResponse => $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$id.'/deactivate', ''),
        ];
    }

    /** @return array<string, array{0: User, 1: string}> */
    private function invalidActorCases(Institution $institution): array
    {
        $inactiveInstitution = $this->institutionWithSettings([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ]);

        return [
            'inactive actor' => [$this->institutionAdmin($institution, ['is_active' => false, 'deactivated_at' => now()]), 'user_inactive'],
            'inactive actor institution' => [$this->institutionAdmin($inactiveInstitution), 'institution_inactive'],
            'password gate' => [$this->institutionAdmin($institution, ['must_change_password' => true]), 'password_change_required'],
            'platform owner' => [User::factory()->platformOwner()->create(), 'forbidden'],
        ];
    }

    /** @return array<string, callable(): TestResponse> */
    private function requestsWithInvalidInputForTarget(User $actor, User $target): array
    {
        return [
            'update' => fn (): TestResponse => $this->authorizedPatch($actor, $target->id, ['is_active' => false]),
            'activate' => fn (): TestResponse => $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/activate', '{"force":true}'),
            'deactivate' => fn (): TestResponse => $this->authorizedRawRequest($actor, 'POST', self::BASE_URI.'/'.$target->id.'/deactivate', '{"force":true}'),
        ];
    }

    /** @return array<string, callable(): TestResponse> */
    private function unauthenticatedRequestsForTarget(User $target): array
    {
        return [
            'update' => fn (): TestResponse => $this->patchJson(self::BASE_URI.'/'.$target->id, ['is_active' => false]),
            'activate' => fn (): TestResponse => $this->postJson(self::BASE_URI.'/'.$target->id.'/activate', ['force' => true]),
            'deactivate' => fn (): TestResponse => $this->postJson(self::BASE_URI.'/'.$target->id.'/deactivate', ['force' => true]),
        ];
    }

    private function emailOfLength254(): string
    {
        return str_repeat('a', 63).'@'.str_repeat('b', 62).'.'.str_repeat('c', 62).'.'.str_repeat('d', 60).'.com';
    }

    /** @return array<string, mixed> */
    private function userSnapshot(User $user): array
    {
        return $user->refresh()->getRawOriginal();
    }

    /** @return array<string, mixed> */
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

    /** @return array<string, mixed> */
    private function protectedLifecycleSnapshot(User $user): array
    {
        $snapshot = $this->protectedUserSnapshot($user);
        unset($snapshot['is_active'], $snapshot['deactivated_at']);

        return $snapshot;
    }

    /** @return list<array<string, mixed>> */
    private function tableRowsSnapshot(string $table): array
    {
        $orderBy = $table === 'institution_settings' ? 'institution_id' : 'id';

        return DB::table($table)->orderBy($orderBy)->get()->map(fn ($row): array => (array) $row)->all();
    }

    /** @return list<array<string, mixed>> */
    private function tokenRowsSnapshot(User $user): array
    {
        return PersonalAccessToken::query()
            ->where('tokenable_id', $user->id)
            ->orderBy('id')
            ->get()
            ->map(fn (PersonalAccessToken $token): array => $token->getRawOriginal())
            ->all();
    }

    private function countUserUpdatesDuring(callable $callback): int
    {
        [, $queries] = $this->captureQueries($callback);

        return $this->countUserUpdateQueries($queries);
    }

    /** @return array{0: mixed, 1: list<array<string, mixed>>} */
    private function captureQueries(callable $callback): array
    {
        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $result = $callback();
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        return [$result, $queries];
    }

    /** @param list<array<string, mixed>> $queries */
    private function countUserUpdateQueries(array $queries): int
    {
        return collect($queries)
            ->filter(fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "users"'))
            ->count();
    }

    /** @param list<array<string, mixed>> $queries */
    private function queriesContainScopedForUpdate(array $queries, string $institutionId, string $targetId): bool
    {
        return collect($queries)->contains(function (array $query) use ($institutionId, $targetId): bool {
            $sql = strtolower((string) $query['query']);
            $bindings = array_map(static fn ($binding): string => (string) $binding, $query['bindings']);

            return str_contains($sql, 'for update')
                && str_contains($sql, '"institution_id"')
                && str_contains($sql, '"role" in')
                && in_array($institutionId, $bindings, true)
                && in_array($targetId, $bindings, true);
        });
    }

    private function assertInstitutionUserResource(
        TestResponse $response,
        string $id,
        UserRole $role,
        string $fullName,
        string $loginName,
        ?string $email,
        ?string $phone,
        bool $isActive,
        string $message,
    ): void {
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame($message, $response->json('message'));
        $data = $response->json('data');
        $this->assertSame([
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
        ], array_keys($data));
        $this->assertSame($id, $data['id']);
        $this->assertSame($role->value, $data['role']);
        $this->assertSame($fullName, $data['full_name']);
        $this->assertSame($loginName, $data['login_name']);
        $this->assertSame($email, $data['email']);
        $this->assertSame($phone, $data['phone']);
        $this->assertSame($isActive, $data['is_active']);
        $this->assertIsBool($data['must_change_password']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $data['created_at']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $data['updated_at']);

        foreach (['last_login_at', 'deactivated_at'] as $nullableTimestamp) {
            if ($data[$nullableTimestamp] !== null) {
                $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $data[$nullableTimestamp]);
            }
        }

        $content = $response->getContent();
        foreach ([
            'institution_id',
            'created_by_user_id',
            'password_hash',
            'password_confirmation',
            'remember_token',
            'abilities',
            'tokens',
            'permissions',
            'relationships',
            'settings',
            'learning_data',
            'meta',
            'links',
        ] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $content);
        }
    }

    private function assertSafeServerError(TestResponse $response, string $internalDetail): void
    {
        $decoded = $this->assertErrorContract($response, 500, 'server_error');
        $content = json_encode($decoded, JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString($internalDetail, $content);
        $this->assertStringNotContainsString('SQLSTATE', $content);
        $this->assertStringNotContainsString('stack', strtolower($content));
        $this->assertStringNotContainsString('token', strtolower($content));
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    private function assertErrorContract(TestResponse $response, int $status, string $code, string $case = ''): object
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

    /** @return array{first_updates: int, second_updates: int} */
    private function runRace(string $workerPath, string $actorId, string $targetId, string $firstOperation, string $secondOperation): array
    {
        $lockedPath = $this->unusedTempPath('s03_be_005_locked_');
        $releasePath = $this->unusedTempPath('s03_be_005_release_');
        $firstAttemptPath = $this->unusedTempPath('s03_be_005_attempt_first_');
        $secondAttemptPath = $this->unusedTempPath('s03_be_005_attempt_second_');
        $first = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $targetId,
            $firstOperation,
            'hold',
            $lockedPath,
            $releasePath,
            $firstAttemptPath,
        ]);
        $this->waitForFile($lockedPath, 'First worker did not acquire and hold the PostgreSQL user row lock.');
        $second = $this->startWorker([
            $workerPath,
            base_path(),
            'run',
            $actorId,
            $targetId,
            $secondOperation,
            'normal',
            $lockedPath,
            $releasePath,
            $secondAttemptPath,
        ]);
        $this->waitForFile($secondAttemptPath, 'Second worker did not begin its user locking operation.');

        try {
            $this->waitForPostgresLock(
                (int) file_get_contents($secondAttemptPath),
                $firstOperation.' -> '.$secondOperation.' for user '.$targetId,
            );
        } catch (\Throwable $exception) {
            file_put_contents($releasePath, 'release');
            $secondOutput = $this->finishWorker($second);
            $firstOutput = $this->finishWorker($first);
            $this->removeTempPaths([$lockedPath, $releasePath, $firstAttemptPath, $secondAttemptPath]);
            $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
        }

        file_put_contents($releasePath, 'release');
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        $this->removeTempPaths([$lockedPath, $releasePath, $firstAttemptPath, $secondAttemptPath]);

        return [
            'first_updates' => $firstResult['updates'],
            'second_updates' => $secondResult['updates'],
        ];
    }

    private function unusedTempPath(string $prefix): string
    {
        $path = tempnam(sys_get_temp_dir(), $prefix);
        $this->assertIsString($path);
        unlink($path);

        return $path;
    }

    private function waitForFile(string $path, string $failureMessage): void
    {
        $deadline = microtime(true) + 10;

        do {
            clearstatcache(true, $path);

            if (file_exists($path) && filesize($path) > 0) {
                return;
            }

            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail($failureMessage);
    }

    private function waitForPostgresLock(int $backendPid, string $scenario): void
    {
        $deadline = microtime(true) + 10;
        $lastActivity = null;

        do {
            DB::select('select pg_stat_clear_snapshot()');
            $lastActivity = DB::selectOne(
                'select wait_event_type, wait_event from pg_stat_activity where pid = ?',
                [$backendPid],
            );

            if ($lastActivity !== null && $lastActivity->wait_event_type === 'Lock') {
                $this->assertNotNull($lastActivity->wait_event);

                return;
            }

            usleep(5_000);
        } while (microtime(true) < $deadline);

        $this->fail(sprintf(
            'Second worker never entered a PostgreSQL user row-lock wait during %s. Last activity: %s',
            $scenario,
            json_encode($lastActivity, JSON_THROW_ON_ERROR),
        ));
    }

    /** @return array{process: resource, pipes: array<int, resource>} */
    private function startWorker(array $arguments): array
    {
        $command = array_merge([PHP_BINARY], $arguments);
        $pipes = [];
        $process = proc_open($command, [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);
        $this->assertIsResource($process);
        fclose($pipes[0]);

        return ['process' => $process, 'pipes' => $pipes];
    }

    /** @param array{process: resource, pipes: array<int, resource>} $worker */
    private function finishWorker(array $worker): string
    {
        $stdout = stream_get_contents($worker['pipes'][1]);
        $stderr = stream_get_contents($worker['pipes'][2]);
        fclose($worker['pipes'][1]);
        fclose($worker['pipes'][2]);
        $exitCode = proc_close($worker['process']);
        $this->assertSame(0, $exitCode, $stderr."\nSTDOUT: ".$stdout);

        return trim($stdout);
    }

    private function runWorker(array $arguments): string
    {
        return $this->finishWorker($this->startWorker($arguments));
    }

    /** @param list<string> $paths */
    private function removeTempPaths(array $paths): void
    {
        foreach ($paths as $path) {
            if (file_exists($path)) {
                unlink($path);
            }
        }
    }

    private function postgresConcurrencyWorkerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Institution\ChangeInstitutionUserLifecycle;
use App\Actions\Institution\UpdateInstitutionUser;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;

$basePath = $argv[1];
$mode = $argv[2];
require $basePath.'/vendor/autoload.php';
$app = require $basePath.'/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.example');
$app->make(Kernel::class)->bootstrap();

if ($mode === 'setup') {
    $institution = Institution::factory()->create(['name' => 'S03 BE 005 concurrency institution']);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $actor = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $targets = [];

    foreach (['patch', 'mixed', 'same', 'opposite'] as $name) {
        $target = User::factory()->teacher($institution)->create([
            'login_name' => 's03_be_005_concurrency_'.$name.'_'.bin2hex(random_bytes(4)),
            'must_change_password' => false,
        ]);
        $target->createToken('concurrency-preserved-token');
        $targets[$name] = $target->id;
    }

    echo json_encode(['institution' => $institution->id, 'actor' => $actor->id, 'targets' => $targets], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo '{}';
    exit(0);
}

$actor = User::query()->findOrFail($argv[3]);
$targetId = $argv[4];
$operation = $argv[5];
$hold = $argv[6] === 'hold';
$lockedPath = $argv[7];
$releasePath = $argv[8];
$attemptPath = $argv[9];
$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);
DB::flushQueryLog();
DB::enableQueryLog();

if ($hold) {
    DB::beginTransaction();
}

try {
    match ($operation) {
        'name' => (new UpdateInstitutionUser)($actor, $targetId, ['full_name' => 'Concurrent Name']),
        'phone' => (new UpdateInstitutionUser)($actor, $targetId, ['phone' => '+998909999999']),
        'email' => (new UpdateInstitutionUser)($actor, $targetId, ['email' => 'concurrent@example.uz']),
        'activate' => (new ChangeInstitutionUserLifecycle)->activate($actor, $targetId),
        'deactivate' => (new ChangeInstitutionUserLifecycle)->deactivate($actor, $targetId),
    };

    $queries = DB::getQueryLog();

    if ($hold) {
        file_put_contents($lockedPath, 'locked');
        $deadline = microtime(true) + 10;

        do {
            clearstatcache(true, $releasePath);

            if (file_exists($releasePath)) {
                break;
            }

            usleep(5_000);
        } while (microtime(true) < $deadline);

        if (! file_exists($releasePath)) {
            DB::rollBack();
            fwrite(STDERR, 'Timed out waiting for deterministic user race release.');
            exit(1);
        }

        DB::commit();
    }

    $updates = count(array_filter($queries, static fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "users"')));
    echo json_encode(['updates' => $updates], JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    if ($hold && DB::transactionLevel() > 0) {
        DB::rollBack();
    }

    fwrite(STDERR, $exception::class.': '.$exception->getMessage());
    exit(1);
}
PHP;
    }
}
