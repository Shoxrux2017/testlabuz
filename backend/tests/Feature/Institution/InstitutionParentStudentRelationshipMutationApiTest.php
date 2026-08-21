<?php

namespace Tests\Feature\Institution;

use App\Enums\UserRole;
use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class InstitutionParentStudentRelationshipMutationApiTest extends TestCase
{
    use RefreshDatabase;

    private const BASE_URI = '/api/v1/institution/parent-student-relationships';

    private const RESOURCE_KEYS = ['id', 'parent_id', 'student_id', 'started_at', 'ended_at'];

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_connect_disconnect_and_reconnect_are_idempotent_derived_and_history_preserving(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $parent = User::factory()->parent($institution)->create();
        $student = User::factory()->student($institution)->create();

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-19 10:00:00', 'UTC'));
        $created = $this->connect($actor, $parent, $student);
        $created->assertCreated()->assertJsonPath('message', 'Parent and student connected successfully.');
        $this->assertSame(self::RESOURCE_KEYS, array_keys($created->json('data')));
        $this->assertSame($parent->id, $created->json('data.parent_id'));
        $this->assertSame($student->id, $created->json('data.student_id'));
        $this->assertSame('2026-08-19T10:00:00Z', $created->json('data.started_at'));
        $this->assertNull($created->json('data.ended_at'));
        $relationship = ParentStudentRelationship::query()->findOrFail($created->json('data.id'));
        $this->assertSame($institution->id, $relationship->institution_id);
        $this->assertSame($actor->id, $relationship->connected_by_user_id);
        $this->assertNull($relationship->ended_at);
        $this->assertSame(
            ['started_at', 'created_at', 'updated_at'],
            array_keys($relationship->only(['started_at', 'created_at', 'updated_at'])),
        );

        $initialTimestamps = $this->timestamps($relationship);
        $parent->forceFill(['is_active' => false, 'deactivated_at' => now()])->save();
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-20 10:00:00', 'UTC'));
        $repeated = $this->connect($actor, $parent, $student);
        $repeated->assertOk();
        $this->assertSame($relationship->id, $repeated->json('data.id'));
        $this->assertSame($initialTimestamps, $this->timestamps($relationship->refresh()));
        $this->assertDatabaseCount('parent_student_relationships', 1);

        $inactiveStudent = User::factory()->student($institution)->inactive()->create();
        $this->connect($actor, $parent, $inactiveStudent)
            ->assertConflict()
            ->assertExactJson([
                'message' => 'The selected parent or student is inactive.',
                'code' => 'business_conflict',
                'errors' => [],
            ]);
        $this->assertDatabaseCount('parent_student_relationships', 1);

        $student->forceFill(['is_active' => false, 'deactivated_at' => now()])->save();
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-21 10:00:00', 'UTC'));
        $this->requestAs($actor, 'DELETE', self::BASE_URI.'/'.$relationship->id)
            ->assertNoContent()
            ->assertContent('');
        $relationship->refresh();
        $this->assertSame('2026-08-21T10:00:00.000000Z', $relationship->ended_at?->toJSON());
        $this->assertDatabaseCount('parent_student_relationships', 1);
        $endedTimestamps = $this->timestamps($relationship);

        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-08-22 10:00:00', 'UTC'));
        $this->requestAs($actor, 'DELETE', self::BASE_URI.'/'.$relationship->id)->assertNoContent();
        $this->assertSame($endedTimestamps, $this->timestamps($relationship->refresh()));

        $parent->forceFill(['is_active' => true, 'deactivated_at' => null])->save();
        $student->forceFill(['is_active' => true, 'deactivated_at' => null])->save();
        $reconnected = $this->connect($actor, $parent, $student);
        $reconnected->assertCreated();
        $this->assertNotSame($relationship->id, $reconnected->json('data.id'));
        $this->assertSame(2, ParentStudentRelationship::query()
            ->where('parent_id', $parent->id)
            ->where('student_id', $student->id)
            ->count());
        $this->assertSame(1, ParentStudentRelationship::query()
            ->where('parent_id', $parent->id)
            ->where('student_id', $student->id)
            ->whereNull('ended_at')
            ->count());
    }

    public function test_connect_supports_many_to_many_and_rejects_wrong_role_or_cross_tenant_targets_privately(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $parent = User::factory()->parent($institution)->create();
        $secondParent = User::factory()->parent($institution)->create();
        $student = User::factory()->student($institution)->create();
        $secondStudent = User::factory()->student($institution)->create();

        $this->connect($actor, $parent, $student)->assertCreated();
        $this->connect($actor, $parent, $secondStudent)->assertCreated();
        $this->connect($actor, $secondParent, $student)->assertCreated();
        $this->assertSame(2, ParentStudentRelationship::query()->where('parent_id', $parent->id)->whereNull('ended_at')->count());
        $this->assertSame(2, ParentStudentRelationship::query()->where('student_id', $student->id)->whereNull('ended_at')->count());

        $teacher = User::factory()->teacher($institution)->create();
        $admin = $this->institutionAdmin($institution);
        $foreignParent = User::factory()->parent($foreignInstitution)->create();
        $foreignStudent = User::factory()->student($foreignInstitution)->create();
        $notFoundPayloads = [];
        foreach ([
            ['parent_id' => '11111111-1111-4111-8111-111111111111', 'student_id' => $secondStudent->id],
            ['parent_id' => $teacher->id, 'student_id' => $secondStudent->id],
            ['parent_id' => $foreignParent->id, 'student_id' => $secondStudent->id],
            ['parent_id' => $secondParent->id, 'student_id' => $parent->id],
            ['parent_id' => $secondParent->id, 'student_id' => $admin->id],
            ['parent_id' => $secondParent->id, 'student_id' => $foreignStudent->id],
        ] as $payload) {
            $response = $this->jsonRequestAs($actor, 'POST', self::BASE_URI, $payload);
            $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $notFoundPayloads[] = $response->json();
        }
        foreach ($notFoundPayloads as $payload) {
            $this->assertSame($notFoundPayloads[0], $payload);
        }
        $this->assertDatabaseCount('parent_student_relationships', 3);
    }

    public function test_mutation_transport_relationship_privacy_and_request_shapes_are_strict(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $parent = User::factory()->parent($institution)->create();
        $student = User::factory()->student($institution)->create();
        $foreignParent = User::factory()->parent($foreignInstitution)->create();
        $foreignStudent = User::factory()->student($foreignInstitution)->create();
        $foreignRelationship = $this->relationship($foreignInstitution, $foreignParent, $foreignStudent, $foreignActor);

        foreach ([
            ['', 'application/json'],
            ['{bad', 'application/json'],
            ['[]', 'application/json'],
            ['1', 'application/json'],
            [json_encode(['parent_id' => $parent->id, 'student_id' => $student->id], JSON_THROW_ON_ERROR), 'text/plain'],
            [json_encode([], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['parent_id' => null, 'student_id' => $student->id], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['parent_id' => 'invalid', 'student_id' => $student->id], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['parent_id' => $parent->id], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['parent_id' => $parent->id, 'student_id' => $student->id, 'institution_id' => $institution->id], JSON_THROW_ON_ERROR), 'application/json'],
            [json_encode(['parent_id' => $parent->id, 'student_id' => $student->id, 'connected_by_user_id' => $actor->id], JSON_THROW_ON_ERROR), 'application/json'],
        ] as [$content, $contentType]) {
            $this->requestAs($actor, 'POST', self::BASE_URI, $content, contentType: $contentType)
                ->assertUnprocessable()
                ->assertJsonPath('code', 'validation_failed');
        }
        $this->jsonRequestAs(
            $actor,
            'POST',
            self::BASE_URI.'?unknown=1',
            ['parent_id' => $parent->id, 'student_id' => $student->id],
        )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseCount('parent_student_relationships', 1);

        foreach (['invalid', '33333333-3333-4333-8333-333333333333', $foreignRelationship->id] as $relationshipId) {
            $this->requestAs($actor, 'DELETE', self::BASE_URI.'/'.$relationshipId)
                ->assertNotFound()
                ->assertJsonPath('code', 'resource_not_found');
        }
        $localRelationship = $this->relationship($institution, $parent, $student, $actor);
        $this->requestAs($actor, 'DELETE', self::BASE_URI.'/'.$localRelationship->id, '{}')
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed');
        $this->requestAs($actor, 'DELETE', self::BASE_URI.'/'.$localRelationship->id.'?unknown=1')
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed');
        $this->assertNull($localRelationship->refresh()->ended_at);
    }

    public function test_mutation_endpoints_enforce_authentication_role_account_institution_and_password_gates(): void
    {
        $institution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $parent = User::factory()->parent($institution)->create();
        $student = User::factory()->student($institution)->create();
        $relationship = $this->relationship($institution, $parent, $student, $actor);
        $connectBody = json_encode(['parent_id' => $parent->id, 'student_id' => $student->id], JSON_THROW_ON_ERROR);
        $operations = [
            ['POST', self::BASE_URI, $connectBody],
            ['DELETE', self::BASE_URI.'/'.$relationship->id, ''],
        ];

        foreach ($operations as [$method, $uri, $content]) {
            $this->rawRequest($method, $uri, content: $content)
                ->assertUnauthorized()
                ->assertJsonPath('code', 'authentication_required');
            $this->requestAs(
                $this->institutionAdmin($institution, ['is_active' => false]),
                $method,
                $uri,
                $content,
            )->assertForbidden()->assertJsonPath('code', 'user_inactive');
            $this->requestAs(
                $this->institutionAdmin($institution, ['must_change_password' => true]),
                $method,
                $uri,
                $content,
            )->assertForbidden()->assertJsonPath('code', 'password_change_required');
            $inactiveInstitution = Institution::factory()->inactive()->create();
            $this->requestAs($this->institutionAdmin($inactiveInstitution), $method, $uri, $content)
                ->assertForbidden()
                ->assertJsonPath('code', 'institution_inactive');

            foreach ([UserRole::PlatformOwner, UserRole::Teacher, UserRole::Student, UserRole::Parent] as $role) {
                $this->requestAs($this->userForRole($role, $institution), $method, $uri, $content)
                    ->assertForbidden()
                    ->assertJsonPath('code', 'forbidden');
            }
        }
        $this->assertNull($relationship->refresh()->ended_at);
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

    private function connect(User $actor, User $parent, User $student): TestResponse
    {
        return $this->jsonRequestAs($actor, 'POST', self::BASE_URI, [
            'parent_id' => $parent->id,
            'student_id' => $student->id,
        ]);
    }

    private function relationship(
        Institution $institution,
        User $parent,
        User $student,
        User $actor,
    ): ParentStudentRelationship {
        return ParentStudentRelationship::factory()->create([
            'institution_id' => $institution->id,
            'parent_id' => $parent->id,
            'student_id' => $student->id,
            'connected_by_user_id' => $actor->id,
        ]);
    }

    /** @return array<string, string|null> */
    private function timestamps(ParentStudentRelationship $relationship): array
    {
        return [
            'started_at' => $relationship->started_at?->toJSON(),
            'ended_at' => $relationship->ended_at?->toJSON(),
            'created_at' => $relationship->created_at?->toJSON(),
            'updated_at' => $relationship->updated_at?->toJSON(),
        ];
    }

    /** @param array<string, mixed> $payload */
    private function jsonRequestAs(User $actor, string $method, string $uri, array $payload): TestResponse
    {
        return $this->requestAs(
            $actor,
            $method,
            $uri,
            json_encode($payload, JSON_THROW_ON_ERROR),
        );
    }

    private function requestAs(
        User $actor,
        string $method,
        string $uri,
        string $content = '',
        string $contentType = 'application/json',
    ): TestResponse {
        $token = $actor->createToken('institution-parent-student-relationship-api-test')->plainTextToken;
        $response = $this->rawRequest($method, $uri, $token, $content, $contentType);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function rawRequest(
        string $method,
        string $uri,
        ?string $token = null,
        string $content = '',
        string $contentType = 'application/json',
    ): TestResponse {
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json'];

        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call($method, $uri, [], [], [], $server, $content);
    }
}
