<?php

namespace Tests\Feature\Teacher;

use App\Enums\UserRole;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class TeacherAssignedGroupApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/teacher/groups';

    public function test_teacher_group_route_is_registered_once_with_exact_middleware_order(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/teacher/groups')
            ->values()
            ->all();

        $this->assertSame([[
            'methods' => ['GET'],
            'uri' => 'api/v1/teacher/groups',
            'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'],
        ]], $routes);
    }

    public function test_list_returns_only_current_assigned_active_same_institution_groups_with_exact_resources(): void
    {
        $institution = Institution::factory()->create();
        $foreignInstitution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $assigner = $this->admin($institution);
        $foreignAssigner = $this->admin($foreignInstitution);

        $first = $this->group($institution, $assigner, [
            'id' => '00000000-0000-0000-0000-000000000001',
            'name' => '9-A',
            'level' => 'Grade 9',
            'subject_direction' => 'Informatics',
        ]);
        $second = $this->group($institution, $assigner, [
            'id' => '00000000-0000-0000-0000-000000000002',
            'name' => '10-B',
            'level' => null,
            'subject_direction' => null,
        ]);
        $ended = $this->group($institution, $assigner, ['name' => 'Ended']);
        $archived = $this->group($institution, $assigner, ['name' => 'Archived'], archived: true);
        $unrelated = $this->group($institution, $assigner, ['name' => 'Unrelated']);
        $foreign = $this->group($foreignInstitution, $foreignAssigner, ['name' => 'Foreign']);

        $this->membership($institution, $first, $teacher, $assigner);
        $this->membership($institution, $second, $teacher, $assigner);
        $this->membership($institution, $ended, $teacher, $assigner, ended: true);
        $this->membership($institution, $archived, $teacher, $assigner);
        $response = $this->requestAs($teacher, self::URI);

        $response->assertOk();
        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertSame([$second->id, $first->id], collect($response->json('data'))->pluck('id')->all());
        $this->assertSame([
            'page' => 1,
            'per_page' => 20,
            'total' => 2,
            'last_page' => 1,
        ], $response->json('meta.pagination'));

        foreach ($response->json('data') as $resource) {
            $this->assertSame(['id', 'name', 'level', 'subject_direction', 'status'], array_keys($resource));
            $this->assertSame('active', $resource['status']);
        }

        foreach (['institution_id', 'description', 'created_by_user_id', 'teachers_count', 'students_count', 'membership', $ended->id, $archived->id, $unrelated->id, $foreign->id] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public function test_list_search_sort_ties_and_pagination_are_literal_and_deterministic(): void
    {
        $institution = Institution::factory()->create();
        $teacher = $this->teacher($institution);
        $assigner = $this->admin($institution);

        $groups = [
            $this->group($institution, $assigner, [
                'id' => '00000000-0000-0000-0000-000000000003',
                'name' => 'same',
                'level' => 'Grade_10%',
                'subject_direction' => 'General',
            ]),
            $this->group($institution, $assigner, [
                'id' => '00000000-0000-0000-0000-000000000001',
                'name' => 'Same',
                'level' => 'Plain',
                'subject_direction' => 'Science_One',
            ]),
            $this->group($institution, $assigner, [
                'id' => '00000000-0000-0000-0000-000000000002',
                'name' => 'Zulu Percent%',
                'level' => null,
                'subject_direction' => null,
            ]),
        ];

        foreach ($groups as $group) {
            $this->membership($institution, $group, $teacher, $assigner);
        }

        $this->assertSame([$groups[1]->id, $groups[0]->id, $groups[2]->id], $this->ids($this->requestAs($teacher, self::URI)));
        $this->assertSame([$groups[2]->id, $groups[0]->id, $groups[1]->id], $this->ids($this->requestAs($teacher, self::URI, ['sort' => 'name', 'direction' => 'desc'])));
        $this->assertSame([$groups[0]->id, $groups[1]->id, $groups[2]->id], $this->ids($this->requestAs($teacher, self::URI, ['sort' => 'level'])));
        $this->assertSame([$groups[0]->id, $groups[1]->id, $groups[2]->id], $this->ids($this->requestAs($teacher, self::URI, ['sort' => 'subject_direction'])));
        $this->assertSame([$groups[1]->id], $this->ids($this->requestAs($teacher, self::URI, ['search' => 'science_one'])));
        $this->assertSame([$groups[0]->id], $this->ids($this->requestAs($teacher, self::URI, ['search' => '_10%'])));
        $this->assertSame([$groups[0]->id, $groups[2]->id], $this->ids($this->requestAs($teacher, self::URI, ['search' => '%'])));
        $this->assertSame(3, $this->requestAs($teacher, self::URI, ['search' => '   '])->json('meta.pagination.total'));

        $page = $this->requestAs($teacher, self::URI, ['page' => 2, 'per_page' => 2]);
        $this->assertSame([$groups[2]->id], $this->ids($page));
        $this->assertSame(['page' => 2, 'per_page' => 2, 'total' => 3, 'last_page' => 2], $page->json('meta.pagination'));
    }

    public function test_list_rejects_unknown_invalid_query_and_any_body(): void
    {
        $institution = Institution::factory()->create();
        $teacher = $this->teacher($institution);

        foreach ([
            ['unknown' => 'x'],
            ['page' => 0],
            ['per_page' => 101],
            ['sort' => 'status'],
            ['direction' => 'sideways'],
            ['search' => str_repeat('a', 255)],
        ] as $query) {
            $this->requestAs($teacher, self::URI, $query)
                ->assertUnprocessable()
                ->assertJsonPath('code', 'validation_failed');
        }

        $this->rawRequest($teacher, self::URI, [], '{}')
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed');
    }

    public function test_list_enforces_authentication_role_account_institution_and_password_middleware(): void
    {
        $institution = Institution::factory()->create();

        $this->getJson(self::URI)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');

        $this->requestAs($this->teacher($institution, ['is_active' => false]), self::URI)
            ->assertForbidden()->assertJsonPath('code', 'user_inactive');
        $this->requestAs($this->teacher($institution, ['must_change_password' => true]), self::URI)
            ->assertForbidden()->assertJsonPath('code', 'password_change_required');

        $inactiveInstitution = Institution::factory()->inactive()->create();
        $this->requestAs($this->teacher($inactiveInstitution), self::URI)
            ->assertForbidden()->assertJsonPath('code', 'institution_inactive');

        foreach ([UserRole::PlatformOwner, UserRole::InstitutionAdmin, UserRole::Student, UserRole::Parent] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);

            $this->requestAs($actor, self::URI)->assertForbidden()->assertJsonPath('code', 'forbidden');
        }
    }

    private function teacher(Institution $institution, array $attributes = []): User
    {
        return User::factory()->teacher($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    private function admin(Institution $institution): User
    {
        return User::factory()->institutionAdmin($institution)->create(['must_change_password' => false]);
    }

    private function group(Institution $institution, User $assigner, array $attributes = [], bool $archived = false): Group
    {
        $factory = $archived ? Group::factory()->archived() : Group::factory();

        return $factory->create(array_merge([
            'institution_id' => $institution->id,
            'created_by_user_id' => $assigner->id,
        ], $attributes));
    }

    private function membership(
        Institution $institution,
        Group $group,
        User $teacher,
        User $assigner,
        bool $ended = false,
    ): GroupTeacherMembership {
        $factory = $ended ? GroupTeacherMembership::factory()->ended() : GroupTeacherMembership::factory();

        return $factory->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
            'assigned_by_user_id' => $assigner->id,
        ]);
    }

    /** @param array<string, mixed> $query */
    private function requestAs(User $actor, string $uri, array $query = []): TestResponse
    {
        return $this->rawRequest($actor, $uri, $query);
    }

    /** @param array<string, mixed> $query */
    private function rawRequest(?User $actor, string $uri, array $query = [], string $content = ''): TestResponse
    {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'];

        if ($actor instanceof User) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$actor->createToken('teacher-group-api-test')->plainTextToken;
        }

        $response = $this->call('GET', $requestUri, [], [], [], $server, $content);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @return list<string> */
    private function ids(TestResponse $response): array
    {
        $response->assertOk();

        return collect($response->json('data'))->pluck('id')->all();
    }
}
