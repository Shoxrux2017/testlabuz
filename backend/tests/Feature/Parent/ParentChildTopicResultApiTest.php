<?php

namespace Tests\Feature\Parent;

use App\Models\Institution;
use App\Models\ParentStudentRelationship;
use App\Models\TopicResult;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTopicResultContext;
use Tests\TestCase;

/** S10-BE-003: a Parent reads a connected child's Topic result, never before the Student (docs/09 §30.5). */
class ParentChildTopicResultApiTest extends TestCase
{
    use BuildsTopicResultContext;
    use UsesBlitzReadSnapshot;

    private User $parent;

    private User $child;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-05 10:00:00 UTC'));
        $this->topicResultContext();
        $this->child = $this->readyStudent('Alpha Student', '88', '84');
        $this->parent = $this->parentOf($this->child);
    }

    public function test_the_route_is_registered_behind_the_parent_gates(): void
    {
        $route = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/parent/children/{student}/topics/{topic}/result')->sole();

        $this->assertSame(['GET', 'HEAD'], $route->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:parent'], $route->middleware());
        $this->child->update(['must_change_password' => false]);
        $this->homeworkRaw($this->child->fresh(), 'GET', $this->uri(), '')->assertForbidden()->assertJsonPath('code', 'forbidden');
    }

    public function test_with_student_the_parent_sees_the_values_once_the_student_does(): void
    {
        $this->releaseModes('manual_teacher', 'with_student');

        $this->assertSame(['topic_id' => $this->topic->id, 'result_status' => 'calculated', 'closed_outcome' => null, 'missing_component' => null,
            'visible' => false, 'homework_score' => null, 'blitz_score' => null, 'final_score' => null, 'calculation_method' => null,
            'category' => null, 'teacher_comment' => null], $this->read()->assertOk()->json('data'));

        $this->row(['student_released_at' => now(), 'student_released_by_user_id' => $this->teacher->id,
            'teacher_comment' => 'Revise question 4.', 'teacher_comment_updated_by_user_id' => $this->teacher->id, 'teacher_comment_updated_at' => now()]);

        $this->assertSame(['topic_id' => $this->topic->id, 'result_status' => 'calculated', 'closed_outcome' => null, 'missing_component' => null,
            'visible' => true, 'homework_score' => 88, 'blitz_score' => 84, 'final_score' => 86, 'calculation_method' => 'average',
            'category' => ['code' => 'understood_well', 'label' => 'Understood well'], 'teacher_comment' => 'Revise question 4.'],
            $this->read()->assertOk()->json('data'));
    }

    public function test_with_manual_release_the_parent_waits_for_the_parent_release(): void
    {
        $row = $this->row(['student_released_at' => now(), 'student_released_by_user_id' => $this->teacher->id]);

        $this->read()->assertOk()->assertJsonPath('data.visible', false)->assertJsonPath('data.final_score', null);

        $row->update(['parent_released_at' => now(), 'parent_released_by_user_id' => $this->teacher->id]);

        $this->read()->assertOk()->assertJsonPath('data.visible', true)->assertJsonPath('data.final_score', 86);
    }

    public function test_the_parent_never_sees_values_the_student_cannot_see(): void
    {
        $this->releaseModes('automatic', 'manual_teacher');
        $this->row(['parent_released_at' => now(), 'parent_released_by_user_id' => $this->teacher->id]);
        $this->read()->assertOk()->assertJsonPath('data.visible', true);

        $this->releaseModes('manual_teacher', 'manual_teacher');

        $this->read()->assertOk()->assertJsonPath('data.visible', false)->assertJsonPath('data.homework_score', null);
    }

    public function test_hidden_and_unconfigured_parent_modes_give_no_result_information(): void
    {
        $this->row(['student_released_at' => now(), 'student_released_by_user_id' => $this->teacher->id,
            'parent_released_at' => now(), 'parent_released_by_user_id' => $this->teacher->id]);

        foreach (['hidden', null] as $mode) {
            $this->releaseModes('automatic', $mode);

            $this->read()->assertOk()->assertExactJson(['data' => null]);
        }
    }

    public function test_a_child_outside_the_cohort_has_no_result(): void
    {
        $member = $this->studentNamed('Member Student');

        $this->read($this->parentOf($member), $member)->assertOk()->assertExactJson(['data' => null]);
    }

    public function test_only_a_current_relationship_with_topic_access_reaches_the_result(): void
    {
        $ended = $this->readyStudent('Ended Child', '70', '72');
        $endedParent = User::factory()->parent($this->institution)->create(['must_change_password' => false]);
        ParentStudentRelationship::factory()->ended()->create(['institution_id' => $this->institution->id, 'parent_id' => $endedParent->id,
            'student_id' => $ended->id, 'connected_by_user_id' => $this->admin->id]);
        $stranger = User::factory()->parent($this->institution)->create(['must_change_password' => false]);
        $foreignParent = User::factory()->parent(Institution::factory()->create())->create(['must_change_password' => false]);
        $outsider = User::factory()->student($this->institution)->create();

        $this->read($endedParent, $ended)->assertNotFound();
        $this->read($stranger)->assertNotFound();
        $this->read($foreignParent)->assertNotFound();
        $this->read($this->parentOf($outsider), $outsider)->assertNotFound();
        $this->homeworkRaw($this->parent, 'GET', '/api/v1/parent/children/not-a-uuid/topics/'.$this->topic->id.'/result', '')->assertNotFound();
    }

    /** @return array<string, array{string, array<string, mixed>}> */
    public static function invalidRequests(): array
    {
        return ['body' => ['{}', []], 'query parameter' => ['', ['include' => 'all']]];
    }

    #[DataProvider('invalidRequests')]
    public function test_the_read_takes_no_body_or_query(string $body, array $query): void
    {
        $this->homeworkRaw($this->parent, 'GET', $this->uri(), $body, $query)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    private function parentOf(User $student): User
    {
        $parent = User::factory()->parent($this->institution)->create(['must_change_password' => false]);
        ParentStudentRelationship::factory()->create(['institution_id' => $this->institution->id, 'parent_id' => $parent->id,
            'student_id' => $student->id, 'connected_by_user_id' => $this->admin->id]);

        return $parent;
    }

    /** @param array<string, mixed> $attributes */
    private function row(array $attributes): TopicResult
    {
        return TopicResult::factory()->create(['institution_id' => $this->institution->id, 'topic_id' => $this->topic->id,
            'student_id' => $this->child->id, ...$attributes]);
    }

    private function read(?User $parent = null, ?User $child = null): TestResponse
    {
        return $this->homeworkRaw($parent ?? $this->parent, 'GET', $this->uri($child), '');
    }

    private function uri(?User $child = null): string
    {
        return '/api/v1/parent/children/'.($child ?? $this->child)->id.'/topics/'.$this->topic->id.'/result';
    }
}
