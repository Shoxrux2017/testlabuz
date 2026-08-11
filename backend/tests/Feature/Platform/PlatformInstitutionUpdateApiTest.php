<?php

namespace Tests\Feature\Platform;

use App\Actions\Platform\CreatePlatformInstitution;
use App\Enums\BlitzTimerStartMode;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class PlatformInstitutionUpdateApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/platform/institutions';

    public function test_patch_route_is_registered_with_required_middleware_order_only_under_platform_path(): void
    {
        $platformInstitutionUpdateRoutes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/platform/institutions/{institution}')
            ->filter(fn (array $route): bool => in_array('PATCH', $route['methods'], true))
            ->values()
            ->all();

        $this->assertSame([
            [
                'methods' => ['PATCH'],
                'uri' => 'api/v1/platform/institutions/{institution}',
                'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:platform_owner'],
            ],
        ], $platformInstitutionUpdateRoutes);

        $unexpectedInstitutionPatchRoutes = collect(Route::getRoutes())
            ->filter(fn ($route): bool => in_array('PATCH', array_values(array_diff($route->methods(), ['HEAD'])), true))
            ->map(fn ($route): string => $route->uri())
            ->filter(fn (string $uri): bool => $uri !== 'api/v1/platform/institutions/{institution}')
            ->filter(fn (string $uri): bool => str_contains($uri, 'institutions'))
            ->values()
            ->all();

        $this->assertSame([], $unexpectedInstitutionPatchRoutes);
    }

    public function test_active_password_complete_platform_owner_updates_active_institution_with_exact_response_and_no_related_side_effects(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'));

        try {
            $creator = $this->createUserForRole(UserRole::PlatformOwner);
            $institution = Institution::factory()->create([
                'name' => 'Original School',
                'type' => InstitutionType::School,
                'status' => InstitutionStatus::Active,
                'contact_email' => 'old@example.uz',
                'contact_phone' => '+998 90 000 00 00',
                'address' => 'Old address',
                'description' => 'Old description',
                'created_by_user_id' => $creator->id,
                'deactivated_at' => null,
                'created_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
                'updated_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
            ]);
            $setting = $this->createConfiguredSetting($institution, $creator);
            User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
            User::factory()->teacher($institution)->inactive()->create(['must_change_password' => false]);
            $otherInstitution = Institution::factory()->create([
                'name' => 'Other Institution',
                'contact_email' => 'other@example.uz',
            ]);

            $protectedBefore = $this->protectedInstitutionSnapshot($institution);
            $settingBefore = $this->settingSnapshot($setting);
            $usersBefore = $this->usersSnapshot($institution);
            $otherInstitutionBefore = $this->rawInstitutionSnapshot($otherInstitution);

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));
            $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

            $response = $this->authorizedPatch($platformOwner, $institution, [
                'name' => '  Updated Name  ',
                'type' => InstitutionType::University->value,
                'contact_email' => 'updated@example.uz',
                'contact_phone' => '+998 90 123 45 67',
                'address' => 'Updated address',
                'description' => null,
            ]);

            $response->assertOk();
            $this->assertSame(['data', 'message'], array_keys($response->json()));
            $this->assertSame('Institution updated successfully.', $response->json('message'));

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
            $this->assertSame($institution->id, $data['id']);
            $this->assertSame('Updated Name', $data['name']);
            $this->assertSame(InstitutionType::University->value, $data['type']);
            $this->assertSame(InstitutionStatus::Active->value, $data['status']);
            $this->assertSame('updated@example.uz', $data['contact_email']);
            $this->assertSame('+998 90 123 45 67', $data['contact_phone']);
            $this->assertSame('Updated address', $data['address']);
            $this->assertNull($data['description']);
            $this->assertSame('2026-08-07T15:00:00Z', $data['created_at']);
            $this->assertSame('2026-08-10T12:00:00Z', $data['updated_at']);

            $institution->refresh();
            $this->assertSame('Updated Name', $institution->name);
            $this->assertSame(InstitutionType::University, $institution->type);
            $this->assertSame('updated@example.uz', $institution->contact_email);
            $this->assertSame('+998 90 123 45 67', $institution->contact_phone);
            $this->assertSame('Updated address', $institution->address);
            $this->assertNull($institution->description);
            $this->assertProtectedInstitutionSnapshotUnchanged($protectedBefore, $institution);
            $this->assertSame($settingBefore, $this->settingSnapshot($setting));
            $this->assertSame($usersBefore, $this->usersSnapshot($institution));
            $this->assertSame($otherInstitutionBefore, $this->rawInstitutionSnapshot($otherInstitution));

            $detailResponse = $this->withToken($this->tokenFor($platformOwner))
                ->getJson($this->updateUri($institution));
            $detailResponse->assertOk();
            $detailResponse->assertJsonPath('data.name', 'Updated Name');
            $detailResponse->assertJsonPath('data.user_counts', ['total' => 2, 'active' => 1]);

            $content = $response->getContent();
            $this->assertStringNotContainsString('created_by_user_id', $content);
            $this->assertStringNotContainsString('deactivated_at', $content);
            $this->assertStringNotContainsString('settings', $content);
            $this->assertStringNotContainsString('acceptable_score_difference', $content);
            $this->assertStringNotContainsString('user_counts', $content);
            $this->assertStringNotContainsString('users', $content);
            $this->assertStringNotContainsString('tokens', $content);
            $this->assertStringNotContainsString('meta', $content);
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    public function test_platform_owner_can_update_inactive_target_without_reactivating_or_restoring_access(): void
    {
        $deactivatedAt = CarbonImmutable::parse('2026-08-08 10:15:00', 'UTC');
        $institution = Institution::factory()->inactive()->create([
            'name' => 'Inactive Target',
            'deactivated_at' => $deactivatedAt,
        ]);
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        $inactiveInstitutionTeacher = $this->createUserForRole(UserRole::Teacher, $institution, [
            'must_change_password' => false,
        ]);
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);

        $response = $this->authorizedPatch($platformOwner, $institution, [
            'name' => 'Inactive Target Updated',
            'contact_phone' => null,
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.name', 'Inactive Target Updated');
        $response->assertJsonPath('data.status', InstitutionStatus::Inactive->value);
        $response->assertJsonPath('data.contact_phone', null);
        $this->assertArrayNotHasKey('deactivated_at', $response->json('data'));

        $institution->refresh();
        $this->assertSame(InstitutionStatus::Inactive, $institution->status);
        $this->assertSame($deactivatedAt->toJSON(), $institution->deactivated_at?->toJSON());

        $this->forgetAuthenticationGuards();
        $this->assertErrorContract(
            $this->withToken($this->tokenFor($inactiveInstitutionTeacher))->patchJson($this->updateUri($institution), [
                'name' => 'Denied Restore Attempt',
            ]),
            403,
            'institution_inactive',
        );
        $this->assertSame('Inactive Target Updated', $institution->refresh()->name);
        $this->assertSame(InstitutionStatus::Inactive, $institution->status);
        $this->assertSame($deactivatedAt->toJSON(), $institution->deactivated_at?->toJSON());
    }

    public function test_authentication_account_password_role_and_inactive_institution_gates_write_nothing(): void
    {
        $target = Institution::factory()->create(['name' => 'Gate Protected Institution']);
        $before = $this->rawInstitutionSnapshot($target);

        $this->assertNoInstitutionChange(
            $target,
            $before,
            fn (): TestResponse => $this->patchJson($this->updateUri($target), ['name' => 'No Token']),
            401,
            'authentication_required',
        );

        $inactivePlatformOwner = $this->createUserForRole(UserRole::PlatformOwner, attributes: [
            'is_active' => false,
            'deactivated_at' => now(),
        ]);
        $this->assertNoInstitutionChange(
            $target,
            $before,
            fn (): TestResponse => $this->authorizedPatch($inactivePlatformOwner, $target, ['name' => 'Inactive Owner']),
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
            fn (): TestResponse => $this->authorizedPatch($passwordIncompletePlatformOwner, $target, ['name' => 'Password Gate']),
            403,
            'password_change_required',
        );
        $this->forgetAuthenticationGuards();

        foreach ([UserRole::InstitutionAdmin, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
            $wrongRoleUser = $this->createUserForRole($role);

            $this->assertNoInstitutionChange(
                $target,
                $before,
                fn (): TestResponse => $this->authorizedPatch($wrongRoleUser, $target, ['name' => 'Denied '.$role->value]),
                403,
                'forbidden',
                $role->value,
            );
            $this->forgetAuthenticationGuards();
        }

        $inactiveActorInstitution = Institution::factory()->inactive()->create();
        $wrongRoleUserFromInactiveInstitution = $this->createUserForRole(UserRole::Teacher, $inactiveActorInstitution, [
            'must_change_password' => false,
        ]);
        $this->assertNoInstitutionChange(
            $target,
            $before,
            fn (): TestResponse => $this->authorizedPatch($wrongRoleUserFromInactiveInstitution, $target, ['name' => 'Inactive Institution Actor']),
            403,
            'institution_inactive',
        );
    }

    public function test_unknown_and_malformed_uuid_return_not_found_only_after_earlier_denial_gates(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $wrongRoleUser = $this->createUserForRole(UserRole::Teacher);
        $unknownUuid = Str::uuid()->toString();
        $malformedUuid = 'not-a-uuid';

        foreach ([$unknownUuid, $malformedUuid] as $id) {
            $this->assertErrorContract(
                $this->patchJson($this->updateUriForId($id), ['name' => 'No Token']),
                401,
                'authentication_required',
                $id,
            );
        }

        $this->assertErrorContract(
            $this->withToken($this->tokenFor($platformOwner))->patchJson($this->updateUriForId($unknownUuid), ['name' => 'Unknown']),
            404,
            'resource_not_found',
        );
        $this->forgetAuthenticationGuards();

        $this->assertErrorContract(
            $this->withToken($this->tokenFor($platformOwner))->patchJson($this->updateUriForId($malformedUuid), ['name' => 'Malformed']),
            404,
            'resource_not_found',
        );
        $this->forgetAuthenticationGuards();

        foreach ([$unknownUuid, $malformedUuid] as $id) {
            $this->assertErrorContract(
                $this->withToken($this->tokenFor($wrongRoleUser))->patchJson($this->updateUriForId($id), ['name' => 'Wrong Role']),
                403,
                'forbidden',
                $id,
            );
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_empty_non_object_query_unknown_and_protected_payloads_are_rejected_without_writes(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create(['name' => 'Strict Payload School']);

        foreach ([
            'empty object' => fn (): TestResponse => $this->authorizedPatch($platformOwner, $institution, []),
            'array body' => fn (): TestResponse => $this->withToken($this->tokenFor($platformOwner))
                ->json('PATCH', $this->updateUri($institution), [['name' => 'Array Root']]),
            'scalar body' => fn (): TestResponse => $this->authorizedRawJsonPatch($platformOwner, $institution, '"scalar"'),
        ] as $case => $request) {
            $before = $this->rawInstitutionSnapshot($institution);
            $decoded = $this->assertErrorContract($request(), 422, 'validation_failed', $case);
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($before, $this->rawInstitutionSnapshot($institution), $case);
            $this->forgetAuthenticationGuards();
        }

        $decodedQuery = $this->assertErrorContract(
            $this->authorizedPatch(
                $platformOwner,
                $institution,
                ['name' => 'Query Rejected'],
                $this->updateUri($institution).'?status='.InstitutionStatus::Inactive->value,
            ),
            422,
            'validation_failed',
            'query status',
        );
        $this->assertObjectHasProperty('status', $decodedQuery->errors);
        $this->assertSame('Strict Payload School', $institution->refresh()->name);

        $protectedFields = [
            'id' => Str::uuid()->toString(),
            'institution_id' => Str::uuid()->toString(),
            'status' => InstitutionStatus::Inactive->value,
            'created_by_user_id' => Str::uuid()->toString(),
            'deactivated_at' => '2026-08-10T12:00:00Z',
            'created_at' => '2026-08-10T12:00:00Z',
            'updated_at' => '2026-08-10T12:00:00Z',
            'settings' => ['timezone' => CreatePlatformInstitution::DEFAULT_TIMEZONE],
            'timezone' => CreatePlatformInstitution::DEFAULT_TIMEZONE,
            'learning_material_max_mb' => CreatePlatformInstitution::DEFAULT_LEARNING_MATERIAL_MAX_MB,
            'student_submission_max_mb' => CreatePlatformInstitution::DEFAULT_STUDENT_SUBMISSION_MAX_MB,
            'acceptable_score_difference' => 10,
            'blitz_timer_start_mode' => BlitzTimerStartMode::Synchronized->value,
            'student_result_release_mode' => StudentResultReleaseMode::Automatic->value,
            'parent_result_release_mode' => ParentResultReleaseMode::WithStudent->value,
            'role' => UserRole::PlatformOwner->value,
            'users' => [],
            'user_counts' => ['total' => 0, 'active' => 0],
            'unknown_future_field' => 'not allowed',
        ];

        foreach ($protectedFields as $field => $value) {
            $before = $this->rawInstitutionSnapshot($institution);
            $decoded = $this->assertErrorContract(
                $this->authorizedPatch($platformOwner, $institution, [
                    'name' => 'Protected '.$field,
                    $field => $value,
                ]),
                422,
                'validation_failed',
                $field,
            );
            $this->assertObjectHasProperty($field, $decoded->errors, $field);
            $this->assertSame($before, $this->rawInstitutionSnapshot($institution), $field);
        }
    }

    public function test_field_validation_current_enums_and_no_invented_uniqueness(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create([
            'name' => 'Validation Target',
            'type' => InstitutionType::School,
            'contact_email' => 'same@example.uz',
            'contact_phone' => 'local phone ext 1',
        ]);

        $this->authorizedPatch($platformOwner, $institution, ['name' => str_repeat('A', 200)])
            ->assertOk()
            ->assertJsonPath('data.name', str_repeat('A', 200));

        foreach (InstitutionType::cases() as $type) {
            $this->authorizedPatch($platformOwner, $institution, ['type' => $type->value])
                ->assertOk()
                ->assertJsonPath('data.type', $type->value);
        }

        $this->authorizedPatch($platformOwner, $institution, ['contact_email' => 'valid@example.uz'])
            ->assertOk()
            ->assertJsonPath('data.contact_email', 'valid@example.uz');
        $this->authorizedPatch($platformOwner, $institution, ['contact_phone' => str_repeat('9', 50)])
            ->assertOk()
            ->assertJsonPath('data.contact_phone', str_repeat('9', 50));
        $this->authorizedPatch($platformOwner, $institution, ['contact_phone' => 'local phone ext 123'])
            ->assertOk()
            ->assertJsonPath('data.contact_phone', 'local phone ext 123');
        $this->authorizedPatch($platformOwner, $institution, ['address' => str_repeat('A', 1200)])
            ->assertOk()
            ->assertJsonPath('data.address', str_repeat('A', 1200));
        $this->authorizedPatch($platformOwner, $institution, ['description' => str_repeat('D', 1300)])
            ->assertOk()
            ->assertJsonPath('data.description', str_repeat('D', 1300));

        foreach ([
            'whitespace name' => ['payload' => ['name' => '   '], 'field' => 'name'],
            'null name' => ['payload' => ['name' => null], 'field' => 'name'],
            'array name' => ['payload' => ['name' => ['Updated']], 'field' => 'name'],
            'boolean name' => ['payload' => ['name' => true], 'field' => 'name'],
            'too long name' => ['payload' => ['name' => str_repeat('B', 201)], 'field' => 'name'],
            'unknown type' => ['payload' => ['type' => 'academy'], 'field' => 'type'],
            'null type' => ['payload' => ['type' => null], 'field' => 'type'],
            'array type' => ['payload' => ['type' => ['school']], 'field' => 'type'],
            'invalid email' => ['payload' => ['contact_email' => 'not an email'], 'field' => 'contact_email'],
            'too long email' => ['payload' => ['contact_email' => str_repeat('a', 245).'@example.uz'], 'field' => 'contact_email'],
            'too long phone' => ['payload' => ['contact_phone' => str_repeat('9', 51)], 'field' => 'contact_phone'],
            'array phone' => ['payload' => ['contact_phone' => ['phone']], 'field' => 'contact_phone'],
            'boolean phone' => ['payload' => ['contact_phone' => false], 'field' => 'contact_phone'],
            'array address' => ['payload' => ['address' => ['Samarkand']], 'field' => 'address'],
            'object address' => ['payload' => ['address' => ['city' => 'Samarkand']], 'field' => 'address'],
            'boolean address' => ['payload' => ['address' => true], 'field' => 'address'],
            'array description' => ['payload' => ['description' => ['notes']], 'field' => 'description'],
            'boolean description' => ['payload' => ['description' => false], 'field' => 'description'],
        ] as $case => $input) {
            $before = $this->rawInstitutionSnapshot($institution);
            $decoded = $this->assertErrorContract(
                $this->authorizedPatch($platformOwner, $institution, $input['payload']),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($input['field'], $decoded->errors, $case);
            $this->assertSame($before, $this->rawInstitutionSnapshot($institution), $case);
        }

        Institution::factory()->create([
            'name' => 'Duplicate Allowed',
            'contact_email' => 'duplicate@example.uz',
            'contact_phone' => 'duplicate-phone',
        ]);

        $this->authorizedPatch($platformOwner, $institution, [
            'name' => 'Duplicate Allowed',
            'contact_email' => 'duplicate@example.uz',
            'contact_phone' => 'duplicate-phone',
        ])
            ->assertOk()
            ->assertJsonPath('data.name', 'Duplicate Allowed')
            ->assertJsonPath('data.contact_email', 'duplicate@example.uz')
            ->assertJsonPath('data.contact_phone', 'duplicate-phone');
    }

    public function test_omitted_fields_are_preserved_explicit_null_clears_nullable_fields_and_same_value_succeeds(): void
    {
        $platformOwner = $this->createUserForRole(UserRole::PlatformOwner);
        $institution = Institution::factory()->create([
            'name' => 'Patch Semantics School',
            'type' => InstitutionType::School,
            'status' => InstitutionStatus::Active,
            'contact_email' => 'preserved@example.uz',
            'contact_phone' => 'preserved phone',
            'address' => 'Preserved address',
            'description' => 'Preserved description',
            'created_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
        ]);
        $originalProtected = $this->protectedInstitutionSnapshot($institution);

        $response = $this->authorizedPatch($platformOwner, $institution, ['name' => 'Only Name Changed']);
        $response->assertOk();
        $response->assertJsonPath('data.name', 'Only Name Changed');
        $response->assertJsonPath('data.type', InstitutionType::School->value);
        $response->assertJsonPath('data.contact_email', 'preserved@example.uz');
        $response->assertJsonPath('data.contact_phone', 'preserved phone');
        $response->assertJsonPath('data.address', 'Preserved address');
        $response->assertJsonPath('data.description', 'Preserved description');
        $this->assertProtectedInstitutionSnapshotUnchanged($originalProtected, $institution);

        $clearResponse = $this->authorizedPatch($platformOwner, $institution, [
            'contact_email' => null,
            'contact_phone' => null,
            'address' => null,
            'description' => null,
        ]);
        $clearResponse->assertOk();
        $clearResponse->assertJsonPath('data.contact_email', null);
        $clearResponse->assertJsonPath('data.contact_phone', null);
        $clearResponse->assertJsonPath('data.address', null);
        $clearResponse->assertJsonPath('data.description', null);
        $this->assertNull($institution->refresh()->contact_email);
        $this->assertNull($institution->contact_phone);
        $this->assertNull($institution->address);
        $this->assertNull($institution->description);

        $sameValueInstitution = Institution::factory()->create([
            'name' => 'Same Value School',
            'updated_at' => CarbonImmutable::parse('2026-08-07 15:00:00', 'UTC'),
        ]);
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-10 12:00:00', 'UTC'));

        try {
            $sameValueResponse = $this->authorizedPatch($platformOwner, $sameValueInstitution, [
                'name' => 'Same Value School',
            ]);

            $sameValueResponse->assertOk();
            $sameValueInstitution->refresh();
            $this->assertSame('Same Value School', $sameValueInstitution->name);
            $this->assertSame('2026-08-07T15:00:00.000000Z', $sameValueInstitution->updated_at?->toJSON());
        } finally {
            CarbonImmutable::setTestNow();
        }
    }

    private function createConfiguredSetting(Institution $institution, User $updater): InstitutionSetting
    {
        return InstitutionSetting::factory()
            ->configuredEducationalPolicy()
            ->uploadLimits(20, 10)
            ->create([
                'institution_id' => $institution->id,
                'timezone' => 'Asia/Samarkand',
                'updated_by_user_id' => $updater->id,
            ]);
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

    private function authorizedPatch(
        User $user,
        Institution $institution,
        array $payload,
        ?string $uri = null,
    ): TestResponse {
        return $this->withToken($this->tokenFor($user))->patchJson($uri ?? $this->updateUri($institution), $payload);
    }

    private function authorizedRawJsonPatch(User $user, Institution $institution, string $content): TestResponse
    {
        return $this->call(
            'PATCH',
            $this->updateUri($institution),
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
        return $user->createToken('platform-institution-update-api-test', $abilities)->plainTextToken;
    }

    private function updateUri(Institution $institution): string
    {
        return $this->updateUriForId($institution->id);
    }

    private function updateUriForId(string $institutionId): string
    {
        return self::BASE_URI.'/'.$institutionId;
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
            'status' => $institution->status->value,
            'created_by_user_id' => $institution->created_by_user_id,
            'deactivated_at' => $institution->deactivated_at?->toJSON(),
            'created_at' => $institution->created_at?->toJSON(),
        ];
    }

    /**
     * @param  array<string, mixed>  $expected
     */
    private function assertProtectedInstitutionSnapshotUnchanged(array $expected, Institution $institution): void
    {
        $this->assertSame($expected, $this->protectedInstitutionSnapshot($institution));
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
