<?php

namespace Tests\Feature\Institution;

use App\Actions\Platform\CreatePlatformInstitution;
use App\Enums\BlitzTimerStartMode;
use App\Enums\InstitutionStatus;
use App\Enums\InstitutionType;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class InstitutionAssessmentSettingsApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/institution/settings/assessment';

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
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/institution/settings/assessment')
            ->values()
            ->all();

        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/institution/settings/assessment', 'middleware' => $middleware],
            ['methods' => ['PUT'], 'uri' => 'api/v1/institution/settings/assessment', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_get_returns_exact_unconfigured_and_configured_resources_with_one_scoped_read_and_no_write(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $this->tokenFor($actor);
        $setting = InstitutionSetting::query()->findOrFail($institution->id);
        $before = $setting->getRawOriginal();

        [$response, $queries] = $this->captureQueries(fn (): TestResponse => $this->authorizedGet($actor));

        $response->assertOk();
        $this->assertExactSettingsResource($response, [
            'educational_policy_configured' => false,
            'acceptable_score_difference' => null,
            'blitz_timer_start_mode' => null,
            'student_result_release_mode' => null,
            'parent_result_release_mode' => null,
            'timezone' => 'Asia/Tashkent',
            'learning_material_max_mb' => 25,
            'student_submission_max_mb' => 15,
        ]);
        $this->assertSame($before, $setting->refresh()->getRawOriginal());

        $settingQueries = collect($queries)->filter(
            fn (array $query): bool => str_contains(strtolower((string) $query['query']), '"institution_settings"')
        )->values();
        $this->assertCount(1, $settingQueries);
        $this->assertStringStartsWith('select', strtolower((string) $settingQueries[0]['query']));
        $this->assertFalse(str_contains(strtolower((string) $settingQueries[0]['query']), ' join '));
        $this->assertContains($institution->id, array_map('strval', $settingQueries[0]['bindings']));

        $setting->forceFill([
            'acceptable_score_difference' => '12.34567891',
            'blitz_timer_start_mode' => BlitzTimerStartMode::Individual,
        ])->save();
        $this->forgetAuthenticationGuards();

        $this->authorizedGet($actor)
            ->assertOk()
            ->assertJsonPath('data.educational_policy_configured', false)
            ->assertJsonPath('data.acceptable_score_difference', 12.34567891)
            ->assertJsonPath('data.blitz_timer_start_mode', 'individual');

        $setting->forceFill([
            'student_result_release_mode' => StudentResultReleaseMode::ManualTeacher,
            'parent_result_release_mode' => ParentResultReleaseMode::Hidden,
        ])->save();
        $this->forgetAuthenticationGuards();

        $configured = $this->authorizedGet($actor);
        $configured->assertOk();
        $this->assertExactSettingsResource($configured, [
            'educational_policy_configured' => true,
            'acceptable_score_difference' => 12.34567891,
            'blitz_timer_start_mode' => 'individual',
            'student_result_release_mode' => 'manual_teacher',
            'parent_result_release_mode' => 'hidden',
            'timezone' => 'Asia/Tashkent',
            'learning_material_max_mb' => 25,
            'student_submission_max_mb' => 15,
        ]);
    }

    public function test_get_rejects_every_body_and_query_input_without_mutating_settings(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $setting = InstitutionSetting::query()->findOrFail($institution->id);
        $this->tokenFor($actor);
        $before = $setting->getRawOriginal();

        $bodyCases = [
            'whitespace' => [" \t\r\n", 'application/json'],
            'empty object' => ['{}', 'application/json'],
            'keyed object' => ['{"timezone":"Asia/Tashkent"}', 'application/json'],
            'array' => ['[]', 'application/json'],
            'scalar' => ['1', 'application/json'],
            'null' => ['null', 'application/json'],
            'malformed' => ['{"timezone":', 'application/json'],
            'raw text' => ['not-json', 'text/plain'],
            'form' => ['timezone=Asia%2FTashkent', 'application/x-www-form-urlencoded'],
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
            $this->assertSame($before, $setting->refresh()->getRawOriginal(), $case);
            $this->forgetAuthenticationGuards();
        }

        foreach (array_merge($this->allowedInputKeys(), ['institution_id', 'unknown']) as $queryKey) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('GET', $actor, '', [$queryKey => 'value']),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($before, $setting->refresh()->getRawOriginal(), $queryKey);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_put_replaces_only_the_actor_institution_row_and_returns_exact_resource(): void
    {
        $institution = $this->institutionWithSettings(['name' => 'Own Institution']);
        $foreignInstitution = $this->institutionWithSettings(['name' => 'Foreign Institution']);
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $actor->createToken('preserved-actor-token');
        $foreignActor->createToken('preserved-foreign-token');
        $this->tokenFor($actor);

        $institutionRowsBefore = $this->tableRowsSnapshot('institutions');
        $userRowsBefore = $this->tableRowsSnapshot('users');
        $tokenRowsBefore = $this->tableRowsSnapshot('personal_access_tokens');
        $historicalRowsBefore = $this->optionalHistoricalRowsSnapshot();
        $foreignBefore = InstitutionSetting::query()->findOrFail($foreignInstitution->id)->getRawOriginal();

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 09:30:00', 'UTC'));

        try {
            $response = $this->authorizedRaw(
                'PUT',
                $actor,
                $this->validPayloadJson('12.34567891'),
                serverOverrides: ['HTTP_X_INSTITUTION_ID' => $foreignInstitution->id],
            );
        } finally {
            CarbonImmutable::setTestNow();
        }

        $response->assertOk();
        $this->assertExactSettingsResource($response, [
            'educational_policy_configured' => true,
            'acceptable_score_difference' => 12.34567891,
            'blitz_timer_start_mode' => 'individual',
            'student_result_release_mode' => 'manual_teacher',
            'parent_result_release_mode' => 'with_student',
            'timezone' => 'Europe/London',
            'learning_material_max_mb' => 20,
            'student_submission_max_mb' => 10,
        ]);

        $own = InstitutionSetting::query()->findOrFail($institution->id);
        $this->assertSame('12.34567891', $own->acceptable_score_difference);
        $this->assertSame(BlitzTimerStartMode::Individual, $own->blitz_timer_start_mode);
        $this->assertSame(StudentResultReleaseMode::ManualTeacher, $own->student_result_release_mode);
        $this->assertSame(ParentResultReleaseMode::WithStudent, $own->parent_result_release_mode);
        $this->assertSame('Europe/London', $own->timezone);
        $this->assertSame(20, $own->learning_material_max_mb);
        $this->assertSame(10, $own->student_submission_max_mb);
        $this->assertSame($actor->id, $own->updated_by_user_id);
        $this->assertSame('2026-08-14T09:30:00.000000Z', $own->updated_at?->toJSON());

        $this->assertSame($foreignBefore, InstitutionSetting::query()->findOrFail($foreignInstitution->id)->getRawOriginal());
        $this->assertSame($institutionRowsBefore, $this->tableRowsSnapshot('institutions'));
        $this->assertSame($userRowsBefore, $this->tableRowsSnapshot('users'));
        $this->assertSame($tokenRowsBefore, $this->tableRowsSnapshot('personal_access_tokens'));
        $this->assertSame($historicalRowsBefore, $this->optionalHistoricalRowsSnapshot());
        $this->assertSame(2, InstitutionSetting::query()
            ->whereIn('institution_id', [$institution->id, $foreignInstitution->id])
            ->count());
    }

    public function test_put_transport_required_allowlist_protected_and_query_validation_is_atomic(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $setting = InstitutionSetting::query()->findOrFail($institution->id);
        $this->tokenFor($actor);
        $before = $setting->getRawOriginal();

        $bodyCases = [
            'absent' => ['', 'application/json'],
            'whitespace' => [" \t\r\n", 'application/json'],
            'malformed' => ['{"timezone":', 'application/json'],
            'scalar' => ['1', 'application/json'],
            'array' => ['[]', 'application/json'],
            'null' => ['null', 'application/json'],
            'text' => ['{}', 'text/plain'],
            'form' => ['timezone=Asia%2FTashkent', 'application/x-www-form-urlencoded'],
            'multipart' => ['--boundary--', 'multipart/form-data; boundary=boundary'],
            'unsupported media parameter' => [$this->validPayloadJson(), 'application/json; profile=settings'],
        ];

        foreach ($bodyCases as $case => [$content, $contentType]) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('PUT', $actor, $content, contentType: $contentType),
                422,
                'validation_failed',
                $case,
            );
            $this->assertObjectHasProperty('body', $decoded->errors, $case);
            $this->assertSame($before, $setting->refresh()->getRawOriginal(), $case);
            $this->forgetAuthenticationGuards();
        }

        $empty = $this->assertErrorContract(
            $this->authorizedRaw('PUT', $actor, '{}'),
            422,
            'validation_failed',
            'empty object',
        );
        foreach ($this->allowedInputKeys() as $field) {
            $this->assertObjectHasProperty($field, $empty->errors, $field);
        }
        $this->assertSame($before, $setting->refresh()->getRawOriginal());
        $this->forgetAuthenticationGuards();

        foreach ($this->allowedInputKeys() as $omittedField) {
            $payload = $this->validPayload();
            unset($payload[$omittedField]);
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('PUT', $actor, json_encode($payload, JSON_THROW_ON_ERROR)),
                422,
                'validation_failed',
                $omittedField,
            );
            $this->assertObjectHasProperty($omittedField, $decoded->errors, $omittedField);
            $this->assertSame($before, $setting->refresh()->getRawOriginal(), $omittedField);
            $this->forgetAuthenticationGuards();
        }

        foreach ($this->protectedInput() as $key => $value) {
            $payload = array_merge($this->validPayload(), [$key => $value]);
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('PUT', $actor, json_encode($payload, JSON_THROW_ON_ERROR)),
                422,
                'validation_failed',
                $key,
            );
            $this->assertObjectHasProperty($key, $decoded->errors, $key);
            $this->assertSame($before, $setting->refresh()->getRawOriginal(), $key);
            $this->forgetAuthenticationGuards();
        }

        foreach (array_merge($this->allowedInputKeys(), ['institution_id', 'unknown']) as $queryKey) {
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('PUT', $actor, $this->validPayloadJson(), [$queryKey => 'value']),
                422,
                'validation_failed',
                $queryKey,
            );
            $this->assertObjectHasProperty($queryKey, $decoded->errors, $queryKey);
            $this->assertSame($before, $setting->refresh()->getRawOriginal(), $queryKey);
            $this->forgetAuthenticationGuards();
        }

        $charsetResponse = $this->authorizedRaw(
            'PUT',
            $actor,
            $this->validPayloadJson(),
            contentType: 'application/json; charset=UTF-8',
        );
        $charsetResponse->assertOk();
    }

    public function test_score_difference_enforces_json_number_range_and_eight_decimal_places_without_rounding(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $this->tokenFor($actor);

        foreach ([
            '0' => '0.00000000',
            '100' => '100.00000000',
            '1.2' => '1.20000000',
            '12.34567891' => '12.34567891',
            '1e-8' => '0.00000001',
            '1.234567891e1' => '12.34567891',
        ] as $literal => $stored) {
            $response = $this->authorizedRaw('PUT', $actor, $this->validPayloadJson($literal));
            $response->assertOk();
            $this->assertTrue(is_int($response->json('data.acceptable_score_difference'))
                || is_float($response->json('data.acceptable_score_difference')));
            $this->assertSame($stored, InstitutionSetting::query()->findOrFail($institution->id)->acceptable_score_difference);
            $this->forgetAuthenticationGuards();
        }

        $invalidLiterals = [
            '"10"',
            'true',
            'false',
            'null',
            '-0.00000001',
            '100.00000001',
            '1.234567891',
            '1e-9',
        ];

        foreach ($invalidLiterals as $literal) {
            $before = InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal();
            $decoded = $this->assertErrorContract(
                $this->authorizedRaw('PUT', $actor, $this->validPayloadJson($literal)),
                422,
                'validation_failed',
                $literal,
            );
            $this->assertObjectHasProperty('acceptable_score_difference', $decoded->errors, $literal);
            $this->assertSame($before, InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal(), $literal);
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_enum_timezone_and_upload_validation_are_exact_and_non_coercing(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $this->tokenFor($actor);

        foreach (BlitzTimerStartMode::values() as $value) {
            $this->validPutWith($actor, ['blitz_timer_start_mode' => $value])
                ->assertJsonPath('data.blitz_timer_start_mode', $value);
            $this->forgetAuthenticationGuards();
        }
        foreach (StudentResultReleaseMode::values() as $value) {
            $this->validPutWith($actor, ['student_result_release_mode' => $value])
                ->assertJsonPath('data.student_result_release_mode', $value);
            $this->forgetAuthenticationGuards();
        }
        foreach (ParentResultReleaseMode::values() as $value) {
            $this->validPutWith($actor, ['parent_result_release_mode' => $value])
                ->assertJsonPath('data.parent_result_release_mode', $value);
            $this->forgetAuthenticationGuards();
        }

        foreach (['Asia/Tashkent', 'Europe/London', 'America/New_York'] as $timezone) {
            $this->assertContains($timezone, timezone_identifiers_list());
            $this->validPutWith($actor, ['timezone' => $timezone])
                ->assertJsonPath('data.timezone', $timezone);
            $this->forgetAuthenticationGuards();
        }

        foreach ([
            'blitz_timer_start_mode' => ['Synchronized', ' synchronized', 'teacher', 1, true, null],
            'student_result_release_mode' => ['Automatic', ' automatic', 'instant', 1, true, null],
            'parent_result_release_mode' => ['With_Student', 'with_student ', 'before_student', 1, true, null],
            'timezone' => ['', ' ', '+05:00', 'asia/tashkent', 'Not/A_Zone', str_repeat('x', 64), str_repeat('x', 65), 1, true, null],
        ] as $field => $invalidValues) {
            foreach ($invalidValues as $invalidValue) {
                $this->assertFieldValidationWithoutMutation($actor, $institution, $field, $invalidValue);
            }
        }

        foreach ([1, 25] as $limit) {
            $this->validPutWith($actor, ['learning_material_max_mb' => $limit])
                ->assertJsonPath('data.upload_limits.learning_material_max_mb', $limit);
            $this->forgetAuthenticationGuards();
        }
        foreach ([1, 15] as $limit) {
            $this->validPutWith($actor, ['student_submission_max_mb' => $limit])
                ->assertJsonPath('data.upload_limits.student_submission_max_mb', $limit);
            $this->forgetAuthenticationGuards();
        }

        foreach ([0, 26, 1.5, '1', true, null] as $invalidValue) {
            $this->assertFieldValidationWithoutMutation($actor, $institution, 'learning_material_max_mb', $invalidValue);
        }
        foreach ([0, 16, 1.5, '1', true, null] as $invalidValue) {
            $this->assertFieldValidationWithoutMutation($actor, $institution, 'student_submission_max_mb', $invalidValue);
        }
    }

    public function test_put_uses_scoped_row_lock_and_exact_no_op_and_updater_timestamp_rules(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $otherActor = $this->institutionAdmin($institution);
        $this->tokenFor($actor);
        $this->tokenFor($otherActor);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 10:00:00', 'UTC'));
        $this->authorizedRaw('PUT', $actor, $this->validPayloadJson())->assertOk();
        $setting = InstitutionSetting::query()->findOrFail($institution->id);
        $initialUpdatedAt = $setting->updated_at?->toJSON();
        $this->forgetAuthenticationGuards();

        try {
            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 11:00:00', 'UTC'));
            [$noOpResponse, $noOpQueries] = $this->captureQueries(
                fn (): TestResponse => $this->authorizedRaw('PUT', $actor, $this->validPayloadJson())
            );
            $noOpResponse->assertOk();
            $this->assertSame(0, $this->countSettingsUpdates($noOpQueries));
            $this->assertTrue($this->queriesContainScopedForUpdate($noOpQueries, $institution->id));
            $this->assertSame($initialUpdatedAt, $setting->refresh()->updated_at?->toJSON());
            $this->assertSame($actor->id, $setting->updated_by_user_id);
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 12:00:00', 'UTC'));
            [$updaterResponse, $updaterQueries] = $this->captureQueries(
                fn (): TestResponse => $this->authorizedRaw('PUT', $otherActor, $this->validPayloadJson())
            );
            $updaterResponse->assertOk();
            $this->assertSame(1, $this->countSettingsUpdates($updaterQueries));
            $this->assertSame($otherActor->id, $setting->refresh()->updated_by_user_id);
            $this->assertSame('2026-08-14T12:00:00.000000Z', $setting->updated_at?->toJSON());
            $this->forgetAuthenticationGuards();

            CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-14 13:00:00', 'UTC'));
            $changedPayload = $this->validPayload();
            $changedPayload['learning_material_max_mb'] = 19;
            [$changedResponse, $changedQueries] = $this->captureQueries(fn (): TestResponse => $this->authorizedRaw(
                'PUT',
                $otherActor,
                json_encode($changedPayload, JSON_THROW_ON_ERROR),
            ));
            $changedResponse->assertOk();
            $this->assertSame(1, $this->countSettingsUpdates($changedQueries));
            $this->assertSame('2026-08-14T13:00:00.000000Z', $setting->refresh()->updated_at?->toJSON());
        } finally {
            CarbonImmutable::setTestNow();
        }

        $this->assertSame(1, InstitutionSetting::query()->where('institution_id', $institution->id)->count());
        $this->assertSame($setting->created_at?->toJSON(), $setting->refresh()->created_at?->toJSON());
    }

    public function test_missing_mandatory_settings_row_returns_safe_server_error_and_never_creates_one(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $this->tokenFor($actor);

        foreach ([
            'GET' => '',
            'PUT' => $this->validPayloadJson(),
        ] as $method => $content) {
            $response = $this->authorizedRaw($method, $actor, $content);
            $decoded = $this->assertErrorContract($response, 500, 'server_error', $method);
            $serialized = json_encode($decoded, JSON_THROW_ON_ERROR);
            $this->assertStringNotContainsString($institution->id, $serialized);
            $this->assertStringNotContainsString('institution_settings', $serialized);
            $this->assertStringNotContainsString('SQLSTATE', $serialized);
            $this->assertSame(0, InstitutionSetting::query()->where('institution_id', $institution->id)->count());
            $this->forgetAuthenticationGuards();
        }
    }

    public function test_middleware_precedes_validation_for_unauthenticated_inactive_password_and_wrong_role_requests(): void
    {
        $institution = $this->institutionWithSettings();
        $inactiveInstitution = $this->institutionWithSettings([
            'status' => InstitutionStatus::Inactive,
            'deactivated_at' => now(),
        ]);

        foreach (['GET', 'PUT'] as $method) {
            $unauthenticated = $this->raw($method, '{"unknown":true}');
            $this->assertErrorContract($unauthenticated, 401, 'authentication_required', $method);
        }

        $cases = [
            'inactive actor' => [$this->institutionAdmin($institution, ['is_active' => false, 'deactivated_at' => now()]), 'user_inactive'],
            'inactive institution' => [$this->institutionAdmin($inactiveInstitution), 'institution_inactive'],
            'password gate' => [$this->institutionAdmin($institution, ['must_change_password' => true]), 'password_change_required'],
            'platform owner' => [User::factory()->platformOwner()->create(), 'forbidden'],
            'teacher' => [User::factory()->teacher($institution)->create(['must_change_password' => false]), 'forbidden'],
            'student' => [User::factory()->student($institution)->create(['must_change_password' => false]), 'forbidden'],
            'parent' => [User::factory()->parent($institution)->create(['must_change_password' => false]), 'forbidden'],
        ];

        foreach ($cases as $case => [$actor, $code]) {
            $this->tokenFor($actor);
            foreach (['GET', 'PUT'] as $method) {
                $decoded = $this->assertErrorContract(
                    $this->authorizedRaw($method, $actor, '{"unknown":true}'),
                    403,
                    $code,
                    $case.' '.$method,
                );
                $this->assertSame([], (array) $decoded->errors);
                $this->forgetAuthenticationGuards();
            }
        }
    }

    public function test_controlled_post_lock_database_failure_rolls_back_and_returns_safe_server_error(): void
    {
        $institution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $this->tokenFor($actor);
        $before = InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal();
        $constraint = 'institution_settings_s03_be_006_rollback';

        DB::statement("alter table institution_settings add constraint {$constraint} check (timezone <> 'Europe/London')");

        try {
            $response = $this->authorizedRaw('PUT', $actor, $this->validPayloadJson());
            $decoded = $this->assertErrorContract($response, 500, 'server_error');
            $serialized = json_encode($decoded, JSON_THROW_ON_ERROR);
            foreach (['institution_settings', $constraint, 'SQLSTATE', 'Europe/London', $institution->id, $actor->id, 'stack'] as $privateValue) {
                $this->assertStringNotContainsString($privateValue, $serialized);
            }
            $this->assertSame($before, InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal());
        } finally {
            DB::statement("alter table institution_settings drop constraint {$constraint}");
        }
    }

    public function test_controlled_postgresql_process_races_serialize_complete_replacements(): void
    {
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $workerPath = tempnam(sys_get_temp_dir(), 's03_be_006_worker_');
        $this->assertIsString($workerPath);
        file_put_contents($workerPath, $this->postgresConcurrencyWorkerSource());
        $setup = $this->runWorker([$workerPath, base_path(), 'setup']);
        $ids = json_decode($setup, true, flags: JSON_THROW_ON_ERROR);

        try {
            $sameRace = $this->runRace(
                $workerPath,
                $ids['actors']['first'],
                $ids['actors']['first'],
                'same',
                'same',
            );
            $this->assertSame([1, 0], [$sameRace['first']['updates'], $sameRace['second']['updates']]);
            $this->assertSame($sameRace['first']['state'], $sameRace['second']['state']);

            $distinctRace = $this->runRace(
                $workerPath,
                $ids['actors']['first'],
                $ids['actors']['second'],
                'first',
                'second',
            );
            $this->assertSame([1, 1], [$distinctRace['first']['updates'], $distinctRace['second']['updates']]);
            $this->assertSame('Asia/Tokyo', $distinctRace['first']['state']['timezone']);
            $this->assertSame('America/New_York', $distinctRace['second']['state']['timezone']);
            $this->assertSame($ids['actors']['first'], $distinctRace['first']['state']['updated_by_user_id']);
            $this->assertSame($ids['actors']['second'], $distinctRace['second']['state']['updated_by_user_id']);

            $final = InstitutionSetting::query()->findOrFail($ids['institution']);
            $this->assertSame('90.87654321', $final->acceptable_score_difference);
            $this->assertSame(BlitzTimerStartMode::Individual, $final->blitz_timer_start_mode);
            $this->assertSame(StudentResultReleaseMode::ManualTeacher, $final->student_result_release_mode);
            $this->assertSame(ParentResultReleaseMode::Hidden, $final->parent_result_release_mode);
            $this->assertSame('America/New_York', $final->timezone);
            $this->assertSame(18, $final->learning_material_max_mb);
            $this->assertSame(9, $final->student_submission_max_mb);
            $this->assertSame($ids['actors']['second'], $final->updated_by_user_id);
            $this->assertSame(1, InstitutionSetting::query()->where('institution_id', $ids['institution'])->count());
        } finally {
            $cleanupJson = $this->runWorker([$workerPath, base_path(), 'cleanup', $ids['institution']]);
            $this->assertJson($cleanupJson, $cleanupJson === '' ? '<empty cleanup output>' : $cleanupJson);
            $cleanup = json_decode($cleanupJson, true, flags: JSON_THROW_ON_ERROR);
            $this->assertSame(['users' => 2, 'settings' => 1, 'institution' => 1], $cleanup);
            $this->assertSame(0, Institution::query()->whereKey($ids['institution'])->count());
            $this->assertSame(0, InstitutionSetting::query()->where('institution_id', $ids['institution'])->count());
            unlink($workerPath);
        }
    }

    public function test_stage_two_initialization_and_controlled_real_stack_smoke_remain_valid(): void
    {
        $platformOwner = User::factory()->platformOwner()->create();
        $institution = (new CreatePlatformInstitution)(
            actor: $platformOwner,
            name: 'S03 BE 006 Smoke Institution',
            type: InstitutionType::School,
            status: InstitutionStatus::Active,
            contactEmail: null,
            contactPhone: null,
            address: null,
            description: null,
        );
        $foreignInstitution = $this->institutionWithSettings();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $this->tokenFor($actor);
        $this->tokenFor($foreignActor);

        $this->assertSame(1, InstitutionSetting::query()->where('institution_id', $institution->id)->count());
        $this->authorizedGet($actor)
            ->assertOk()
            ->assertJsonPath('data.educational_policy_configured', false)
            ->assertJsonPath('data.timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.upload_limits.learning_material_max_mb', 25)
            ->assertJsonPath('data.upload_limits.student_submission_max_mb', 15);
        $this->forgetAuthenticationGuards();

        $this->authorizedRaw('PUT', $actor, $this->validPayloadJson())
            ->assertOk()
            ->assertJsonPath('data.educational_policy_configured', true);
        $updatedAt = InstitutionSetting::query()->findOrFail($institution->id)->updated_at?->toJSON();
        $this->forgetAuthenticationGuards();

        $this->authorizedRaw('PUT', $actor, $this->validPayloadJson())->assertOk();
        $this->assertSame($updatedAt, InstitutionSetting::query()->findOrFail($institution->id)->updated_at?->toJSON());
        $this->forgetAuthenticationGuards();

        foreach ([
            $this->validPutWith($actor, ['learning_material_max_mb' => 26]),
            $this->validPutWith($actor, ['timezone' => 'Invalid/Timezone']),
            $this->authorizedRaw('PUT', $actor, '{}'),
            $this->validPutWith($actor, ['homework_attempt_limit' => 4]),
            $this->validPutWith($actor, ['unknown' => true]),
            $this->authorizedRaw('PUT', $actor, $this->validPayloadJson(), ['institution_id' => $foreignInstitution->id]),
        ] as $response) {
            $response->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            $this->forgetAuthenticationGuards();
        }

        $this->authorizedGet($foreignActor)
            ->assertOk()
            ->assertJsonPath('data.educational_policy_configured', false)
            ->assertJsonPath('data.timezone', 'Asia/Tashkent');
        $this->assertSame(2, InstitutionSetting::query()
            ->whereIn('institution_id', [$institution->id, $foreignInstitution->id])
            ->count());
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

    /** @return array<string, mixed> */
    private function validPayload(): array
    {
        return [
            'acceptable_score_difference' => 12.34567891,
            'blitz_timer_start_mode' => 'individual',
            'student_result_release_mode' => 'manual_teacher',
            'parent_result_release_mode' => 'with_student',
            'timezone' => 'Europe/London',
            'learning_material_max_mb' => 20,
            'student_submission_max_mb' => 10,
        ];
    }

    private function validPayloadJson(string $scoreDifferenceLiteral = '12.34567891'): string
    {
        return '{'
            .'"acceptable_score_difference":'.$scoreDifferenceLiteral.','
            .'"blitz_timer_start_mode":"individual",'
            .'"student_result_release_mode":"manual_teacher",'
            .'"parent_result_release_mode":"with_student",'
            .'"timezone":"Europe/London",'
            .'"learning_material_max_mb":20,'
            .'"student_submission_max_mb":10'
            .'}';
    }

    private function validPutWith(User $actor, array $overrides): TestResponse
    {
        return $this->authorizedRaw(
            'PUT',
            $actor,
            json_encode(array_merge($this->validPayload(), $overrides), JSON_THROW_ON_ERROR),
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
        $uri = self::URI;

        if ($query !== []) {
            $uri .= '?'.http_build_query($query);
        }

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

    private function tokenFor(User $user): string
    {
        return $this->actorTokens[$user->id]
            ??= $user->createToken('institution-assessment-settings-api-test')->plainTextToken;
    }

    private function forgetAuthenticationGuards(): void
    {
        $this->app['auth']->forgetGuards();
    }

    /** @return list<string> */
    private function allowedInputKeys(): array
    {
        return [
            'acceptable_score_difference',
            'blitz_timer_start_mode',
            'student_result_release_mode',
            'parent_result_release_mode',
            'timezone',
            'learning_material_max_mb',
            'student_submission_max_mb',
        ];
    }

    /** @return array<string, mixed> */
    private function protectedInput(): array
    {
        return [
            'institution_id' => Str::uuid()->toString(),
            'settings_id' => Str::uuid()->toString(),
            'id' => Str::uuid()->toString(),
            'updated_by_user_id' => Str::uuid()->toString(),
            'created_at' => '2026-08-14T10:00:00Z',
            'updated_at' => '2026-08-14T10:00:00Z',
            'educational_policy_configured' => true,
            'upload_limits' => ['learning_material_max_mb' => 99],
            'platform_learning_material_max_mb' => 99,
            'platform_student_submission_max_mb' => 99,
            'fixed_attempt_rules' => ['homework_normal_attempts' => 9],
            'homework_normal_attempts' => 9,
            'homework_attempt_limit' => 9,
            'blitz_normal_attempts' => 9,
            'blitz_attempt_limit' => 9,
            'blitz_max_additional_exception_attempts' => 9,
            'blitz_exception_attempt_limit' => 9,
            'understanding_categories' => [],
            'categories' => [],
            'category_ranges' => [],
            'users' => [],
            'files' => [],
            'results' => [],
            'history' => [],
            'arbitrary_container' => ['institution_id' => Str::uuid()->toString()],
        ];
    }

    private function assertFieldValidationWithoutMutation(
        User $actor,
        Institution $institution,
        string $field,
        mixed $invalidValue,
    ): void {
        $case = $field.'='.json_encode($invalidValue, JSON_THROW_ON_ERROR);
        $before = InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal();
        $decoded = $this->assertErrorContract(
            $this->validPutWith($actor, [$field => $invalidValue]),
            422,
            'validation_failed',
            $case,
        );
        $this->assertObjectHasProperty($field, $decoded->errors, $case);
        $this->assertSame($before, InstitutionSetting::query()->findOrFail($institution->id)->getRawOriginal(), $case);
        $this->forgetAuthenticationGuards();
    }

    /** @param array<string, mixed> $expected */
    private function assertExactSettingsResource(TestResponse $response, array $expected): void
    {
        $this->assertSame(['data'], array_keys($response->json()));
        $data = $response->json('data');
        $this->assertSame([
            'educational_policy_configured',
            'acceptable_score_difference',
            'blitz_timer_start_mode',
            'student_result_release_mode',
            'parent_result_release_mode',
            'timezone',
            'upload_limits',
            'fixed_attempt_rules',
        ], array_keys($data));
        $this->assertSame([
            'learning_material_max_mb',
            'student_submission_max_mb',
            'platform_learning_material_max_mb',
            'platform_student_submission_max_mb',
        ], array_keys($data['upload_limits']));
        $this->assertSame([
            'homework_normal_attempts',
            'blitz_normal_attempts',
            'blitz_max_additional_exception_attempts',
        ], array_keys($data['fixed_attempt_rules']));

        $this->assertSame($expected['educational_policy_configured'], $data['educational_policy_configured']);
        $this->assertSame($expected['acceptable_score_difference'], $data['acceptable_score_difference']);
        $this->assertSame($expected['blitz_timer_start_mode'], $data['blitz_timer_start_mode']);
        $this->assertSame($expected['student_result_release_mode'], $data['student_result_release_mode']);
        $this->assertSame($expected['parent_result_release_mode'], $data['parent_result_release_mode']);
        $this->assertSame($expected['timezone'], $data['timezone']);
        $this->assertSame($expected['learning_material_max_mb'], $data['upload_limits']['learning_material_max_mb']);
        $this->assertSame($expected['student_submission_max_mb'], $data['upload_limits']['student_submission_max_mb']);
        $this->assertSame(25, $data['upload_limits']['platform_learning_material_max_mb']);
        $this->assertSame(15, $data['upload_limits']['platform_student_submission_max_mb']);
        $this->assertSame(3, $data['fixed_attempt_rules']['homework_normal_attempts']);
        $this->assertSame(1, $data['fixed_attempt_rules']['blitz_normal_attempts']);
        $this->assertSame(1, $data['fixed_attempt_rules']['blitz_max_additional_exception_attempts']);

        $this->assertIsBool($data['educational_policy_configured']);
        $this->assertIsString($data['timezone']);
        foreach ($data['upload_limits'] as $limit) {
            $this->assertIsInt($limit);
        }
        foreach ($data['fixed_attempt_rules'] as $attemptRule) {
            $this->assertIsInt($attemptRule);
        }

        $serialized = $response->getContent();
        foreach ([
            'message',
            'meta',
            'links',
            'institution_id',
            'updated_by_user_id',
            'created_at',
            'updated_at',
            'understanding_categories',
            'password',
            'token',
            'answers',
            'scores',
            'results',
        ] as $forbidden) {
            $this->assertStringNotContainsString('"'.$forbidden.'"', $serialized);
        }
    }

    private function assertErrorContract(TestResponse $response, int $status, string $code, string $case = ''): object
    {
        $this->assertSame($status, $response->getStatusCode(), $case.' response: '.$response->getContent());
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

    /** @return list<array<string, mixed>> */
    private function tableRowsSnapshot(string $table): array
    {
        $orderBy = $table === 'institution_settings' ? 'institution_id' : 'id';

        return DB::table($table)->orderBy($orderBy)->get()->map(fn ($row): array => (array) $row)->all();
    }

    /** @return array<string, list<array<string, mixed>>> */
    private function optionalHistoricalRowsSnapshot(): array
    {
        $snapshots = [];
        $tables = [
            'institution_understanding_categories',
            'files',
            'learning_materials',
            'assessments',
            'homework_assignments',
            'blitz_tasks',
            'assessment_attempts',
            'attempt_answers',
            'official_task_scores',
            'topic_result_pairs',
            'topic_results',
        ];

        foreach ($tables as $table) {
            if (Schema::hasTable($table)) {
                $snapshots[$table] = DB::table($table)->get()->map(fn ($row): array => (array) $row)->all();
            }
        }

        return $snapshots;
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
    private function countSettingsUpdates(array $queries): int
    {
        return collect($queries)
            ->filter(fn (array $query): bool => str_starts_with(
                strtolower((string) $query['query']),
                'update "institution_settings"',
            ))
            ->count();
    }

    /** @param list<array<string, mixed>> $queries */
    private function queriesContainScopedForUpdate(array $queries, string $institutionId): bool
    {
        return collect($queries)->contains(function (array $query) use ($institutionId): bool {
            $sql = strtolower((string) $query['query']);
            $bindings = array_map('strval', $query['bindings']);

            return str_contains($sql, 'from "institution_settings"')
                && str_contains($sql, '"institution_id"')
                && str_contains($sql, 'for update')
                && in_array($institutionId, $bindings, true);
        });
    }

    /** @return array{first: array{updates: int, state: array<string, mixed>}, second: array{updates: int, state: array<string, mixed>}} */
    private function runRace(
        string $workerPath,
        string $firstActorId,
        string $secondActorId,
        string $firstOperation,
        string $secondOperation,
    ): array {
        $lockedPath = $this->unusedTempPath('s03_be_006_locked_');
        $releasePath = $this->unusedTempPath('s03_be_006_release_');
        $firstAttemptPath = $this->unusedTempPath('s03_be_006_attempt_first_');
        $secondAttemptPath = $this->unusedTempPath('s03_be_006_attempt_second_');
        $first = null;

        try {
            $first = $this->startWorker([
                $workerPath,
                base_path(),
                'run',
                $firstActorId,
                $firstOperation,
                'hold',
                $lockedPath,
                $releasePath,
                $firstAttemptPath,
            ]);
            $second = null;

            try {
                $this->waitForFile($lockedPath, 'First worker did not acquire and hold the PostgreSQL settings row lock.');
                $second = $this->startWorker([
                    $workerPath,
                    base_path(),
                    'run',
                    $secondActorId,
                    $secondOperation,
                    'normal',
                    $lockedPath,
                    $releasePath,
                    $secondAttemptPath,
                ]);
                $this->waitForFile($secondAttemptPath, 'Second worker did not begin its settings-row locking operation.');
                $this->waitForPostgresLock(
                    (int) file_get_contents($secondAttemptPath),
                    $firstOperation.' -> '.$secondOperation.' for institution assessment settings',
                );
            } catch (\Throwable $exception) {
                file_put_contents($releasePath, 'release');
                $secondOutput = $second === null ? '<not started>' : $this->finishWorker($second);
                $firstOutput = $this->finishWorker($first);
                $this->fail($exception->getMessage()."\nFirst: ".$firstOutput."\nSecond: ".$secondOutput);
            }

            file_put_contents($releasePath, 'release');
            $secondResult = json_decode($this->finishWorker($second), true, flags: JSON_THROW_ON_ERROR);
            $firstResult = json_decode($this->finishWorker($first), true, flags: JSON_THROW_ON_ERROR);

            return [
                'first' => $firstResult,
                'second' => $secondResult,
            ];
        } finally {
            if ($first !== null && ! file_exists($releasePath)) {
                file_put_contents($releasePath, 'release');
            }

            $this->removeTempPaths([$lockedPath, $releasePath, $firstAttemptPath, $secondAttemptPath]);
        }
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
            'Second worker never entered a PostgreSQL settings row-lock wait during %s. Last activity: %s',
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

use App\Actions\Institution\UpdateInstitutionAssessmentSettings;
use App\Enums\BlitzTimerStartMode;
use App\Enums\ParentResultReleaseMode;
use App\Enums\StudentResultReleaseMode;
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
    $institution = Institution::factory()->create(['name' => 'S03 BE 006 concurrency institution']);
    InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
    $actors = [
        'first' => User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]),
        'second' => User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]),
    ];
    echo json_encode([
        'institution' => $institution->id,
        'actors' => ['first' => $actors['first']->id, 'second' => $actors['second']->id],
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

if ($mode === 'cleanup') {
    $institutionId = $argv[3];
    $userIds = User::query()->where('institution_id', $institutionId)->pluck('id');
    PersonalAccessToken::query()->whereIn('tokenable_id', $userIds)->delete();
    $deletedSettings = InstitutionSetting::query()->where('institution_id', $institutionId)->delete();
    $deletedUsers = User::query()->where('institution_id', $institutionId)->delete();
    $deletedInstitution = Institution::query()->whereKey($institutionId)->delete();
    echo json_encode([
        'users' => $deletedUsers,
        'settings' => $deletedSettings,
        'institution' => $deletedInstitution,
    ], JSON_THROW_ON_ERROR);
    exit(0);
}

$actor = User::query()->findOrFail($argv[3]);
$operation = $argv[4];
$hold = $argv[5] === 'hold';
$lockedPath = $argv[6];
$releasePath = $argv[7];
$attemptPath = $argv[8];
$payload = match ($operation) {
    'same' => [
        'score' => '50.12345678',
        'blitz' => BlitzTimerStartMode::Synchronized,
        'student' => StudentResultReleaseMode::Automatic,
        'parent' => ParentResultReleaseMode::WithStudent,
        'timezone' => 'Europe/London',
        'learning' => 20,
        'submission' => 10,
    ],
    'first' => [
        'score' => '10.12345678',
        'blitz' => BlitzTimerStartMode::Synchronized,
        'student' => StudentResultReleaseMode::Automatic,
        'parent' => ParentResultReleaseMode::ManualTeacher,
        'timezone' => 'Asia/Tokyo',
        'learning' => 19,
        'submission' => 8,
    ],
    'second' => [
        'score' => '90.87654321',
        'blitz' => BlitzTimerStartMode::Individual,
        'student' => StudentResultReleaseMode::ManualTeacher,
        'parent' => ParentResultReleaseMode::Hidden,
        'timezone' => 'America/New_York',
        'learning' => 18,
        'submission' => 9,
    ],
};

$pid = DB::selectOne('select pg_backend_pid() as pid')->pid;
file_put_contents($attemptPath, (string) $pid);
DB::flushQueryLog();
DB::enableQueryLog();

if ($hold) {
    DB::beginTransaction();
}

try {
    $settings = (new UpdateInstitutionAssessmentSettings)(
        actor: $actor,
        acceptableScoreDifference: $payload['score'],
        blitzTimerStartMode: $payload['blitz'],
        studentResultReleaseMode: $payload['student'],
        parentResultReleaseMode: $payload['parent'],
        timezone: $payload['timezone'],
        learningMaterialMaxMb: $payload['learning'],
        studentSubmissionMaxMb: $payload['submission'],
    );
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
            fwrite(STDERR, 'Timed out waiting for deterministic assessment settings race release.');
            exit(1);
        }

        DB::commit();
    }

    $updates = count(array_filter(
        $queries,
        static fn (array $query): bool => str_starts_with(
            strtolower((string) $query['query']),
            'update "institution_settings"',
        ),
    ));
    echo json_encode([
        'updates' => $updates,
        'state' => [
            'acceptable_score_difference' => $settings->acceptable_score_difference,
            'blitz_timer_start_mode' => $settings->blitz_timer_start_mode->value,
            'student_result_release_mode' => $settings->student_result_release_mode->value,
            'parent_result_release_mode' => $settings->parent_result_release_mode->value,
            'timezone' => $settings->timezone,
            'learning_material_max_mb' => $settings->learning_material_max_mb,
            'student_submission_max_mb' => $settings->student_submission_max_mb,
            'updated_by_user_id' => $settings->updated_by_user_id,
        ],
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
