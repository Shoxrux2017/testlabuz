<?php

namespace Tests\Feature\Student;

use App\Models\GroupStudentMembership;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\TopicResult;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTopicResultContext;
use Tests\TestCase;

/** S10-BE-003: the Student's own Topic result with values only when visible (docs/09 §29.3, §29.5). */
class StudentTopicResultApiTest extends TestCase
{
    use BuildsTopicResultContext;
    use UsesBlitzReadSnapshot;

    private const HIDDEN_VALUES = [
        'visible' => false, 'homework_score' => null, 'blitz_score' => null, 'final_score' => null,
        'calculation_method' => null, 'category' => null, 'teacher_comment' => null,
    ];

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-05 10:00:00 UTC'));
        $this->topicResultContext();
    }

    public function test_the_route_is_registered_behind_the_student_gates(): void
    {
        $route = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/student/topics/{topic}/result')->sole();

        $this->assertSame(['GET', 'HEAD'], $route->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'], $route->middleware());
    }

    public function test_a_released_result_shows_exactly_its_student_values(): void
    {
        $student = $this->student($this->readyStudent('Alpha Student', '88', '84'));
        $this->topicResult($student)->update(['teacher_comment' => 'Revise question 4.', 'teacher_comment_updated_by_user_id' => $this->teacher->id,
            'teacher_comment_updated_at' => now(), 'student_released_at' => now(), 'student_released_by_user_id' => $this->teacher->id]);

        $this->assertSame(['data' => [
            'topic_id' => $this->topic->id, 'result_status' => 'calculated', 'closed_outcome' => null, 'missing_component' => null,
            'visible' => true, 'homework_score' => 88, 'blitz_score' => 84, 'final_score' => 86, 'calculation_method' => 'average',
            'category' => ['code' => 'understood_well', 'label' => 'Understood well'], 'teacher_comment' => 'Revise question 4.',
        ]], $this->read($student)->assertOk()->json());
    }

    public function test_an_unreleased_result_hides_every_value_but_keeps_its_status(): void
    {
        $student = $this->student($this->readyStudent('Alpha Student', '88', '84'));
        $this->topicResult($student)->update(['teacher_comment' => 'Revise question 4.', 'teacher_comment_updated_by_user_id' => $this->teacher->id,
            'teacher_comment_updated_at' => now()]);

        $this->assertSame(['topic_id' => $this->topic->id, 'result_status' => 'calculated', 'closed_outcome' => null,
            'missing_component' => null, ...self::HIDDEN_VALUES], $this->read($student)->assertOk()->json('data'));
        $this->assertStringNotContainsString('Revise question 4.', $this->read($student)->getContent());
    }

    public function test_automatic_release_still_waits_for_the_window_and_the_outcome(): void
    {
        $this->releaseModes('automatic', 'with_student');
        $waiting = $this->student($this->cohortStudent('Alpha Student'));
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');
        $ready = $this->student($this->readyStudent('Beta Student', '88', '84'));

        $this->read($waiting)->assertOk()->assertJsonPath('data.result_status', 'waiting_for_teacher_review')->assertJsonPath('data.visible', false);
        $this->read($ready)->assertOk()->assertJsonPath('data.visible', true)->assertJsonPath('data.final_score', 86);

        // The Homework can still be submitted, so the window is not open.
        $this->homework->homeworkAssignment->update(['status' => 'active', 'closed_at' => null, 'deadline_at' => null]);

        $this->assertSame(['result_status' => 'calculated', ...self::HIDDEN_VALUES],
            array_intersect_key($this->read($ready)->assertOk()->json('data'), ['result_status' => true] + self::HIDDEN_VALUES));
    }

    public function test_a_not_completed_result_shows_the_ready_side_and_the_not_completed_category(): void
    {
        $this->releaseModes('automatic', 'with_student');
        $student = $this->student($this->cohortStudent('Alpha Student'));
        $this->officialAttempt($this->homework, $student, '80.00000000');

        $this->assertSame([
            'topic_id' => $this->topic->id, 'result_status' => 'not_completed', 'closed_outcome' => null, 'missing_component' => 'blitz',
            'visible' => true, 'homework_score' => 80, 'blitz_score' => null, 'final_score' => null, 'calculation_method' => null,
            'category' => ['code' => 'not_completed', 'label' => 'Not completed'], 'teacher_comment' => null,
        ], $this->read($student)->assertOk()->json('data'));
    }

    public function test_a_closed_result_shows_its_snapshot_once_released(): void
    {
        $student = $this->student($this->readyStudent('Alpha Student', '88', '84'));
        $this->closedRow($student, ['student_released_at' => now(), 'student_released_by_user_id' => $this->teacher->id]);

        $data = $this->read($student)->assertOk()->json('data');

        $this->assertSame(['closed', 'calculated', true, 86, 'understood_well'],
            [$data['result_status'], $data['closed_outcome'], $data['visible'], $data['final_score'], $data['category']['code']]);
        foreach (['consistency', 'score_difference', 'acceptable_difference', 'category_score'] as $hidden) {
            $this->assertArrayNotHasKey($hidden, $data);
        }
    }

    public function test_a_former_member_still_in_the_cohort_reads_the_result(): void
    {
        $student = $this->student($this->readyStudent('Alpha Student', '88', '84'));
        GroupStudentMembership::query()->where('student_id', $student->id)->update(['ended_at' => now()]);

        $this->read($student)->assertOk()->assertJsonPath('data.result_status', 'calculated');
    }

    public function test_a_member_outside_the_cohort_gets_no_result(): void
    {
        $member = $this->student($this->studentNamed('Member Student'));

        $this->read($member)->assertOk()->assertExactJson(['data' => null]);
    }

    public function test_topics_out_of_the_students_reach_are_not_found(): void
    {
        $outsider = $this->student(User::factory()->student($this->institution)->create());
        $foreign = $this->student(User::factory()->student(Institution::factory()->create())->create());
        $member = $this->student($this->readyStudent('Alpha Student', '88', '84'));
        $draft = Topic::factory()->create(['institution_id' => $this->institution->id, 'group_id' => $this->group->id,
            'teacher_id' => $this->teacher->id]);

        $this->read($outsider)->assertNotFound();
        $this->read($foreign)->assertNotFound();
        $this->read($member, $draft->id)->assertNotFound();
        $this->read($member, 'not-a-uuid')->assertNotFound();
    }

    /** @return array<string, array{string, array<string, mixed>}> */
    public static function invalidRequests(): array
    {
        return ['body' => ['{}', []], 'query parameter' => ['', ['include' => 'all']]];
    }

    #[DataProvider('invalidRequests')]
    public function test_the_read_takes_no_body_or_query(string $body, array $query): void
    {
        $student = $this->student($this->readyStudent('Alpha Student', '88', '84'));

        $this->homeworkRaw($student, 'GET', '/api/v1/student/topics/'.$this->topic->id.'/result', $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_the_topic_detail_carries_the_students_result_status(): void
    {
        $student = $this->student($this->readyStudent('Alpha Student', '88', '84'));
        $member = $this->student($this->studentNamed('Member Student'));
        $detail = fn (User $reader): TestResponse => $this->homeworkRaw($reader, 'GET', '/api/v1/student/topics/'.$this->topic->id, '')->assertOk();

        $detail($student)->assertJsonPath('data.result_status', 'calculated');
        $this->closedRow($student, []);
        $detail($student)->assertJsonPath('data.result_status', 'closed');
        $this->assertNull($detail($member)->json('data.result_status'));
        $this->assertArrayHasKey('result_status', $detail($member)->json('data'));
    }

    private function student(User $student): User
    {
        $student->update(['must_change_password' => false]);

        return $student;
    }

    private function topicResult(User $student): TopicResult
    {
        return TopicResult::factory()->create(['institution_id' => $this->institution->id, 'topic_id' => $this->topic->id, 'student_id' => $student->id]);
    }

    private function read(User $student, ?string $topicId = null): TestResponse
    {
        return $this->homeworkRaw($student, 'GET', '/api/v1/student/topics/'.($topicId ?? $this->topic->id).'/result', '');
    }
}
