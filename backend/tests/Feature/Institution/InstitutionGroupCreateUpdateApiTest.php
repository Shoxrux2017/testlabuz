<?php

namespace Tests\Feature\Institution;

use App\Enums\GroupStatus;
use App\Enums\UserRole;
use App\Exceptions\Institution\GroupArchivedException;
use App\Models\Group;
use App\Models\GroupStudentMembership;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use RuntimeException;
use Tests\TestCase;

class InstitutionGroupCreateUpdateApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/institution/groups';

    private const RESOURCE_KEYS = [
        'id',
        'name',
        'level',
        'subject_direction',
        'description',
        'status',
        'teachers_count',
        'students_count',
        'archived_at',
        'created_at',
        'updated_at',
    ];

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_create_trims_fields_derives_protected_state_allows_duplicates_and_returns_exact_resource(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 10:00:00', 'UTC'));
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $foreignInstitution = Institution::factory()->create();
        $foreignActor = $this->institutionAdmin($foreignInstitution);

        $response = $this->jsonRequestAs($actor, 'POST', self::BASE_URI, [
            'name' => '  10-A  ',
            'level' => '  Grade 10  ',
            'subject_direction' => '  General  ',
            'description' => null,
        ]);

        $response->assertCreated();
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame('Group created successfully.', $response->json('message'));
        $this->assertGroupResource($response->json('data'));
        $this->assertSame('10-A', $response->json('data.name'));
        $this->assertSame('Grade 10', $response->json('data.level'));
        $this->assertSame('General', $response->json('data.subject_direction'));
        $this->assertNull($response->json('data.description'));
        $this->assertSame('active', $response->json('data.status'));
        $this->assertSame(0, $response->json('data.teachers_count'));
        $this->assertSame(0, $response->json('data.students_count'));
        $this->assertNull($response->json('data.archived_at'));
        $this->assertSame('2026-08-19T10:00:00Z', $response->json('data.created_at'));
        $this->assertSame('2026-08-19T10:00:00Z', $response->json('data.updated_at'));

        $created = Group::query()->findOrFail($response->json('data.id'));
        $this->assertSame($institution->id, $created->institution_id);
        $this->assertSame($actor->id, $created->created_by_user_id);
        $this->assertSame(GroupStatus::Active, $created->status);
        $this->assertNull($created->archived_at);

        $duplicate = $this->jsonRequestAs($actor, 'POST', self::BASE_URI, ['name' => '10-A']);
        $duplicate->assertCreated()->assertJsonPath('data.name', '10-A');
        $this->assertNotSame($created->id, $duplicate->json('data.id'));
        $this->assertSame(2, Group::query()->where('institution_id', $institution->id)->where('name', '10-A')->count());

        $foreign = $this->jsonRequestAs($foreignActor, 'POST', self::BASE_URI, ['name' => '10-A']);
        $foreign->assertCreated();
        $this->assertSame($foreignInstitution->id, Group::query()->findOrFail($foreign->json('data.id'))->institution_id);

        $content = $response->getContent();
        foreach (['institution_id', 'created_by_user_id', 'password', 'membership_id'] as $protected) {
            $this->assertStringNotContainsString($protected, $content);
        }
    }

    public function test_create_accepts_nullable_optionals_and_rejects_every_invalid_or_protected_shape_atomically(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);

        $nullable = $this->jsonRequestAs($actor, 'POST', self::BASE_URI, [
            'name' => 'Nullable Group',
            'level' => null,
            'subject_direction' => null,
            'description' => null,
        ]);
        $nullable->assertCreated();
        $this->assertNull($nullable->json('data.level'));
        $this->assertNull($nullable->json('data.subject_direction'));
        $this->assertNull($nullable->json('data.description'));

        $before = Group::query()->count();
        $cases = [
            ['', 'application/json'],
            ['{', 'application/json'],
            ['[]', 'application/json'],
            ['"scalar"', 'application/json'],
            ['null', 'application/json'],
            ['{"name":"Wrong type"}', 'text/plain'],
            ['{}', 'application/json'],
            [json_encode(['name' => '   '], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => null], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => str_repeat('n', 161)], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => 'X', 'level' => '   '], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => 'X', 'subject_direction' => ''], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => 'X', 'description' => " \t "], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => 'X', 'level' => str_repeat('l', 101)], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => 'X', 'subject_direction' => str_repeat('s', 161)], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => 'X', 'level' => 10], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => 'X', 'unknown' => true], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode([
                'name' => 'Forged',
                'id' => '11111111-1111-4111-8111-111111111111',
                'institution_id' => $institution->id,
                'status' => 'archived',
                'created_by_user_id' => $actor->id,
                'archived_at' => now()->toJSON(),
                'created_at' => now()->toJSON(),
                'updated_at' => now()->toJSON(),
            ], JSON_THROW_ON_ERROR), 'application/json'],
        ];

        foreach ($cases as [$content, $contentType]) {
            $this->rawRequestAs($actor, 'POST', self::BASE_URI, $content, contentType: $contentType)
                ->assertUnprocessable()
                ->assertJsonPath('code', 'validation_failed');
            $this->assertSame($before, Group::query()->count(), $content);
        }

        $this->rawRequestAs(
            $actor,
            'POST',
            self::BASE_URI,
            json_encode(['name' => 'Query Group'], JSON_THROW_ON_ERROR),
            query: ['status' => 'active'],
        )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, Group::query()->count());
    }

    public function test_create_transaction_rolls_back_a_controlled_post_insert_failure_and_returns_safe_error(): void
    {
        config(['app.debug' => false]);
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $internalDetail = 'controlled group insert failure '.$institution->id;

        Event::listen('eloquent.created: '.Group::class, function (Group $group) use ($internalDetail): void {
            if ($group->name === 'Rollback Group') {
                throw new RuntimeException($internalDetail);
            }
        });

        $response = $this->jsonRequestAs($actor, 'POST', self::BASE_URI, ['name' => 'Rollback Group']);

        $response->assertStatus(500)->assertJsonPath('code', 'server_error');
        $this->assertStringNotContainsString($internalDetail, $response->getContent());
        $this->assertDatabaseMissing('groups', [
            'institution_id' => $institution->id,
            'name' => 'Rollback Group',
        ]);
    }

    public function test_update_is_strict_partial_tenant_scoped_and_clears_nullable_fields_without_changing_omissions(): void
    {
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 11:00:00', 'UTC'));
        $institution = Institution::factory()->create();
        $otherInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $otherActor = $this->institutionAdmin($otherInstitution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Original',
            'level' => 'Grade 9',
            'subject_direction' => 'General',
            'description' => 'Original description',
            'created_at' => CarbonImmutable::parse('2026-08-19 09:00:00', 'UTC'),
            'updated_at' => CarbonImmutable::parse('2026-08-19 09:00:00', 'UTC'),
        ]);
        $foreign = Group::factory()->create([
            'institution_id' => $otherInstitution->id,
            'created_by_user_id' => $otherActor->id,
        ]);
        $teacher = User::factory()->teacher($institution)->create();
        $student = User::factory()->student($institution)->create();
        GroupTeacherMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $actor->id,
        ]);
        GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $actor->id,
        ]);

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $response = $this->jsonRequestAs($actor, 'PATCH', self::BASE_URI.'/'.$group->id, [
                'name' => '  Updated  ',
                'description' => null,
            ]);
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $response->assertOk();
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame('Group updated successfully.', $response->json('message'));
        $this->assertGroupResource($response->json('data'));
        $this->assertSame('Updated', $response->json('data.name'));
        $this->assertSame('Grade 9', $response->json('data.level'));
        $this->assertSame('General', $response->json('data.subject_direction'));
        $this->assertNull($response->json('data.description'));
        $this->assertSame(1, $response->json('data.teachers_count'));
        $this->assertSame(1, $response->json('data.students_count'));
        $this->assertSame('2026-08-19T11:00:00Z', $response->json('data.updated_at'));
        $this->assertSame(1, $this->groupUpdateCount($queries));
        $this->assertTrue($this->queriesContainScopedForUpdate($queries, $institution->id, $group->id));

        $group->refresh();
        $this->assertSame('Updated', $group->name);
        $this->assertSame('Grade 9', $group->level);
        $this->assertSame('General', $group->subject_direction);
        $this->assertNull($group->description);

        $foreignBefore = $foreign->refresh()->getRawOriginal();
        $this->jsonRequestAs($actor, 'PATCH', self::BASE_URI.'/'.$foreign->id, ['name' => 'Forged'])
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertSame($foreignBefore, $foreign->refresh()->getRawOriginal());
        $this->jsonRequestAs($actor, 'PATCH', self::BASE_URI.'/not-a-uuid', ['name' => 'Forged'])
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
    }

    public function test_exact_normalized_update_noop_issues_no_update_and_preserves_timestamp(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Same Name',
            'level' => 'Grade 10',
            'subject_direction' => null,
            'description' => 'Same description',
            'updated_at' => CarbonImmutable::parse('2026-08-19 09:00:00', 'UTC'),
        ]);
        $rawUpdatedAt = $group->refresh()->getRawOriginal('updated_at');
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 12:00:00', 'UTC'));

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $response = $this->jsonRequestAs($actor, 'PATCH', self::BASE_URI.'/'.$group->id, [
                'name' => '  Same Name  ',
                'level' => ' Grade 10 ',
                'subject_direction' => null,
                'description' => ' Same description ',
            ]);
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $response->assertOk()->assertJsonPath('data.updated_at', '2026-08-19T09:00:00Z');
        $this->assertSame(0, $this->groupUpdateCount($queries));
        $this->assertTrue($this->queriesContainScopedForUpdate($queries, $institution->id, $group->id));
        $this->assertSame($rawUpdatedAt, $group->refresh()->getRawOriginal('updated_at'));
    }

    public function test_update_rejects_invalid_transport_types_empty_strings_and_protected_fields_without_mutation(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $before = $group->refresh()->getRawOriginal();

        $cases = [
            ['', 'application/json'],
            ['{', 'application/json'],
            ['[]', 'application/json'],
            ['"scalar"', 'application/json'],
            ['{}', 'application/json'],
            ['{"name":"Wrong type"}', 'text/plain'],
            [json_encode(['name' => null], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => '   '], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['level' => ''], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['subject_direction' => '  '], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['description' => "\t"], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['name' => str_repeat('n', 161)], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['level' => str_repeat('l', 101)], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['subject_direction' => str_repeat('s', 161)], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['description' => []], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['unknown' => 'x'], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode([
                'name' => 'Forged',
                'id' => $group->id,
                'institution_id' => $institution->id,
                'status' => 'archived',
                'created_by_user_id' => $actor->id,
                'archived_at' => now()->toJSON(),
                'created_at' => now()->toJSON(),
                'updated_at' => now()->toJSON(),
            ], JSON_THROW_ON_ERROR), 'application/json'],
        ];

        foreach ($cases as [$content, $contentType]) {
            $this->rawRequestAs($actor, 'PATCH', self::BASE_URI.'/'.$group->id, $content, contentType: $contentType)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            $this->assertSame($before, $group->refresh()->getRawOriginal(), $content);
        }

        $this->rawRequestAs(
            $actor,
            'PATCH',
            self::BASE_URI.'/'.$group->id,
            json_encode(['name' => 'Query mutation'], JSON_THROW_ON_ERROR),
            query: ['x' => '1'],
        )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $group->refresh()->getRawOriginal());
    }

    public function test_archived_update_conflicts_before_noop_comparison_with_exact_centralized_envelope(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->archived()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
            'name' => 'Archived Name',
        ]);
        $before = $group->refresh()->getRawOriginal();

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $response = $this->jsonRequestAs($actor, 'PATCH', self::BASE_URI.'/'.$group->id, [
                'name' => 'Archived Name',
            ]);
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertGroupArchivedError($response);
        $this->assertSame(0, $this->groupUpdateCount($queries));
        $this->assertTrue($this->queriesContainScopedForUpdate($queries, $institution->id, $group->id));
        $this->assertSame($before, $group->refresh()->getRawOriginal());

        Route::patch('/api/v1/test-group-archived-mapping', function (): never {
            throw new GroupArchivedException;
        });
        $this->assertGroupArchivedError($this->rawRequest('PATCH', '/api/v1/test-group-archived-mapping'));
    }

    public function test_create_and_update_enforce_authentication_role_account_institution_and_password_gates(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $group = Group::factory()->create([
            'institution_id' => $institution->id,
            'created_by_user_id' => $actor->id,
        ]);
        $requests = [
            ['POST', self::BASE_URI, ['name' => 'Gate Create']],
            ['PATCH', self::BASE_URI.'/'.$group->id, ['name' => 'Gate Update']],
        ];

        foreach ($requests as [$method, $uri, $payload]) {
            $content = json_encode($payload, JSON_THROW_ON_ERROR);
            $this->rawRequest($method, $uri, content: $content)
                ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');

            $inactive = $this->institutionAdmin($institution, ['is_active' => false]);
            $this->rawRequestAs($inactive, $method, $uri, $content)
                ->assertForbidden()->assertJsonPath('code', 'user_inactive');

            $passwordIncomplete = $this->institutionAdmin($institution, ['must_change_password' => true]);
            $this->rawRequestAs($passwordIncomplete, $method, $uri, $content)
                ->assertForbidden()->assertJsonPath('code', 'password_change_required');

            $inactiveInstitution = Institution::factory()->inactive()->create();
            $inactiveInstitutionActor = $this->institutionAdmin($inactiveInstitution);
            $this->rawRequestAs($inactiveInstitutionActor, $method, $uri, $content)
                ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

            foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
                $wrongRole = $this->userForRole($role, $institution);
                $this->rawRequestAs($wrongRole, $method, $uri, $content)
                    ->assertForbidden()->assertJsonPath('code', 'forbidden');
            }
        }
    }

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
            UserRole::Teacher => User::factory()->teacher($institution),
            UserRole::Student => User::factory()->student($institution),
            UserRole::Parent => User::factory()->parent($institution),
            UserRole::InstitutionAdmin => User::factory()->institutionAdmin($institution),
        };

        return $factory->create(['must_change_password' => false]);
    }

    /** @param array<string, mixed> $payload */
    private function jsonRequestAs(User $actor, string $method, string $uri, array $payload): TestResponse
    {
        return $this->rawRequestAs($actor, $method, $uri, json_encode($payload, JSON_THROW_ON_ERROR));
    }

    /** @param array<string, mixed> $query */
    private function rawRequestAs(
        User $actor,
        string $method,
        string $uri,
        string $content,
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $token = $actor->createToken('institution-group-create-update-api-test')->plainTextToken;
        $response = $this->rawRequest($method, $uri, $token, $content, $query, $contentType);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @param array<string, mixed> $query */
    private function rawRequest(
        string $method,
        string $uri,
        ?string $token = null,
        string $content = '',
        array $query = [],
        string $contentType = 'application/json',
    ): TestResponse {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json'];

        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call($method, $requestUri, [], [], [], $server, $content);
    }

    /** @param array<string, mixed> $resource */
    private function assertGroupResource(array $resource): void
    {
        $this->assertSame(self::RESOURCE_KEYS, array_keys($resource));
        $this->assertIsInt($resource['teachers_count']);
        $this->assertIsInt($resource['students_count']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['created_at']);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['updated_at']);

        foreach (['institution_id', 'created_by_user_id', 'memberships', 'password'] as $protected) {
            $this->assertArrayNotHasKey($protected, $resource);
        }
    }

    /** @param list<array<string, mixed>> $queries */
    private function groupUpdateCount(array $queries): int
    {
        return collect($queries)
            ->filter(fn (array $query): bool => str_starts_with(strtolower((string) $query['query']), 'update "groups"'))
            ->count();
    }

    /** @param list<array<string, mixed>> $queries */
    private function queriesContainScopedForUpdate(array $queries, string $institutionId, string $groupId): bool
    {
        return collect($queries)->contains(function (array $query) use ($institutionId, $groupId): bool {
            $sql = strtolower((string) $query['query']);
            $bindings = array_map(static fn ($binding): string => (string) $binding, $query['bindings']);

            return str_contains($sql, 'for update')
                && str_contains($sql, '"institution_id"')
                && in_array($institutionId, $bindings, true)
                && in_array($groupId, $bindings, true);
        });
    }

    private function assertGroupArchivedError(TestResponse $response): void
    {
        $response->assertStatus(409);
        $decoded = json_decode($response->getContent());
        $this->assertIsObject($decoded);
        $this->assertSame(['message', 'code', 'errors'], array_keys(get_object_vars($decoded)));
        $this->assertSame('The group is archived.', $decoded->message);
        $this->assertSame('business_conflict', $decoded->code);
        $this->assertIsObject($decoded->errors);
        $this->assertSame([], get_object_vars($decoded->errors));
    }
}
