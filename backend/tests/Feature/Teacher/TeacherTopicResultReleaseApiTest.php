<?php

namespace Tests\Feature\Teacher;

use App\Models\TopicResult;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTopicResultContext;
use Tests\TestCase;

/** S10-BE-003: Teacher release of Topic results to Students and Parents, single and bulk (docs/09 §27.3-27.5). */
class TeacherTopicResultReleaseApiTest extends TestCase
{
    use BuildsTopicResultContext;
    use UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-05 10:00:00 UTC'));
        $this->topicResultContext();
    }

    public function test_the_release_routes_are_registered_behind_the_teacher_gates(): void
    {
        foreach ([
            'api/v1/teacher/topics/{topic}/results/{student}/release/student',
            'api/v1/teacher/topics/{topic}/results/{student}/release/parent',
            'api/v1/teacher/topics/{topic}/results/release/student',
            'api/v1/teacher/topics/{topic}/results/release/parent',
        ] as $uri) {
            $route = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === $uri)->sole();
            $this->assertSame(['POST'], $route->methods());
            $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'], $route->middleware());
        }
    }

    public function test_a_student_release_needs_the_manual_mode(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->releaseModes('automatic', 'with_student');

        $this->release($student, 'student')->assertConflict()->assertJsonPath('code', 'manual_release_not_allowed');
        $this->releaseModes(null, null);
        $this->release($student, 'student')->assertConflict()->assertJsonPath('code', 'manual_release_not_allowed');
        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_a_waiting_result_or_unfinished_work_is_not_ready_for_release(): void
    {
        $waiting = $this->cohortStudent('Alpha Student');
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');

        $this->release($waiting, 'student')->assertConflict()->assertJsonPath('code', 'result_not_ready');
        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_a_calculated_result_is_not_ready_while_the_homework_can_still_be_submitted(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->homework->homeworkAssignment->update(['status' => 'active', 'closed_at' => null, 'deadline_at' => null]);

        $this->release($student, 'student')->assertConflict()->assertJsonPath('code', 'result_not_ready');
        $this->bulk('student')->assertOk()->assertJsonPath('data', ['processed' => 0, 'skipped' => ['already_done' => 0, 'not_ready' => 1]]);
        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_a_student_release_records_the_teacher_and_time_and_is_idempotent(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $this->release($student, 'student')->assertOk()
            ->assertJsonPath('message', 'Topic result released to the Student.')
            ->assertJsonPath('data.visibility.student_visible', true)
            ->assertJsonPath('data.visibility.student_released_at', '2026-10-05T10:00:00Z')
            ->assertJsonPath('data.visibility.can_release_to_student', false)
            ->assertJsonPath('data.student_released_by.id', $this->teacher->id);

        $this->travelTo(now()->addHour());

        $this->release($student, 'student')->assertOk()->assertJsonPath('data.visibility.student_released_at', '2026-10-05T10:00:00Z');
        $this->assertSame(1, TopicResult::query()->count());
    }

    public function test_a_closed_result_is_released_like_any_other(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->closedRow($student, []);

        $this->release($student, 'student')->assertOk()
            ->assertJsonPath('data.result_status', 'closed')
            ->assertJsonPath('data.visibility.student_visible', true);
    }

    public function test_a_parent_release_needs_the_manual_parent_mode_and_a_result_the_student_sees(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $this->release($student, 'parent')->assertConflict()->assertJsonPath('code', 'student_result_not_released');

        $this->release($student, 'student')->assertOk();
        $this->release($student, 'parent')->assertOk()
            ->assertJsonPath('message', 'Topic result released to Parents.')
            ->assertJsonPath('data.visibility.parent_visible', true)
            ->assertJsonPath('data.visibility.parent_released_at', '2026-10-05T10:00:00Z')
            ->assertJsonPath('data.visibility.can_release_to_parent', false)
            ->assertJsonPath('data.parent_released_by.id', $this->teacher->id);
        $this->travelTo(now()->addHour());
        $this->release($student, 'parent')->assertOk()->assertJsonPath('data.visibility.parent_released_at', '2026-10-05T10:00:00Z');

        foreach (['with_student', 'hidden', null] as $mode) {
            $this->releaseModes('manual_teacher', $mode);
            $this->release($student, 'parent')->assertConflict()->assertJsonPath('code', 'manual_release_not_allowed');
        }
    }

    public function test_an_automatic_student_mode_lets_the_teacher_release_to_parents_directly(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->releaseModes('automatic', 'manual_teacher');

        $this->release($student, 'parent')->assertOk()->assertJsonPath('data.visibility.parent_visible', true);
        $this->assertNull(TopicResult::query()->sole()->student_released_at);
    }

    public function test_bulk_student_release_reports_processed_and_skipped_results(): void
    {
        $ready = $this->readyStudent('Alpha Student', '88', '84');
        $released = $this->readyStudent('Beta Student', '60', '62');
        $this->release($released, 'student')->assertOk();
        $waiting = $this->cohortStudent('Gamma Student');
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');
        $notCompleted = $this->cohortStudent('Delta Student');

        $this->bulk('student')->assertOk()
            ->assertJsonPath('message', 'Topic results released to Students.')
            ->assertJsonPath('data', ['processed' => 2, 'skipped' => ['already_done' => 1, 'not_ready' => 1]]);

        $releasedIds = TopicResult::query()->whereNotNull('student_released_at')->pluck('student_id')->sort()->values()->all();
        $this->assertSame(collect([$ready->id, $released->id, $notCompleted->id])->sort()->values()->all(), $releasedIds);
    }

    public function test_bulk_release_with_a_forbidding_mode_fails_as_a_whole(): void
    {
        $this->readyStudent('Alpha Student', '88', '84');
        $this->releaseModes('automatic', 'hidden');

        $this->bulk('student')->assertConflict()->assertJsonPath('code', 'manual_release_not_allowed');
        $this->bulk('parent')->assertConflict()->assertJsonPath('code', 'manual_release_not_allowed');
        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_bulk_parent_release_skips_results_the_student_cannot_see(): void
    {
        $visible = $this->readyStudent('Alpha Student', '88', '84');
        $this->release($visible, 'student')->assertOk();
        $this->readyStudent('Beta Student', '88', '84');

        $this->bulk('parent')->assertOk()
            ->assertJsonPath('message', 'Topic results released to Parents.')
            ->assertJsonPath('data', ['processed' => 1, 'skipped' => ['already_done' => 0, 'not_ready' => 1]]);
        $this->bulk('parent')->assertOk()->assertJsonPath('data', ['processed' => 0, 'skipped' => ['already_done' => 1, 'not_ready' => 1]]);
    }

    public function test_releases_outside_the_teachers_topics_or_the_cohort_are_not_found(): void
    {
        $member = $this->readyStudent('Alpha Student', '88', '84');
        $outsider = $this->studentNamed('Outside Student');
        $colleague = User::factory()->teacher()->create(['institution_id' => $this->institution->id, 'must_change_password' => false]);

        $this->release($outsider, 'student')->assertNotFound();
        $this->homeworkRaw($colleague, 'POST', $this->resultsUri().'/'.$member->id.'/release/student', '')->assertNotFound();
        $this->homeworkRaw($colleague, 'POST', $this->resultsUri().'/release/student', '')->assertNotFound();
        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/not-a-uuid/release/student', '')->assertNotFound();
        $this->assertSame(0, TopicResult::query()->count());
    }

    /** @return array<string, array{string, array<string, mixed>}> */
    public static function invalidRequests(): array
    {
        return ['non-empty body' => ['{"force":true}', []], 'query parameter' => ['', ['force' => 1]]];
    }

    #[DataProvider('invalidRequests')]
    public function test_release_requests_take_no_body_or_query(string $body, array $query): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/'.$student->id.'/release/student', $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/release/student', $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/'.$student->id.'/release/student', '{}')->assertOk();
    }

    private function release(User $student, string $audience): TestResponse
    {
        return $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/'.$student->id.'/release/'.$audience, '');
    }

    private function bulk(string $audience): TestResponse
    {
        return $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/release/'.$audience, '');
    }

    private function resultsUri(): string
    {
        return '/api/v1/teacher/topics/'.$this->topic->id.'/results';
    }
}
