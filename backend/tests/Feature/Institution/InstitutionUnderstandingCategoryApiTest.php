<?php

namespace Tests\Feature\Institution;

use App\Enums\InstitutionStatus;
use App\Enums\UnderstandingCategoryCode;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use RuntimeException;
use Tests\TestCase;

class InstitutionUnderstandingCategoryApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/institution/understanding-categories';

    /** @var array<string, string> */
    private array $actorTokens = [];

    public function test_routes_are_registered_once_with_exact_methods_and_middleware_order(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/institution/understanding-categories')
            ->values()
            ->all();
        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/institution/understanding-categories', 'middleware' => $middleware],
            ['methods' => ['PUT'], 'uri' => 'api/v1/institution/understanding-categories', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_get_returns_exact_unconfigured_or_configured_actor_scoped_state_without_writes(): void
    {
        $institution = $this->institutionWithSettings();
        $foreignInstitution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $foreignUpdater = $this->institutionAdmin($foreignInstitution);
        $this->persistSet($foreignInstitution, $foreignUpdater, $this->validSet([[91, 100], [81, 90], [41, 80], [0, 40]]));
        $this->tokenFor($actor);
        $settingsBefore = InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal();

        [$unconfigured, $queries] = $this->captureQueries(fn (): TestResponse => $this->authorizedGet($actor));

        $unconfigured->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($unconfigured->json()));
        $this->assertSame([], $unconfigured->json('data'));
        $this->assertSame(['configured' => false], $unconfigured->json('meta'));
        $this->assertIsBool($unconfigured->json('meta.configured'));
        $this->assertSame($settingsBefore, InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal());
        $this->assertCount(2, collect($queries)->filter(fn (array $query): bool => str_starts_with(
            strtolower((string) $query['query']),
            'select',
        ))->filter(fn (array $query): bool => str_contains(
            strtolower((string) $query['query']),
            'institution_',
        )));

        $this->persistSet($institution, $actor);
        $rowsBefore = $this->categoryRows($institution->id);
        $this->forgetAuthenticationGuards();
        $configured = $this->authorizedGet($actor);

        $configured->assertOk();
        $this->assertExactConfiguredResponse($configured, $this->validSet());
        $this->assertSame($rowsBefore, $this->categoryRows($institution->id));
        $this->assertSame(5, InstitutionUnderstandingCategory::query()
            ->where('institution_id', $foreignInstitution->id)
            ->count());
    }

    public function test_get_rejects_every_raw_body_and_query_input_with_zero_mutation(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $this->persistSet($institution, $actor);
        $this->tokenFor($actor);
        $categoriesBefore = $this->categoryRows($institution->id);
        $settingsBefore = InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal();
        $bodyCases = [
            'whitespace' => [" \t\r\n", 'application/json'],
            'object' => ['{}', 'application/json'],
            'keyed object' => ['{"categories":[]}', 'application/json'],
            'array' => ['[]', 'application/json'],
            'scalar' => ['1', 'application/json'],
            'null' => ['null', 'application/json'],
            'malformed' => ['{"categories":', 'application/json'],
            'text' => ['text', 'text/plain'],
            'form' => ['categories=value', 'application/x-www-form-urlencoded'],
            'multipart' => ['--boundary--', 'multipart/form-data; boundary=boundary'],
        ];

        foreach ($bodyCases as $case => [$content, $contentType]) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('GET', $actor, $content, contentType: $contentType),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($categoriesBefore, $this->categoryRows($institution->id), $case);
            $this->assertSame($settingsBefore, InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal(), $case);
            $this->forgetAuthenticationGuards();
        }

        foreach (['categories', 'institution_id', 'updated_by_user_id', 'unknown'] as $queryKey) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('GET', $actor, '', [$queryKey => 'value']),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($categoriesBefore, $this->categoryRows($institution->id), $queryKey);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_first_put_creates_exact_server_owned_canonical_set_for_actor_tenant_only(): void
    {
        $institution = $this->institutionWithSettings();
        $foreignInstitution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $actor->createToken('preserved-own-token');
        $foreignActor->createToken('preserved-foreign-token');
        $this->tokenFor($actor);
        $settingsBefore = $this->tableRowsSnapshot('institution_settings', 'institution_id');
        $institutionsBefore = $this->tableRowsSnapshot('institutions');
        $usersBefore = $this->tableRowsSnapshot('users');
        $tokensBefore = $this->tableRowsSnapshot('personal_access_tokens');
        $input = array_reverse($this->validSet());
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 10:15:30.123456', 'UTC'));

        try {
            $response = $this->authorizedRaw(
                'PUT',
                $actor,
                json_encode(['categories' => $input], JSON_THROW_ON_ERROR),
                serverOverrides: ['HTTP_X_INSTITUTION_ID' => $foreignInstitution->id],
            );
        } finally {
            CarbonImmutable::setTestNow();
        }

        $response->assertOk();
        $this->assertExactConfiguredResponse($response, $this->validSet());
        $rows = InstitutionUnderstandingCategory::query()
            ->where('institution_id', $institution->id)
            ->orderBy('sort_order')
            ->get();
        $this->assertCount(5, $rows);
        $this->assertSame([1, 2, 3, 4, 5], $rows->pluck('sort_order')->all());
        $this->assertCount(5, array_unique($rows->pluck('id')->all()));
        $this->assertTrue($rows->every(fn (InstitutionUnderstandingCategory $row): bool => Str::isUuid($row->id)));
        $this->assertSame([$actor->id], $rows->pluck('updated_by_user_id')->unique()->values()->all());
        $this->assertSame(1, $rows->pluck('created_at')->map->format('Y-m-d H:i:s.uP')->unique()->count());
        $this->assertSame(1, $rows->pluck('updated_at')->map->format('Y-m-d H:i:s.uP')->unique()->count());
        $this->assertSame(
            $rows->first()->created_at?->format('Y-m-d H:i:s.uP'),
            $rows->first()->updated_at?->format('Y-m-d H:i:s.uP'),
        );
        $this->assertSame(0, InstitutionUnderstandingCategory::query()
            ->where('institution_id', $foreignInstitution->id)
            ->count());
        $this->assertSame($settingsBefore, $this->tableRowsSnapshot('institution_settings', 'institution_id'));
        $this->assertSame($institutionsBefore, $this->tableRowsSnapshot('institutions'));
        $this->assertSame($usersBefore, $this->tableRowsSnapshot('users'));
        $this->assertSame($tokensBefore, $this->tableRowsSnapshot('personal_access_tokens'));
    }

    public function test_replacement_preserves_identity_noop_writes_nothing_and_updater_change_replaces_all_five(): void
    {
        $institution = $this->institutionWithSettings();
        $firstActor = $this->institutionAdmin($institution);
        $secondActor = $this->institutionAdmin($institution);
        $this->tokenFor($firstActor);
        $this->authorizedPut($firstActor, $this->validSet())->assertOk();
        $before = $this->categoryRows($institution->id);
        $replacement = $this->validSet([[91, 100], [81, 90], [41, 80], [0, 40]]);
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 11:00:00', 'UTC'));

        try {
            [$response, $queries] = $this->captureQueries(
                fn (): TestResponse => $this->authorizedPut($firstActor, $replacement),
            );
        } finally {
            CarbonImmutable::setTestNow();
        }

        $response->assertOk();
        $this->assertExactConfiguredResponse($response, $replacement);
        $afterReplacement = $this->categoryRows($institution->id);
        $this->assertSame(array_column($before, 'id'), array_column($afterReplacement, 'id'));
        $this->assertSame(array_column($before, 'created_at'), array_column($afterReplacement, 'created_at'));
        $this->assertNotSame(array_column($before, 'updated_at'), array_column($afterReplacement, 'updated_at'));
        $this->assertSame(1, count(array_unique(array_column($afterReplacement, 'updated_at'))));
        $this->assertSame([$firstActor->id], array_values(array_unique(array_column($afterReplacement, 'updated_by_user_id'))));
        $this->assertSame(1, $this->countCategoryDml($queries));

        $this->forgetAuthenticationGuards();
        [$noOp, $noOpQueries] = $this->captureQueries(
            fn (): TestResponse => $this->authorizedPut($firstActor, array_reverse($replacement)),
        );
        $noOp->assertOk();
        $this->assertSame(0, $this->countCategoryDml($noOpQueries));
        $this->assertSame($afterReplacement, $this->categoryRows($institution->id));

        $this->tokenFor($secondActor);
        $this->forgetAuthenticationGuards();
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 12:00:00', 'UTC'));

        try {
            [$updaterChange, $updaterQueries] = $this->captureQueries(
                fn (): TestResponse => $this->authorizedPut($secondActor, $replacement),
            );
        } finally {
            CarbonImmutable::setTestNow();
        }

        $updaterChange->assertOk();
        $afterUpdaterChange = $this->categoryRows($institution->id);
        $this->assertSame(array_column($afterReplacement, 'id'), array_column($afterUpdaterChange, 'id'));
        $this->assertSame(array_column($afterReplacement, 'created_at'), array_column($afterUpdaterChange, 'created_at'));
        $this->assertSame([$secondActor->id], array_values(array_unique(array_column($afterUpdaterChange, 'updated_by_user_id'))));
        $this->assertSame(1, count(array_unique(array_column($afterUpdaterChange, 'updated_at'))));
        $this->assertSame(1, $this->countCategoryDml($updaterQueries));
    }

    public function test_put_transport_shape_allowlist_types_and_complete_set_validation_are_atomic(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $this->persistSet($institution, $actor);
        $this->tokenFor($actor);
        $before = $this->categoryRows($institution->id);
        $settingsBefore = InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal();
        $bodyCases = [
            'absent' => ['', 'application/json'],
            'whitespace' => [" \t\n", 'application/json'],
            'malformed' => ['{"categories":', 'application/json'],
            'scalar' => ['1', 'application/json'],
            'array root' => ['[]', 'application/json'],
            'null' => ['null', 'application/json'],
            'form' => ['categories=value', 'application/x-www-form-urlencoded'],
            'multipart' => ['--boundary--', 'multipart/form-data; boundary=boundary'],
            'text' => ['text', 'text/plain'],
        ];

        foreach ($bodyCases as $case => [$content, $contentType]) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('PUT', $actor, $content, contentType: $contentType),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertUnchanged($institution, $before, $settingsBefore, $case);
            $this->forgetAuthenticationGuards();
        }

        $payloadCases = [
            'empty object' => [[], 'categories'],
            'categories scalar' => [['categories' => 'invalid'], 'categories'],
            'wrong count' => [['categories' => array_slice($this->validSet(), 0, 4)], 'categories'],
            'non-object entry' => [['categories' => array_replace($this->validSet(), [0 => 'invalid'])], 'categories.0'],
            'missing code' => [['categories' => $this->withoutItemKey($this->validSet(), 0, 'code')], 'categories.0.code'],
            'missing min' => [['categories' => $this->withoutItemKey($this->validSet(), 0, 'min_score')], 'categories.0.min_score'],
            'missing max' => [['categories' => $this->withoutItemKey($this->validSet(), 0, 'max_score')], 'categories.0.max_score'],
            'missing sort' => [['categories' => $this->withoutItemKey($this->validSet(), 0, 'sort_order')], 'categories.0.sort_order'],
            'unknown code' => [['categories' => $this->replaceItem($this->validSet(), 0, ['code' => 'excellent'])], 'categories.0.code'],
            'code case' => [['categories' => $this->replaceItem($this->validSet(), 0, ['code' => 'UNDERSTOOD_WELL'])], 'categories.0.code'],
            'code spacing' => [['categories' => $this->replaceItem($this->validSet(), 0, ['code' => ' understood_well'])], 'categories.0.code'],
            'code boolean' => [['categories' => $this->replaceItem($this->validSet(), 0, ['code' => true])], 'categories.0.code'],
            'numeric string' => [['categories' => $this->replaceItem($this->validSet(), 0, ['min_score' => '86'])], 'categories.0.min_score'],
            'float' => [['categories' => $this->replaceItem($this->validSet(), 0, ['min_score' => 86.0])], 'categories.0.min_score'],
            'boolean' => [['categories' => $this->replaceItem($this->validSet(), 0, ['max_score' => true])], 'categories.0.max_score'],
            'numeric null' => [['categories' => $this->replaceItem($this->validSet(), 0, ['min_score' => null])], 'categories.0.min_score'],
            'negative bound' => [['categories' => $this->replaceItem($this->validSet(), 3, ['min_score' => -1])], 'categories.3.min_score'],
            'above bound' => [['categories' => $this->replaceItem($this->validSet(), 0, ['max_score' => 101])], 'categories.0.max_score'],
            'not completed integer' => [['categories' => $this->replaceItem($this->validSet(), 4, ['max_score' => 0])], 'categories.4.max_score'],
            'not completed string' => [['categories' => $this->replaceItem($this->validSet(), 4, ['min_score' => '0'])], 'categories.4.min_score'],
            'sort string' => [['categories' => $this->replaceItem($this->validSet(), 0, ['sort_order' => '1'])], 'categories.0.sort_order'],
            'wrong sort' => [['categories' => $this->replaceItem($this->validSet(), 0, ['sort_order' => 2])], 'categories.0.sort_order'],
            'top uncovered' => [['categories' => $this->replaceItem($this->validSet(), 0, ['max_score' => 99])], 'categories'],
            'bottom uncovered' => [['categories' => $this->replaceItem($this->validSet(), 3, ['min_score' => 1])], 'categories'],
            'gap' => [['categories' => $this->replaceItem($this->validSet(), 1, ['max_score' => 84])], 'categories'],
            'overlap' => [['categories' => $this->replaceItem($this->validSet(), 1, ['max_score' => 86])], 'categories'],
            'reversed' => [['categories' => $this->replaceItem($this->validSet(), 1, ['min_score' => 90])], 'categories'],
            'duplicate code' => [['categories' => array_replace($this->validSet(), [1 => $this->validSet()[0]])], 'categories'],
            'unknown root' => [['categories' => $this->validSet(), 'institution_id' => $institution->id], 'institution_id'],
        ];

        foreach ($payloadCases as $case => [$payload, $errorKey]) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw(
                    'PUT',
                    $actor,
                    json_encode($payload, JSON_THROW_ON_ERROR | JSON_PRESERVE_ZERO_FRACTION),
                ),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty($errorKey, $decoded->errors, $case);
            $this->assertUnchanged($institution, $before, $settingsBefore, $case);
            $this->forgetAuthenticationGuards();
        }

        foreach ($this->protectedItemKeys() as $protectedKey) {
            $categories = $this->validSet();
            $categories[0][$protectedKey] = 'forged';
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('PUT', $actor, json_encode(['categories' => $categories], JSON_THROW_ON_ERROR)),
                422,
                'validation_failed',
                $protectedKey,
            );
            $this->assertObjectHasProperty("categories.0.{$protectedKey}", $decoded->errors, $protectedKey);
            $this->assertUnchanged($institution, $before, $settingsBefore, $protectedKey);
            $this->forgetAuthenticationGuards();
        }

        foreach (['institution_id', 'categories', 'unknown'] as $queryKey) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw(
                    'PUT',
                    $actor,
                    json_encode(['categories' => $this->validSet()], JSON_THROW_ON_ERROR),
                    [$queryKey => 'value'],
                ),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertUnchanged($institution, $before, $settingsBefore, $queryKey);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_partial_corrupt_and_missing_lock_states_return_safe_500_without_repair_or_disclosure(): void
    {
        $partialInstitution = $this->institutionWithSettings();
        $partialActor = $this->institutionAdmin($partialInstitution);
        $this->persistSet($partialInstitution, $partialActor, array_slice($this->validSet(), 0, 1));
        $this->tokenFor($partialActor);
        $partialBefore = $this->categoryRows($partialInstitution->id);

        foreach (['GET', 'PUT'] as $method) {
            $response = $method === 'GET'
                ? $this->authorizedGet($partialActor)
                : $this->authorizedPut($partialActor, $this->validSet());
            $decoded = $this->assertErrorContract($response, 500, 'server_error', $method.' partial');
            $this->assertSafeServerError($decoded, $response, $partialInstitution->id);
            $this->assertSame($partialBefore, $this->categoryRows($partialInstitution->id));
            $this->forgetAuthenticationGuards();
        }

        $invalidInstitution = $this->institutionWithSettings();
        $invalidActor = $this->institutionAdmin($invalidInstitution);
        $invalidSet = $this->replaceItem($this->validSet(), 1, ['min_score' => 72]);
        $this->persistSet($invalidInstitution, $invalidActor, $invalidSet);
        $this->tokenFor($invalidActor);
        $invalidBefore = $this->categoryRows($invalidInstitution->id);

        foreach (['GET', 'PUT'] as $method) {
            $response = $method === 'GET'
                ? $this->authorizedGet($invalidActor)
                : $this->authorizedPut($invalidActor, $this->validSet());
            $decoded = $this->assertErrorContract($response, 500, 'server_error', $method.' invalid');
            $this->assertSafeServerError($decoded, $response, $invalidInstitution->id);
            $this->assertSame($invalidBefore, $this->categoryRows($invalidInstitution->id));
            $this->forgetAuthenticationGuards();
        }

        $missingSettingsInstitution = Institution::factory()->create();
        $missingSettingsActor = $this->institutionAdmin($missingSettingsInstitution);
        $this->tokenFor($missingSettingsActor);

        foreach (['GET', 'PUT'] as $method) {
            $response = $method === 'GET'
                ? $this->authorizedGet($missingSettingsActor)
                : $this->authorizedPut($missingSettingsActor, $this->validSet());
            $decoded = $this->assertErrorContract($response, 500, 'server_error', $method.' missing settings');
            $this->assertSafeServerError($decoded, $response, $missingSettingsInstitution->id);
            $this->assertDatabaseMissing('institution_settings', ['institution_id' => $missingSettingsInstitution->id]);
            $this->assertDatabaseMissing('institution_understanding_categories', [
                'institution_id' => $missingSettingsInstitution->id,
            ]);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_controlled_first_and_replacement_failures_roll_back_complete_set_and_return_safe_500(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $this->tokenFor($actor);
        $settingsBefore = InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal();
        $failFirstWrite = true;
        DB::listen(function (object $query) use (&$failFirstWrite): void {
            if ($failFirstWrite && str_starts_with(
                strtolower((string) $query->sql),
                'insert into "institution_understanding_categories"',
            )) {
                $failFirstWrite = false;

                throw new RuntimeException('controlled category insert failure');
            }
        });

        $firstFailure = $this->authorizedPut($actor, $this->validSet());
        $decoded = $this->assertErrorContract($firstFailure, 500, 'server_error', 'first configuration rollback');
        $this->assertSafeServerError($decoded, $firstFailure, $institution->id);
        $this->assertDatabaseMissing('institution_understanding_categories', ['institution_id' => $institution->id]);
        $this->assertSame($settingsBefore, InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal());

        $this->forgetAuthenticationGuards();
        $this->authorizedPut($actor, $this->validSet())->assertOk();
        $prior = $this->categoryRows($institution->id);
        $failReplacement = true;
        DB::listen(function (object $query) use (&$failReplacement): void {
            if ($failReplacement && str_starts_with(
                strtolower((string) $query->sql),
                'insert into "institution_understanding_categories"',
            )) {
                $failReplacement = false;

                throw new RuntimeException('controlled category replacement failure');
            }
        });
        $this->forgetAuthenticationGuards();
        $replacementFailure = $this->authorizedPut(
            $actor,
            $this->validSet([[91, 100], [81, 90], [41, 80], [0, 40]]),
        );
        $replacementDecoded = $this->assertErrorContract(
            $replacementFailure,
            500,
            'server_error',
            'replacement rollback',
        );
        $this->assertSafeServerError($replacementDecoded, $replacementFailure, $institution->id);
        $this->assertSame($prior, $this->categoryRows($institution->id));
        $this->assertSame($settingsBefore, InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal());
    }

    public function test_middleware_precedence_wrong_roles_and_tenant_authority_are_enforced(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $invalidPayload = '{"categories":';

        $this->raw('GET', '')->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $this->raw('PUT', $invalidPayload)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');

        $inactiveActor = $this->institutionAdmin($institution, ['is_active' => false]);
        $this->authorizedRaw('PUT', $inactiveActor, $invalidPayload)
            ->assertForbidden()->assertJsonPath('code', 'user_inactive');
        $this->forgetAuthenticationGuards();

        $inactiveInstitution = $this->institutionWithSettings(['status' => InstitutionStatus::Inactive]);
        $inactiveInstitutionActor = $this->institutionAdmin($inactiveInstitution);
        $this->authorizedRaw('PUT', $inactiveInstitutionActor, $invalidPayload)
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');
        $this->forgetAuthenticationGuards();

        $firstLoginActor = $this->institutionAdmin($institution, ['must_change_password' => true]);
        $this->authorizedRaw('PUT', $firstLoginActor, $invalidPayload)
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');
        $this->forgetAuthenticationGuards();

        foreach ([
            User::factory()->platformOwner()->create(),
            User::factory()->teacher($institution)->create(['must_change_password' => false]),
            User::factory()->student($institution)->create(['must_change_password' => false]),
            User::factory()->parent($institution)->create(['must_change_password' => false]),
        ] as $wrongRole) {
            $this->authorizedRaw('PUT', $wrongRole, $invalidPayload)
                ->assertForbidden()->assertJsonPath('code', 'forbidden');
            $this->forgetAuthenticationGuards();
        }

        $foreignInstitution = $this->institutionWithSettings();
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $this->persistSet($foreignInstitution, $foreignActor);
        $foreignBefore = $this->categoryRows($foreignInstitution->id);
        $this->tokenFor($actor);
        $this->forgetAuthenticationGuards();
        $this->authorizedRaw(
            'PUT',
            $actor,
            json_encode(['categories' => $this->validSet()], JSON_THROW_ON_ERROR),
            serverOverrides: ['HTTP_X_INSTITUTION_ID' => $foreignInstitution->id],
        )->assertOk();
        $this->assertSame($foreignBefore, $this->categoryRows($foreignInstitution->id));
        $this->assertSame(5, InstitutionUnderstandingCategory::query()
            ->where('institution_id', $institution->id)
            ->count());
    }

    public function test_real_postgresql_races_serialize_same_tenant_and_keep_different_tenants_independent(): void
    {
        $workerPath = tempnam(sys_get_temp_dir(), 's03_be_007_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $single = json_decode($this->runWorker([$workerPath, base_path(), 'setup-single']), true, flags: JSON_THROW_ON_ERROR);
        $two = null;

        try {
            $sameFirst = $this->runRace(
                $workerPath,
                $single['actors']['first'],
                $single['actors']['first'],
                'first',
                'first',
            );
            $this->assertGreaterThan(0.5, $sameFirst['second']['action_elapsed_seconds']);
            $this->assertSame(1, $sameFirst['first']['dml']);
            $this->assertSame(0, $sameFirst['second']['dml']);
            $this->assertSame($sameFirst['first']['state'], $sameFirst['second']['state']);
            $this->runWorker([$workerPath, base_path(), 'reset', $single['institutions'][0]]);

            $differentFirst = $this->runRace(
                $workerPath,
                $single['actors']['first'],
                $single['actors']['second'],
                'first',
                'second',
            );
            $this->assertGreaterThan(0.5, $differentFirst['second']['action_elapsed_seconds']);
            $this->assertSame('first', $differentFirst['first']['payload']);
            $this->assertSame('second', $differentFirst['second']['payload']);
            $this->assertSame(5, $differentFirst['first']['count']);
            $this->assertSame(5, $differentFirst['second']['count']);
            $this->assertSame(1, $differentFirst['first']['dml']);
            $this->assertSame(1, $differentFirst['second']['dml']);

            $samePayload = $this->runRace(
                $workerPath,
                $single['actors']['first'],
                $single['actors']['first'],
                'same',
                'same',
            );
            $this->assertSame(1, $samePayload['first']['dml']);
            $this->assertSame(0, $samePayload['second']['dml']);
            $this->assertSame($samePayload['first']['state'], $samePayload['second']['state']);

            $differentPayload = $this->runRace(
                $workerPath,
                $single['actors']['first'],
                $single['actors']['second'],
                'first',
                'second',
            );
            $this->assertSame(1, $differentPayload['first']['dml']);
            $this->assertSame(1, $differentPayload['second']['dml']);
            $this->assertSame('second', $differentPayload['second']['payload']);

            $differentUpdater = $this->runRace(
                $workerPath,
                $single['actors']['first'],
                $single['actors']['second'],
                'second',
                'second',
            );
            $this->assertSame(1, $differentUpdater['first']['dml']);
            $this->assertSame(1, $differentUpdater['second']['dml']);
            $this->assertSame([$single['actors']['second']], array_values(array_unique(
                array_column($differentUpdater['second']['state'], 'updated_by_user_id'),
            )));

            $two = json_decode($this->runWorker([$workerPath, base_path(), 'setup-two']), true, flags: JSON_THROW_ON_ERROR);
            $independent = $this->runIndependentRace(
                $workerPath,
                $two['first_actor'],
                $two['second_actor'],
            );
            $this->assertLessThan(0.5, $independent['second']['action_elapsed_seconds']);
            $this->assertSame(5, $independent['first']['count']);
            $this->assertSame(5, $independent['second']['count']);
            $this->assertNotSame($independent['first']['institution_id'], $independent['second']['institution_id']);
        } finally {
            $this->runWorker([$workerPath, base_path(), 'cleanup', $single['institutions'][0]]);

            if (is_array($two)) {
                foreach ($two['institutions'] as $institutionId) {
                    $this->runWorker([$workerPath, base_path(), 'cleanup', $institutionId]);
                }
            }

            unlink($workerPath);
        }
    }

    public function test_controlled_http_smoke_covers_unconfigured_create_noop_replace_invalid_and_tenant_isolation(): void
    {
        $institution = $this->institutionWithSettings();
        $foreignInstitution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $this->tokenFor($actor);
        $this->authorizedGet($actor)->assertOk()->assertJsonPath('meta.configured', false);
        $this->forgetAuthenticationGuards();
        $this->authorizedPut($actor, $this->validSet())->assertOk();
        $created = $this->categoryRows($institution->id);
        $this->forgetAuthenticationGuards();
        $this->authorizedPut($actor, $this->validSet())->assertOk();
        $this->assertSame($created, $this->categoryRows($institution->id));
        $this->forgetAuthenticationGuards();
        $this->authorizedPut($actor, $this->validSet([[91, 100], [81, 90], [41, 80], [0, 40]]))->assertOk();
        $replaced = $this->categoryRows($institution->id);
        $this->forgetAuthenticationGuards();
        $this->authorizedPut($actor, $this->replaceItem($this->validSet(), 1, ['max_score' => 84]))
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($replaced, $this->categoryRows($institution->id));
        $this->assertSame(0, InstitutionUnderstandingCategory::query()
            ->where('institution_id', $foreignInstitution->id)->count());
        $this->tokenFor($foreignActor);
        $this->forgetAuthenticationGuards();
        $this->authorizedGet($foreignActor)->assertOk()->assertJsonPath('meta.configured', false);
    }

    /**
     * @param  list<array{0: int, 1: int}>  $ranges
     * @return list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>
     */
    private function validSet(array $ranges = [[86, 100], [71, 85], [51, 70], [0, 50]]): array
    {
        $codes = UnderstandingCategoryCode::cases();
        $entries = [];

        foreach (array_slice($codes, 0, 4) as $index => $code) {
            $entries[] = [
                'code' => $code->value,
                'min_score' => $ranges[$index][0],
                'max_score' => $ranges[$index][1],
                'sort_order' => $code->sortOrder(),
            ];
        }

        $entries[] = [
            'code' => UnderstandingCategoryCode::NotCompleted->value,
            'min_score' => null,
            'max_score' => null,
            'sort_order' => UnderstandingCategoryCode::NotCompleted->sortOrder(),
        ];

        return $entries;
    }

    /** @param list<array<string, mixed>> $categories */
    private function authorizedPut(User $actor, array $categories): TestResponse
    {
        return $this->authorizedRaw(
            'PUT',
            $actor,
            json_encode(['categories' => $categories], JSON_THROW_ON_ERROR),
        );
    }

    private function authorizedGet(User $actor): TestResponse
    {
        return $this->authorizedRaw('GET', $actor, '');
    }

    private function authorizedRaw(
        string $method,
        User $actor,
        string $content,
        array $query = [],
        string $contentType = 'application/json',
        array $serverOverrides = [],
    ): TestResponse {
        return $this->raw(
            $method,
            $content,
            $query,
            $contentType,
            array_merge($serverOverrides, ['HTTP_AUTHORIZATION' => 'Bearer '.$this->tokenFor($actor)]),
        );
    }

    private function raw(
        string $method,
        string $content,
        array $query = [],
        string $contentType = 'application/json',
        array $serverOverrides = [],
    ): TestResponse {
        $uri = self::URI.($query === [] ? '' : '?'.http_build_query($query));

        return $this->call(
            $method,
            $uri,
            [],
            [],
            [],
            array_merge([
                'CONTENT_TYPE' => $contentType,
                'HTTP_ACCEPT' => 'application/json',
            ], $serverOverrides),
            $content,
        );
    }

    private function tokenFor(User $actor): string
    {
        return $this->actorTokens[$actor->id]
            ??= $actor->createToken('institution-understanding-category-api-test')->plainTextToken;
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    /** @param array<string, mixed> $institutionAttributes */
    private function institutionWithSettings(array $institutionAttributes = []): Institution
    {
        $institution = Institution::factory()->create($institutionAttributes);
        InstitutionSetting::factory()->create(['institution_id' => $institution->id]);

        return $institution;
    }

    /** @param array<string, mixed> $attributes */
    private function institutionAdmin(Institution $institution, array $attributes = []): User
    {
        return User::factory()->institutionAdmin($institution)->create(array_merge([
            'must_change_password' => false,
        ], $attributes));
    }

    /**
     * @param  list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>|null  $set
     */
    private function persistSet(Institution $institution, User $updater, ?array $set = null): void
    {
        $timestamp = now();
        $rows = array_map(fn (array $entry): array => [
            'id' => Str::uuid()->toString(),
            'institution_id' => $institution->id,
            ...$entry,
            'updated_by_user_id' => $updater->id,
            'created_at' => $timestamp,
            'updated_at' => $timestamp,
        ], $set ?? $this->validSet());
        DB::table('institution_understanding_categories')->insert($rows);
    }

    /** @return list<array<string, mixed>> */
    private function categoryRows(string $institutionId): array
    {
        return DB::table('institution_understanding_categories')
            ->where('institution_id', $institutionId)
            ->orderBy('sort_order')
            ->get()
            ->map(fn (object $row): array => (array) $row)
            ->all();
    }

    /** @return list<array<string, mixed>> */
    private function tableRowsSnapshot(string $table, string $orderBy = 'id'): array
    {
        return DB::table($table)->orderBy($orderBy)->get()->map(fn (object $row): array => (array) $row)->all();
    }

    /**
     * @param  list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>  $expected
     */
    private function assertExactConfiguredResponse(TestResponse $response, array $expected): void
    {
        $this->assertSame(['data'], array_keys($response->json()));
        $data = $response->json('data');
        $this->assertCount(5, $data);
        $labels = array_column(array_map(fn (UnderstandingCategoryCode $code): array => [
            'code' => $code->value,
            'label' => $code->label(),
        ], UnderstandingCategoryCode::cases()), 'label', 'code');

        foreach ($data as $index => $item) {
            $this->assertSame(['code', 'label', 'min_score', 'max_score', 'sort_order'], array_keys($item));
            $this->assertSame($expected[$index]['code'], $item['code']);
            $this->assertSame($labels[$item['code']], $item['label']);
            $this->assertSame($expected[$index]['min_score'], $item['min_score']);
            $this->assertSame($expected[$index]['max_score'], $item['max_score']);
            $this->assertSame($expected[$index]['sort_order'], $item['sort_order']);
            $this->assertIsInt($item['sort_order']);
            $item['min_score'] === null ? $this->assertNull($item['min_score']) : $this->assertIsInt($item['min_score']);
            $item['max_score'] === null ? $this->assertNull($item['max_score']) : $this->assertIsInt($item['max_score']);
        }

        foreach ([
            'message', 'meta', 'links', 'id', 'institution_id', 'updated_by_user_id',
            'created_at', 'updated_at', 'settings', 'users', 'results', 'history', 'password', 'token',
        ] as $forbidden) {
            $this->assertStringNotContainsString('"'.$forbidden.'"', $response->getContent());
        }
    }

    private function assertErrorContract(TestResponse $response, int $status, string $code, string $case = ''): object
    {
        $this->assertSame($status, $response->getStatusCode(), $case.' response: '.$response->getContent());
        $decoded = json_decode($response->getContent());
        $this->assertIsObject($decoded, $case);
        $this->assertObjectHasProperty('message', $decoded, $case);
        $this->assertObjectHasProperty('code', $decoded, $case);
        $this->assertSame($code, $decoded->code, $case);
        $this->assertObjectHasProperty('errors', $decoded, $case);
        $this->assertIsObject($decoded->errors, $case);

        return $decoded;
    }

    private function assertSafeServerError(object $decoded, TestResponse $response, string $tenantId): void
    {
        $this->assertSame('An unexpected server error occurred.', $decoded->message);
        $serialized = $response->getContent();

        foreach ([$tenantId, 'institution_understanding_categories', 'institution_settings', 'SQLSTATE', 'constraint', 'stack', 'trace'] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $serialized);
        }
    }

    /** @param list<array<string, mixed>> $before */
    private function assertUnchanged(Institution $institution, array $before, array $settingsBefore, string $case): void
    {
        $this->assertSame($before, $this->categoryRows($institution->id), $case);
        $this->assertSame(
            $settingsBefore,
            InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal(),
            $case,
        );
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
    private function countCategoryDml(array $queries): int
    {
        return collect($queries)->filter(function (array $query): bool {
            $sql = strtolower((string) $query['query']);

            return str_contains($sql, 'institution_understanding_categories')
                && (str_starts_with($sql, 'insert ') || str_starts_with($sql, 'update ') || str_starts_with($sql, 'delete '));
        })->count();
    }

    /**
     * @param  list<array<string, mixed>>  $set
     * @param  array<string, mixed>  $replacement
     * @return list<array<string, mixed>>
     */
    private function replaceItem(array $set, int $index, array $replacement): array
    {
        $set[$index] = array_replace($set[$index], $replacement);

        return $set;
    }

    /**
     * @param  list<array<string, mixed>>  $set
     * @return list<array<string, mixed>>
     */
    private function withoutItemKey(array $set, int $index, string $key): array
    {
        unset($set[$index][$key]);

        return $set;
    }

    /** @return list<string> */
    private function protectedItemKeys(): array
    {
        return [
            'label', 'id', 'category_id', 'institution_id', 'updated_by_user_id', 'created_at',
            'updated_at', 'configured', 'meta', 'links', 'color', 'icon', 'name', 'result_id',
            'score', 'arbitrary_unknown',
        ];
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runRace(
        string $workerPath,
        string $firstActorId,
        string $secondActorId,
        string $firstPayload,
        string $secondPayload,
    ): array {
        $signalPath = tempnam(sys_get_temp_dir(), 's03_be_007_signal_');
        $this->assertIsString($signalPath);
        unlink($signalPath);
        $readyPath = $signalPath.'_ready';
        $first = $this->startWorker([
            $workerPath, base_path(), 'run', $firstActorId, $firstPayload, 'hold', $signalPath, $readyPath,
        ]);
        $deadline = microtime(true) + 3;

        while (! file_exists($signalPath) && microtime(true) < $deadline) {
            usleep(10_000);
        }

        $this->assertFileExists($signalPath, 'First worker did not acquire the stable settings-row lock.');
        $second = $this->startWorker([
            $workerPath, base_path(), 'run', $secondActorId, $secondPayload, 'normal', $signalPath, $readyPath,
        ]);
        $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
        $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);
        unlink($signalPath);
        unlink($readyPath);

        return [
            'first' => $firstResult,
            'second' => $secondResult,
        ];
    }

    /** @return array{first: array<string, mixed>, second: array<string, mixed>} */
    private function runIndependentRace(string $workerPath, string $firstActorId, string $secondActorId): array
    {
        return $this->runRace($workerPath, $firstActorId, $secondActorId, 'first', 'second');
    }

    /** @return array{process: resource, pipes: array<int, resource>} */
    private function startWorker(array $arguments): array
    {
        $pipes = [];
        $process = proc_open(array_merge([PHP_BINARY], $arguments), [
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

    private function postgresConcurrencyWorkerSource(): string
    {
        return <<<'PHP'
<?php

use App\Actions\Institution\ReplaceInstitutionUnderstandingCategories;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
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

if ($mode === 'setup-single') {
    $institution = Institution::factory()->create(['name' => 'S03 BE 007 race institution']);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $first = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    $second = User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    echo json_encode([
        'institutions' => [$institution->id],
        'actors' => ['first' => $first->id, 'second' => $second->id],
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'setup-two') {
    $firstInstitution = Institution::factory()->create(['name' => 'S03 BE 007 independent first']);
    $secondInstitution = Institution::factory()->create(['name' => 'S03 BE 007 independent second']);
    InstitutionSetting::factory()->create(['institution_id' => $firstInstitution->id]);
    InstitutionSetting::factory()->create(['institution_id' => $secondInstitution->id]);
    $firstActor = User::factory()->institutionAdmin($firstInstitution)->create(['must_change_password' => false]);
    $secondActor = User::factory()->institutionAdmin($secondInstitution)->create(['must_change_password' => false]);
    echo json_encode([
        'institutions' => [$firstInstitution->id, $secondInstitution->id],
        'first_actor' => $firstActor->id,
        'second_actor' => $secondActor->id,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    InstitutionUnderstandingCategory::query()->where('institution_id', $institutionId)->delete();
    InstitutionSetting::query()->where('institution_id', $institutionId)->delete();
    User::query()->where('institution_id', $institutionId)->delete();
    Institution::query()->whereKey($institutionId)->delete();
    echo json_encode(['cleaned' => $institutionId], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'reset') {
    InstitutionUnderstandingCategory::query()->where('institution_id', $argv[3])->delete();
    echo json_encode(['reset' => $argv[3]], JSON_THROW_ON_ERROR);
    exit(0);
}

$actor = User::query()->findOrFail($argv[3]);
$payloadName = $argv[4];
$hold = $argv[5] === 'hold';
$signalPath = $argv[6];
$readyPath = $argv[7];
$payloads = [
    'first' => [
        ['code' => 'understood_well', 'min_score' => 86, 'max_score' => 100, 'sort_order' => 1],
        ['code' => 'partially_understood', 'min_score' => 71, 'max_score' => 85, 'sort_order' => 2],
        ['code' => 'needs_revision', 'min_score' => 51, 'max_score' => 70, 'sort_order' => 3],
        ['code' => 'needs_teacher_support', 'min_score' => 0, 'max_score' => 50, 'sort_order' => 4],
        ['code' => 'not_completed', 'min_score' => null, 'max_score' => null, 'sort_order' => 5],
    ],
    'second' => [
        ['code' => 'understood_well', 'min_score' => 91, 'max_score' => 100, 'sort_order' => 1],
        ['code' => 'partially_understood', 'min_score' => 81, 'max_score' => 90, 'sort_order' => 2],
        ['code' => 'needs_revision', 'min_score' => 41, 'max_score' => 80, 'sort_order' => 3],
        ['code' => 'needs_teacher_support', 'min_score' => 0, 'max_score' => 40, 'sort_order' => 4],
        ['code' => 'not_completed', 'min_score' => null, 'max_score' => null, 'sort_order' => 5],
    ],
    'same' => [
        ['code' => 'understood_well', 'min_score' => 96, 'max_score' => 100, 'sort_order' => 1],
        ['code' => 'partially_understood', 'min_score' => 76, 'max_score' => 95, 'sort_order' => 2],
        ['code' => 'needs_revision', 'min_score' => 26, 'max_score' => 75, 'sort_order' => 3],
        ['code' => 'needs_teacher_support', 'min_score' => 0, 'max_score' => 25, 'sort_order' => 4],
        ['code' => 'not_completed', 'min_score' => null, 'max_score' => null, 'sort_order' => 5],
    ],
];

DB::flushQueryLog();
DB::enableQueryLog();

if ($hold) {
    DB::beginTransaction();
}

try {
    if (! $hold) {
        file_put_contents($readyPath, 'ready');
    }

    $actionStartedAt = microtime(true);
    $categories = (new ReplaceInstitutionUnderstandingCategories(app(\App\Domain\Institution\UnderstandingCategorySetValidator::class)))(
        $actor,
        $payloads[$payloadName],
    );
    $actionElapsedSeconds = microtime(true) - $actionStartedAt;
    $queries = DB::getQueryLog();

    if ($hold) {
        file_put_contents($signalPath, 'locked');

        $readyDeadline = microtime(true) + 4;

        while (! file_exists($readyPath) && microtime(true) < $readyDeadline) {
            usleep(10_000);
        }

        if (! file_exists($readyPath)) {
            throw new RuntimeException('Second race worker did not become ready.');
        }

        usleep(700_000);
        DB::commit();
    }

    $dml = count(array_filter($queries, static function (array $query): bool {
        $sql = strtolower((string) $query['query']);

        return str_contains($sql, 'institution_understanding_categories')
            && (str_starts_with($sql, 'insert ') || str_starts_with($sql, 'update ') || str_starts_with($sql, 'delete '));
    }));
    echo json_encode([
        'payload' => $payloadName,
        'institution_id' => $actor->institution_id,
        'count' => $categories->count(),
        'dml' => $dml,
        'action_elapsed_seconds' => $actionElapsedSeconds,
        'state' => $categories->map(fn ($category): array => [
            'code' => $category->code->value,
            'min_score' => $category->min_score,
            'max_score' => $category->max_score,
            'sort_order' => $category->sort_order,
            'updated_by_user_id' => $category->updated_by_user_id,
        ])->all(),
    ], JSON_THROW_ON_ERROR);
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
