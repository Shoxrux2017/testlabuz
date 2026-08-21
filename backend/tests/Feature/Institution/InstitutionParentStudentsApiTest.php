<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ListInstitutionParentStudents;
use App\Http\Resources\Institution\InstitutionParentStudentRelationshipResource;
use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class InstitutionParentStudentsApiTest extends TestCase
{
    use RefreshDatabase;

    private const RESOURCE_KEYS = ['id', 'parent_id', 'student_id', 'started_at', 'ended_at'];

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_parent_student_routes_are_exact_and_use_institution_admin_middleware(): void
    {
        $expectedUris = [
            'api/v1/institution/parents/{parent}/students',
            'api/v1/institution/students/{student}/parents',
            'api/v1/institution/parent-student-relationships',
            'api/v1/institution/parent-student-relationships/{relationship}',
        ];
        $routes = collect(Route::getRoutes())
            ->filter(fn ($route): bool => in_array($route->uri(), $expectedUris, true))
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->values()
            ->all();
        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:institution_admin'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => $expectedUris[0], 'middleware' => $middleware],
            ['methods' => ['GET'], 'uri' => $expectedUris[1], 'middleware' => $middleware],
            ['methods' => ['POST'], 'uri' => $expectedUris[2], 'middleware' => $middleware],
            ['methods' => ['DELETE'], 'uri' => $expectedUris[3], 'middleware' => $middleware],
        ], $routes);
        $this->assertFalse(collect(Route::getRoutes())->contains(
            fn ($route): bool => str_contains($route->uri(), 'parent-student-connections'),
        ));
    }

    public function test_parent_students_list_is_current_tenant_scoped_literal_filtered_sorted_paginated_and_query_bounded(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $parent = User::factory()->parent($institution)->inactive()->create();
        $otherParent = User::factory()->parent($institution)->create();
        $first = User::factory()->student($institution)->create([
            'full_name' => 'beta Same',
            'login_name' => 'student_literal_%_!',
            'email' => null,
            'phone' => null,
        ]);
        $second = User::factory()->student($institution)->inactive()->create([
            'full_name' => 'Beta Same',
            'email' => 'matched@example.uz',
        ]);
        $endedStudent = User::factory()->student($institution)->create();
        $unrelatedStudent = User::factory()->student($institution)->create();
        $foreignParent = User::factory()->parent($foreignInstitution)->create();
        $foreignStudent = User::factory()->student($foreignInstitution)->create();
        $firstRelationship = $this->relationship($institution, $parent, $first, $actor, [
            'id' => '30000000-0000-4000-8000-000000000001',
            'started_at' => CarbonImmutable::parse('2026-08-19 10:00:00', 'UTC'),
        ]);
        $secondRelationship = $this->relationship($institution, $parent, $second, $actor, [
            'id' => '30000000-0000-4000-8000-000000000002',
            'started_at' => CarbonImmutable::parse('2026-08-19 11:00:00', 'UTC'),
        ]);
        $this->relationship($institution, $parent, $endedStudent, $actor, [
            'started_at' => CarbonImmutable::parse('2026-08-18 10:00:00', 'UTC'),
            'ended_at' => CarbonImmutable::parse('2026-08-18 12:00:00', 'UTC'),
        ]);
        $this->relationship($institution, $otherParent, $unrelatedStudent, $actor);
        $this->relationship($foreignInstitution, $foreignParent, $foreignStudent, $foreignActor);

        $default = $this->requestAs($actor, 'GET', $this->uri($parent));
        $default->assertOk();
        $this->assertSame([$firstRelationship->id, $secondRelationship->id], $this->ids($default));
        $this->assertSame(
            ['page' => 1, 'per_page' => 20, 'total' => 2, 'last_page' => 1],
            $default->json('meta.pagination'),
        );
        $this->assertRelationshipResource($default->json('data.0'));
        $this->assertSame($parent->id, $default->json('data.0.parent_id'));
        $this->assertSame($first->id, $default->json('data.0.student_id'));
        $this->assertSame('2026-08-19T10:00:00Z', $default->json('data.0.started_at'));
        $this->assertNull($default->json('data.0.ended_at'));

        $this->assertSame([$firstRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($parent),
            query: ['status' => 'active'],
        )));
        $this->assertSame([$secondRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($parent),
            query: ['status' => 'inactive'],
        )));
        $this->assertSame([$firstRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($parent),
            query: ['search' => '  %_!  '],
        )));
        $this->assertSame([$secondRelationship->id, $firstRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($parent),
            query: ['sort' => 'started_at', 'direction' => 'desc'],
        )));
        $page = $this->requestAs($actor, 'GET', $this->uri($parent), query: ['page' => 2, 'per_page' => 1]);
        $this->assertSame([$secondRelationship->id], $this->ids($page));
        $this->assertSame(
            ['page' => 2, 'per_page' => 1, 'total' => 2, 'last_page' => 2],
            $page->json('meta.pagination'),
        );
        $this->requestAs($actor, 'GET', $this->uri(User::factory()->parent($institution)->create()))
            ->assertOk()
            ->assertExactJson([
                'data' => [],
                'meta' => ['pagination' => ['page' => 1, 'per_page' => 20, 'total' => 0, 'last_page' => 1]],
            ]);

        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $paginator = app(ListInstitutionParentStudents::class)(
                actor: $actor,
                parent: $parent->id,
                search: 'beta',
                isActive: null,
                sort: 'full_name',
                direction: 'asc',
                page: 1,
                perPage: 20,
            );
            foreach ($paginator->items() as $relationship) {
                (new InstitutionParentStudentRelationshipResource($relationship))->toArray(Request::create('/'));
            }
            $queries = DB::getQueryLog();
        } finally {
            DB::disableQueryLog();
        }

        $this->assertCount(3, $queries);
        $listSql = strtolower($queries[2]['query']);
        $this->assertStringContainsString('parent_student_relationships', $listSql);
        $this->assertStringContainsString('inner join "users" as "students"', $listSql);
        $this->assertStringContainsString("ilike ? escape '!'", $listSql);
        $this->assertStringContainsString(
            'order by lower(students.full_name) asc, "parent_student_relationships"."id" asc',
            $listSql,
        );
        $this->assertStringNotContainsString('select *', $listSql);
    }

    public function test_parent_path_resolution_and_list_input_are_strict_and_existence_private(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $validParent = User::factory()->parent($institution)->create();
        $wrongRole = User::factory()->student($institution)->create();
        $foreignParent = User::factory()->parent($foreignInstitution)->create();
        $notFound = [];

        foreach (['invalid', '11111111-1111-4111-8111-111111111111', $wrongRole->id, $foreignParent->id] as $parentId) {
            $response = $this->requestAs($actor, 'GET', '/api/v1/institution/parents/'.$parentId.'/students');
            $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $notFound[] = $response->json();
        }
        $this->assertSame($notFound[0], $notFound[1]);
        $this->assertSame($notFound[1], $notFound[2]);
        $this->assertSame($notFound[2], $notFound[3]);

        foreach ([
            ['query' => ['unknown' => '1'], 'content' => ''],
            ['query' => ['status' => 'ACTIVE'], 'content' => ''],
            ['query' => ['page' => 0], 'content' => ''],
            ['query' => ['per_page' => 101], 'content' => ''],
            ['query' => ['sort' => 'id'], 'content' => ''],
            ['query' => ['direction' => 'sideways'], 'content' => ''],
            ['query' => [], 'content' => '{}'],
        ] as $case) {
            $this->requestAs($actor, 'GET', $this->uri($validParent), $case['content'], $case['query'])
                ->assertUnprocessable()
                ->assertJsonPath('code', 'validation_failed');
        }
        $this->requestAs($actor, 'GET', $this->uri($validParent), query: ['search' => '   '])
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    private function institutionAdmin(Institution $institution): User
    {
        return User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    }

    private function relationship(
        Institution $institution,
        User $parent,
        User $student,
        User $actor,
        array $attributes = [],
    ): ParentStudentRelationship {
        return ParentStudentRelationship::factory()->create(array_merge([
            'institution_id' => $institution->id,
            'parent_id' => $parent->id,
            'student_id' => $student->id,
            'connected_by_user_id' => $actor->id,
        ], $attributes));
    }

    private function uri(User $parent): string
    {
        return '/api/v1/institution/parents/'.$parent->id.'/students';
    }

    /** @param array<string, mixed> $query */
    private function requestAs(
        User $actor,
        string $method,
        string $uri,
        string $content = '',
        array $query = [],
    ): TestResponse {
        $token = $actor->createToken('institution-parent-students-api-test')->plainTextToken;
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $response = $this->call($method, $requestUri, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$token,
        ], $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @return list<string> */
    private function ids(TestResponse $response): array
    {
        return collect($response->json('data'))->pluck('id')->all();
    }

    /** @param array<string, mixed> $resource */
    private function assertRelationshipResource(array $resource): void
    {
        $this->assertSame(self::RESOURCE_KEYS, array_keys($resource));
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $resource['started_at']);

        foreach (['institution_id', 'connected_by_user_id', 'created_at', 'updated_at', 'full_name', 'password'] as $protected) {
            $this->assertArrayNotHasKey($protected, $resource);
        }
    }
}
