<?php

namespace Tests\Feature\Teacher;

use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultOutcome;
use App\Models\AssessmentAttempt;
use App\Models\InstitutionSetting;
use App\Models\OfficialTaskScore;
use App\Models\TopicResult;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTopicResultContext;
use Tests\TestCase;

/** S10-BE-004: Teacher closure of Topic results, single, bulk and at Topic archive (docs/09 §25.8-25.10). */
class TeacherTopicResultCloseApiTest extends TestCase
{
    use BuildsTopicResultContext;
    use UsesBlitzReadSnapshot;

    private const CLOSURE_COLUMNS = [
        'closed_at', 'closed_by_user_id', 'closure_reason', 'closed_outcome', 'missing_component', 'homework_assessment_id',
        'blitz_assessment_id', 'homework_state', 'blitz_state', 'homework_attempt_id', 'homework_score', 'blitz_attempt_id',
        'blitz_score', 'score_difference', 'acceptable_difference_used', 'calculation_method', 'consistency', 'final_score',
        'category_score', 'category_code', 'category_min_score_used', 'category_max_score_used',
    ];

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-05 10:00:00.250 UTC'));
        $this->topicResultContext();
    }

    public function test_the_close_routes_are_registered_behind_the_teacher_gates(): void
    {
        foreach (['api/v1/teacher/topics/{topic}/results/{student}/close', 'api/v1/teacher/topics/{topic}/results/close'] as $uri) {
            $route = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === $uri)->sole();
            $this->assertSame(['POST'], $route->methods());
            $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'], $route->middleware());
        }
    }

    public function test_closing_a_calculated_result_writes_the_full_snapshot(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $attempts = AssessmentAttempt::query()->where('student_id', $student->id)->get()->keyBy('assessment_id');

        $this->close($student)->assertOk()
            ->assertJsonPath('message', 'Topic result closed.')
            ->assertJsonPath('data.result_status', 'closed')
            ->assertJsonPath('data.closed_outcome', 'calculated')
            ->assertJsonPath('data.closed_at', '2026-10-05T10:00:00Z')
            ->assertJsonPath('data.closed_by.id', $this->teacher->id)
            ->assertJsonPath('data.can_close', false);

        $this->assertSame([
            'closed_at' => '2026-10-05 10:00:00+00', 'closed_by_user_id' => $this->teacher->id, 'closure_reason' => 'teacher',
            'closed_outcome' => 'calculated', 'missing_component' => null, 'homework_assessment_id' => $this->homework->id,
            'blitz_assessment_id' => $this->blitz->id, 'homework_state' => 'ready', 'blitz_state' => 'ready',
            'homework_attempt_id' => $attempts[$this->homework->id]->id, 'homework_score' => '88.00000000',
            'blitz_attempt_id' => $attempts[$this->blitz->id]->id, 'blitz_score' => '84.00000000', 'score_difference' => '4.00000000',
            'acceptable_difference_used' => '10.00000000', 'calculation_method' => 'average', 'consistency' => 'consistent',
            'final_score' => '86.00000000', 'category_score' => 86, 'category_code' => 'understood_well',
            'category_min_score_used' => 86, 'category_max_score_used' => 100,
        ], $this->closureColumns($student));
    }

    public function test_closing_a_not_completed_result_keeps_a_waiting_side_without_values(): void
    {
        $student = $this->cohortStudent('Alpha Student');
        $this->submission($this->homework, $student, 'waiting_for_teacher_review');

        $this->close($student)->assertOk()->assertJsonPath('data.closed_outcome', 'not_completed');

        $this->assertSame([
            'closed_at' => '2026-10-05 10:00:00+00', 'closed_by_user_id' => $this->teacher->id,
            'closure_reason' => 'teacher', 'closed_outcome' => 'not_completed', 'missing_component' => 'blitz',
            'homework_assessment_id' => $this->homework->id, 'blitz_assessment_id' => $this->blitz->id,
            'homework_state' => 'waiting_for_teacher_review', 'blitz_state' => 'missing', 'homework_attempt_id' => null,
            'homework_score' => null, 'blitz_attempt_id' => null, 'blitz_score' => null, 'score_difference' => null,
            'acceptable_difference_used' => null, 'calculation_method' => null, 'consistency' => null, 'final_score' => null,
            'category_score' => null, 'category_code' => 'not_completed', 'category_min_score_used' => null, 'category_max_score_used' => null,
        ], $this->closureColumns($student));
    }

    public function test_an_already_closed_result_is_returned_unchanged(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->closedRow($student, []);
        $before = $this->closureColumns($student);
        $this->travelTo(now()->addHour());

        $this->close($student)->assertOk()->assertJsonPath('data.result_status', 'closed');

        $this->assertSame($before, $this->closureColumns($student));
    }

    public function test_a_result_that_is_not_terminal_or_whose_work_is_not_finished_cannot_be_closed(): void
    {
        $waiting = $this->cohortStudent('Alpha Student');
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');
        $this->close($waiting)->assertConflict()->assertJsonPath('code', 'result_not_ready_for_closure');

        $calculated = $this->readyStudent('Beta Student', '88', '84');
        $this->homework->homeworkAssignment->update(['status' => 'active', 'closed_at' => null, 'deadline_at' => null]);
        $this->close($calculated)->assertConflict()->assertJsonPath('code', 'result_not_ready_for_closure');

        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_closing_keeps_the_comment_and_the_releases(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        TopicResult::factory()->withComment()->releasedToStudent()->create(['institution_id' => $this->institution->id,
            'topic_id' => $this->topic->id, 'student_id' => $student->id]);
        $kept = fn (): array => TopicResult::query()->sole()->only(['teacher_comment', 'teacher_comment_updated_by_user_id',
            'teacher_comment_updated_at', 'student_released_at', 'student_released_by_user_id', 'parent_released_at']);
        $before = $kept();

        $this->close($student)->assertOk();

        $this->assertEquals($before, $kept());
        $this->assertSame(1, TopicResult::query()->count());
    }

    public function test_a_closed_result_stays_frozen_after_a_settings_change(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->close($student)->assertOk();

        InstitutionSetting::query()->where('institution_id', $this->institution->id)->update(['acceptable_score_difference' => '2.00000000']);

        $this->homeworkRaw($this->teacher, 'GET', $this->resultsUri().'/'.$student->id, '')->assertOk()
            ->assertJsonPath('data.calculation_method', 'average')->assertJsonPath('data.final_score', 86)
            ->assertJsonPath('data.acceptable_difference', 10);
    }

    public function test_bulk_close_reports_processed_and_skipped_results(): void
    {
        $this->readyStudent('Alpha Student', '88', '84');
        $closed = $this->readyStudent('Beta Student', '60', '62');
        $this->closedRow($closed, []);
        $waiting = $this->cohortStudent('Gamma Student');
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');
        $this->cohortStudent('Delta Student');

        $this->bulk()->assertOk()
            ->assertJsonPath('message', 'Topic results closed.')
            ->assertJsonPath('data', ['processed' => 2, 'skipped' => ['already_done' => 1, 'not_ready' => 1]]);
        $this->bulk()->assertOk()->assertJsonPath('data', ['processed' => 0, 'skipped' => ['already_done' => 3, 'not_ready' => 1]]);

        $this->assertSame([TopicResultOutcome::Calculated, TopicResultOutcome::Calculated, TopicResultOutcome::NotCompleted],
            TopicResult::query()->whereNotNull('closed_at')->orderBy('closed_outcome')->orderBy('id')->pluck('closed_outcome')->all());
        $this->assertNull(TopicResult::query()->where('student_id', $waiting->id)->first());
    }

    public function test_closes_outside_the_teachers_topics_or_the_cohort_are_not_found(): void
    {
        $member = $this->readyStudent('Alpha Student', '88', '84');
        $outsider = $this->studentNamed('Outside Student');
        $colleague = User::factory()->teacher()->create(['institution_id' => $this->institution->id, 'must_change_password' => false]);

        $this->close($outsider)->assertNotFound();
        $this->homeworkRaw($colleague, 'POST', $this->resultsUri().'/'.$member->id.'/close', '')->assertNotFound();
        $this->homeworkRaw($colleague, 'POST', $this->resultsUri().'/close', '')->assertNotFound();
        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/not-a-uuid/close', '')->assertNotFound();
        $this->assertSame(0, TopicResult::query()->count());
    }

    /** @return array<string, array{string, array<string, mixed>}> */
    public static function invalidRequests(): array
    {
        return ['non-empty body' => ['{"force":true}', []], 'query parameter' => ['', ['force' => 1]]];
    }

    #[DataProvider('invalidRequests')]
    public function test_close_requests_take_no_body_or_query(string $body, array $query): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/'.$student->id.'/close', $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/close', $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame(0, TopicResult::query()->count());
        $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/'.$student->id.'/close', '{}')->assertOk();
    }

    public function test_archiving_the_topic_closes_every_terminal_result_and_leaves_waiting_ones_open(): void
    {
        $ready = $this->readyStudent('Alpha Student', '88', '84');
        $notCompleted = $this->cohortStudent('Beta Student');
        $waiting = $this->cohortStudent('Gamma Student');
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $waitingBlitz = $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');
        $this->closeTopic()->assertOk();
        $this->assertSame(0, TopicResult::query()->count());
        $this->travelTo(now()->addMinute());

        $this->archive()->assertOk();

        $rows = TopicResult::query()->get()->keyBy('student_id');
        $this->assertEqualsCanonicalizing([$ready->id, $notCompleted->id], $rows->keys()->all());
        foreach ([$ready, $notCompleted] as $student) {
            $this->assertSame([TopicResultClosureReason::TopicArchived, $this->teacher->id, '2026-10-05 10:01:00+00'],
                [$rows[$student->id]->closure_reason, $rows[$student->id]->closed_by_user_id, $this->closureColumns($student)['closed_at']]);
        }
        $this->assertSame(TopicResultOutcome::NotCompleted, $rows[$notCompleted->id]->closed_outcome);

        // An idempotent repeat closes nothing, even once the waiting result became terminal.
        $waitingBlitz->update(['status' => 'checked', 'normalized_score' => '70.00000000', 'earned_points' => '0.00000000', 'scoring_completed_at' => now()]);
        OfficialTaskScore::factory()->create(['official_attempt_id' => $waitingBlitz->id]);
        $this->archive()->assertOk();
        $this->assertNull(TopicResult::query()->where('student_id', $waiting->id)->first());
    }

    public function test_closing_the_topic_closes_no_result(): void
    {
        $this->readyStudent('Alpha Student', '88', '84');

        $this->closeTopic()->assertOk();

        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_archive_closes_a_not_completed_result_without_an_activated_official_blitz_and_keeps_it_hidden(): void
    {
        $this->releaseModes('automatic', 'with_student');
        TopicResultPair::query()->where('topic_id', $this->topic->id)->update(['blitz_assessment_id' => null]);
        $student = $this->cohortStudent('Alpha Student');
        $this->closeTopic()->assertOk();

        $this->archive()->assertOk();

        $this->assertSame(['topic_archived', 'not_completed', 'homework', 'not_designated'], array_values(array_intersect_key(
            $this->closureColumns($student), array_flip(['closure_reason', 'closed_outcome', 'missing_component', 'blitz_state']))));
        $this->homeworkRaw($this->teacher, 'GET', $this->resultsUri().'/'.$student->id, '')->assertOk()
            ->assertJsonPath('data.result_status', 'closed')->assertJsonPath('data.visibility.student_visible', false);
    }

    /** @return array<string, mixed> */
    private function closureColumns(User $student): array
    {
        $row = (array) DB::table('topic_results')->where('student_id', $student->id)->sole();

        return array_intersect_key($row, array_flip(self::CLOSURE_COLUMNS));
    }

    private function close(User $student): TestResponse
    {
        return $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/'.$student->id.'/close', '');
    }

    private function bulk(): TestResponse
    {
        return $this->homeworkRaw($this->teacher, 'POST', $this->resultsUri().'/close', '');
    }

    private function closeTopic(): TestResponse
    {
        return $this->homeworkRaw($this->teacher, 'POST', '/api/v1/teacher/topics/'.$this->topic->id.'/close', '');
    }

    private function archive(): TestResponse
    {
        return $this->homeworkRaw($this->teacher, 'POST', '/api/v1/teacher/topics/'.$this->topic->id.'/archive', '');
    }

    private function resultsUri(): string
    {
        return '/api/v1/teacher/topics/'.$this->topic->id.'/results';
    }
}
