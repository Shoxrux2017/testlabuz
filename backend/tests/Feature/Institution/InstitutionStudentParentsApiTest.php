<?php

namespace Tests\Feature\Institution;

use App\Actions\Institution\ListInstitutionStudentParents;
use App\Http\Resources\Institution\InstitutionParentStudentRelationshipResource;
use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class InstitutionStudentParentsApiTest extends TestCase
{
    use RefreshDatabase;

    private const RESOURCE_KEYS = ['id', 'parent_id', 'student_id', 'started_at', 'ended_at'];

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    public function test_student_parents_list_reverses_roles_with_current_tenant_scope_filters_sorting_pagination_and_bounded_queries(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $foreignActor = $this->institutionAdmin($foreignInstitution);
        $student = User::factory()->student($institution)->inactive()->create();
        $otherStudent = User::factory()->student($institution)->create();
        $first = User::factory()->parent($institution)->create([
            'full_name' => 'alpha Same',
            'login_name' => 'parent_literal_%_!',
        ]);
        $second = User::factory()->parent($institution)->inactive()->create([
            'full_name' => 'Alpha Same',
            'phone' => '+998901234567',
        ]);
        $endedParent = User::factory()->parent($institution)->create();
        $foreignStudent = User::factory()->student($foreignInstitution)->create();
        $foreignParent = User::factory()->parent($foreignInstitution)->create();
        $firstRelationship = $this->relationship($institution, $first, $student, $actor, [
            'id' => '40000000-0000-4000-8000-000000000001',
            'started_at' => CarbonImmutable::parse('2026-08-19 09:00:00', 'UTC'),
        ]);
        $secondRelationship = $this->relationship($institution, $second, $student, $actor, [
            'id' => '40000000-0000-4000-8000-000000000002',
            'started_at' => CarbonImmutable::parse('2026-08-19 10:00:00', 'UTC'),
        ]);
        $this->relationship($institution, $endedParent, $student, $actor, ['ended_at' => now()]);
        $this->relationship($institution, $first, $otherStudent, $actor);
        $this->relationship($foreignInstitution, $foreignParent, $foreignStudent, $foreignActor);

        $default = $this->requestAs($actor, 'GET', $this->uri($student));
        $default->assertOk();
        $this->assertSame([$firstRelationship->id, $secondRelationship->id], $this->ids($default));
        $this->assertSame(self::RESOURCE_KEYS, array_keys($default->json('data.0')));
        $this->assertSame($first->id, $default->json('data.0.parent_id'));
        $this->assertSame($student->id, $default->json('data.0.student_id'));
        $this->assertNull($default->json('data.0.ended_at'));

        $this->assertSame([$firstRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($student),
            query: ['status' => 'active'],
        )));
        $this->assertSame([$secondRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($student),
            query: ['status' => 'inactive'],
        )));
        $this->assertSame([$firstRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($student),
            query: ['search' => '  %_!  '],
        )));
        $this->assertSame([$secondRelationship->id, $firstRelationship->id], $this->ids($this->requestAs(
            $actor,
            'GET',
            $this->uri($student),
            query: ['sort' => 'started_at', 'direction' => 'desc'],
        )));
        $page = $this->requestAs($actor, 'GET', $this->uri($student), query: ['page' => 2, 'per_page' => 1]);
        $this->assertSame([$secondRelationship->id], $this->ids($page));
        $this->assertSame(
            ['page' => 2, 'per_page' => 1, 'total' => 2, 'last_page' => 2],
            $page->json('meta.pagination'),
        );
        $this->requestAs($actor, 'GET', $this->uri(User::factory()->student($institution)->create()))
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $measureQueries = function () use ($actor, $student): array {
            DB::flushQueryLog();
            DB::enableQueryLog();
            try {
                $paginator = app(ListInstitutionStudentParents::class)(
                    actor: $actor,
                    student: $student->id,
                    search: 'alpha',
                    isActive: null,
                    sort: 'full_name',
                    direction: 'asc',
                    page: 1,
                    perPage: 100,
                );
                foreach ($paginator->items() as $relationship) {
                    (new InstitutionParentStudentRelationshipResource($relationship))->toArray(Request::create('/'));
                }

                return ['queries' => DB::getQueryLog(), 'item_count' => count($paginator->items())];
            } finally {
                DB::disableQueryLog();
            }
        };

        $smallMeasurement = $measureQueries();
        $this->assertSame(2, $smallMeasurement['item_count']);

        for ($index = 0; $index < 20; $index++) {
            $additionalParent = User::factory()->parent($institution)->create([
                'full_name' => 'alpha Growth '.$index,
            ]);
            $this->relationship($institution, $additionalParent, $student, $actor);
        }

        $largeMeasurement = $measureQueries();
        $this->assertSame(22, $largeMeasurement['item_count']);
        $this->assertCount(3, $smallMeasurement['queries']);
        $this->assertSame(count($smallMeasurement['queries']), count($largeMeasurement['queries']));
        $this->assertCount(3, $largeMeasurement['queries']);
        $listSql = strtolower($largeMeasurement['queries'][2]['query']);
        $this->assertStringContainsString('inner join "users" as "parents"', $listSql);
        $this->assertStringContainsString("ilike ? escape '!'", $listSql);
        $this->assertStringContainsString(
            'order by lower(parents.full_name) asc, "parent_student_relationships"."id" asc',
            $listSql,
        );
        $this->assertStringNotContainsString('select *', $listSql);
    }

    public function test_student_path_resolution_and_list_input_are_strict_and_existence_private(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $actor = $this->institutionAdmin($institution);
        $validStudent = User::factory()->student($institution)->create();
        $wrongRole = User::factory()->parent($institution)->create();
        $foreignStudent = User::factory()->student($foreignInstitution)->create();
        $notFound = [];

        foreach (['invalid', '22222222-2222-4222-8222-222222222222', $wrongRole->id, $foreignStudent->id] as $studentId) {
            $response = $this->requestAs($actor, 'GET', '/api/v1/institution/students/'.$studentId.'/parents');
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
            $this->requestAs($actor, 'GET', $this->uri($validStudent), $case['content'], $case['query'])
                ->assertUnprocessable()
                ->assertJsonPath('code', 'validation_failed');
        }
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

    private function uri(User $student): string
    {
        return '/api/v1/institution/students/'.$student->id.'/parents';
    }

    /** @param array<string, mixed> $query */
    private function requestAs(
        User $actor,
        string $method,
        string $uri,
        string $content = '',
        array $query = [],
    ): TestResponse {
        $token = $actor->createToken('institution-student-parents-api-test')->plainTextToken;
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
}
