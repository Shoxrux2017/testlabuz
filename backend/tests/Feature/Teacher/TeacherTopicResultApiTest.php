<?php

namespace Tests\Feature\Teacher;

use App\Enums\TopicResultClosureReason;
use App\Enums\TopicResultOutcome;
use App\Enums\TopicResultSideState;
use App\Enums\UnderstandingCategoryCode as Code;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\GroupTeacherMembership;
use App\Models\InstitutionSetting;
use App\Models\InstitutionUnderstandingCategory;
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
use Tests\Feature\Teacher\Concerns\BuildsTeacherSubmissionContext;
use Tests\TestCase;

/** S10-BE-002: the Teacher's Topic results, their visibility state and the Topic-result comment (docs/09 §25.4-25.7). */
class TeacherTopicResultApiTest extends TestCase
{
    use BuildsTeacherSubmissionContext;
    use UsesBlitzReadSnapshot;

    private const ITEM_KEYS = ['student', 'result_status', 'closed_outcome', 'closed_at', 'missing_component', 'homework', 'blitz',
        'score_difference', 'acceptable_difference', 'consistency', 'calculation_method', 'final_score', 'category_score', 'category',
        'teacher_comment', 'visibility', 'can_close'];

    private Assessment $homework;

    private Assessment $blitz;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-05 10:00:00 UTC'));
        $this->submissionContext();
        $this->teacher->update(['must_change_password' => false]);
        $this->homework = $this->homeworkTask();
        $this->blitz = $this->blitzTask();
        TopicResultPair::factory()->create([
            'homework_assessment_id' => $this->homework->id, 'blitz_assessment_id' => $this->blitz->id,
            'designated_by_user_id' => $this->teacher->id, 'designated_at' => now()->subHours(3), 'cohort_snapshotted_at' => now()->subHours(2),
        ]);
        InstitutionSetting::query()->where('institution_id', $this->institution->id)->update([
            'acceptable_score_difference' => '10.00000000', 'blitz_timer_start_mode' => 'individual',
            'student_result_release_mode' => 'manual_teacher', 'parent_result_release_mode' => 'manual_teacher',
        ]);

        foreach ([[Code::UnderstoodWell, 86, 100], [Code::PartiallyUnderstood, 71, 85], [Code::NeedsRevision, 51, 70],
            [Code::NeedsTeacherSupport, 0, 50], [Code::NotCompleted, null, null]] as [$code, $min, $max]) {
            InstitutionUnderstandingCategory::factory()->forInstitution($this->institution, $this->admin)->forCode($code, $min, $max)->create();
        }
    }

    public function test_the_routes_are_registered_behind_the_teacher_gates(): void
    {
        foreach ([
            ['api/v1/teacher/topics/{topic}/results', ['GET', 'HEAD']],
            ['api/v1/teacher/topics/{topic}/results/{student}', ['GET', 'HEAD']],
            ['api/v1/teacher/topics/{topic}/results/{student}/comment', ['PUT']],
        ] as [$uri, $methods]) {
            $route = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === $uri)->sole();
            $this->assertSame($methods, $route->methods());
            $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'], $route->middleware());
        }

        $this->getJson($this->listUri())->assertUnauthorized();
    }

    public function test_the_list_explains_each_result_in_name_order_with_counts(): void
    {
        $calculated = $this->readyStudent('Beta Student', '88.00000000', '84.00000000');
        $absent = $this->cohortStudent('Alpha Student');
        $waiting = $this->cohortStudent('Gamma Student');
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');

        $response = $this->list()->assertOk();

        $this->assertSame([$absent->id, $calculated->id, $waiting->id], array_column(array_column($response->json('data'), 'student'), 'id'));
        $this->assertSame(self::ITEM_KEYS, array_keys($response->json('data.1')));
        $this->assertSame(['page' => 1, 'per_page' => 25, 'total' => 3, 'last_page' => 1], $response->json('meta.pagination'));
        $this->assertSame([
            'waiting_for_homework' => 0, 'waiting_for_blitz' => 0, 'waiting_for_teacher_review' => 1, 'waiting_for_settings' => 0,
            'calculated' => 1, 'not_completed' => 1, 'closed' => 0,
        ], $response->json('meta.counts'));

        $item = $response->json('data.1');
        $this->assertSame(['id' => $calculated->id, 'full_name' => 'Beta Student'], $item['student']);
        $this->assertSame(['calculated', null, null, null], [$item['result_status'], $item['closed_outcome'], $item['closed_at'], $item['missing_component']]);
        $homeworkAttempt = AssessmentAttempt::query()->where('assessment_id', $this->homework->id)->where('student_id', $calculated->id)->sole();
        $this->assertSame(['assessment_id' => $this->homework->id, 'state' => 'ready', 'official_attempt_id' => $homeworkAttempt->id,
            'attempt_number' => 1, 'score' => 88], $item['homework']);
        $this->assertSame([4, 10, 'consistent', 'average', 86, 86], [$item['score_difference'], $item['acceptable_difference'],
            $item['consistency'], $item['calculation_method'], $item['final_score'], $item['category_score']]);
        $this->assertSame(['code' => 'understood_well', 'label' => 'Understood well'], $item['category']);
        $this->assertSame([
            'student_release_mode' => 'manual_teacher', 'student_visible' => false, 'student_released_at' => null, 'can_release_to_student' => true,
            'parent_release_mode' => 'manual_teacher', 'parent_visible' => false, 'parent_released_at' => null, 'can_release_to_parent' => false,
        ], $item['visibility']);
        $this->assertTrue($item['can_close']);

        $notCompleted = $response->json('data.0');
        $this->assertSame(['not_completed', 'both', 'missing', 'missing'], [$notCompleted['result_status'], $notCompleted['missing_component'],
            $notCompleted['homework']['state'], $notCompleted['blitz']['state']]);
        $this->assertSame(['code' => 'not_completed', 'label' => 'Not completed'], $notCompleted['category']);
        $this->assertNull($notCompleted['final_score']);
        $this->assertSame(['waiting_for_teacher_review', null, false], [$response->json('data.2.result_status'), $response->json('data.2.category'),
            $response->json('data.2.can_close')]);
    }

    public function test_the_list_orders_names_like_the_other_teacher_lists_without_regard_to_case(): void
    {
        foreach (['Delta Student', 'Beta Student', 'alpha Student', 'Ćelik Student', 'Twin Student', 'twin Student'] as $name) {
            $this->cohortStudent($name);
        }

        $expected = User::query()->whereIn('full_name', ['Delta Student', 'Beta Student', 'alpha Student', 'Ćelik Student', 'Twin Student', 'twin Student'])
            ->orderByRaw('lower(full_name) ASC')->orderBy('id')->pluck('id')->all();

        $this->assertSame($expected, array_column(array_column($this->list()->json('data'), 'student'), 'id'));
        $this->assertSame('alpha Student', $this->list()->json('data.0.student.full_name'));
    }

    public function test_a_page_far_beyond_the_results_is_empty(): void
    {
        $this->readyStudent('Alpha Student', '88', '84');

        $this->list(['page' => '400000000000000000'])->assertOk()->assertJsonPath('data', [])->assertJsonPath('meta.pagination.total', 1);
    }

    public function test_filters_apply_before_paging_and_counts_cover_the_whole_cohort(): void
    {
        $this->readyStudent('Alpha Student', '88', '84');
        $this->readyStudent('Beta Student', '60', '62');
        $this->cohortStudent('Gamma Student');

        $this->assertSame(['Beta Student'], array_column(array_column($this->list(['category' => 'needs_revision'])->json('data'), 'student'), 'full_name'));
        $calculated = $this->list(['result_status' => 'calculated', 'per_page' => 1, 'page' => 2])->assertOk();
        $this->assertSame(['Beta Student'], array_column(array_column($calculated->json('data'), 'student'), 'full_name'));
        $this->assertSame(['page' => 2, 'per_page' => 1, 'total' => 2, 'last_page' => 2], $calculated->json('meta.pagination'));
        $this->assertSame(2, $calculated->json('meta.counts.calculated'));
        $this->assertSame(1, $calculated->json('meta.counts.not_completed'));
    }

    /** @return array<string, array{array<string, mixed>, string}> */
    public static function invalidListRequests(): array
    {
        return [
            'unknown status' => [['result_status' => 'released'], ''],
            'unknown category' => [['category' => 'excellent'], ''],
            'page zero' => [['page' => 0], ''],
            'per page above 100' => [['per_page' => 101], ''],
            'unknown key' => [['sort' => 'name'], ''],
            'body' => [[], '{}'],
        ];
    }

    #[DataProvider('invalidListRequests')]
    public function test_the_list_rejects_invalid_query_and_body(array $query, string $body): void
    {
        $this->homeworkRaw($this->teacher, 'GET', $this->listUri(), $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_waiting_for_settings_and_closed_results_are_listed_with_their_counts(): void
    {
        $closed = $this->readyStudent('Alpha Student', '88', '84');
        $this->closedRow($closed, []);
        $settings = $this->readyStudent('Beta Student', '88', '84');
        InstitutionUnderstandingCategory::query()->where('code', 'needs_revision')->update(['min_score' => 52]);

        $response = $this->list()->assertOk();

        $this->assertSame(1, $response->json('meta.counts.closed'));
        $this->assertSame(1, $response->json('meta.counts.waiting_for_settings'));
        $attempt = fn (User $student, Assessment $task): AssessmentAttempt => AssessmentAttempt::query()
            ->where('assessment_id', $task->id)->where('student_id', $student->id)->sole();
        $side = fn (User $student, Assessment $task, int|float $score): array => ['assessment_id' => $task->id, 'state' => 'ready',
            'official_attempt_id' => $attempt($student, $task)->id, 'attempt_number' => 1, 'score' => $score];
        // Released modes are manual; the Homework (closed) and the Blitz (closed) finished every Student's work.
        $visibility = ['student_release_mode' => 'manual_teacher', 'student_visible' => false, 'student_released_at' => null,
            'can_release_to_student' => true, 'parent_release_mode' => 'manual_teacher', 'parent_visible' => false,
            'parent_released_at' => null, 'can_release_to_parent' => false];

        $this->assertSame([
            'student' => ['id' => $closed->id, 'full_name' => 'Alpha Student'], 'result_status' => 'closed', 'closed_outcome' => 'calculated',
            'closed_at' => '2026-10-05T09:30:00Z', 'missing_component' => null,
            'homework' => $side($closed, $this->homework, 88), 'blitz' => $side($closed, $this->blitz, 84),
            'score_difference' => 4, 'acceptable_difference' => 12, 'consistency' => 'consistent', 'calculation_method' => 'average',
            'final_score' => 86, 'category_score' => 86, 'category' => ['code' => 'understood_well', 'label' => 'Understood well'],
            'teacher_comment' => null, 'visibility' => $visibility, 'can_close' => false,
        ], $response->json('data.0'));
        $this->assertSame([
            'student' => ['id' => $settings->id, 'full_name' => 'Beta Student'], 'result_status' => 'waiting_for_settings',
            'closed_outcome' => null, 'closed_at' => null, 'missing_component' => null,
            'homework' => $side($settings, $this->homework, 88), 'blitz' => $side($settings, $this->blitz, 84),
            'score_difference' => null, 'acceptable_difference' => null, 'consistency' => null, 'calculation_method' => null,
            'final_score' => null, 'category_score' => null, 'category' => null, 'teacher_comment' => null,
            'visibility' => array_replace($visibility, ['can_release_to_student' => false]), 'can_close' => false,
        ], $response->json('data.1'));
    }

    public function test_a_not_completed_and_a_waiting_item_carry_exactly_their_values(): void
    {
        $absent = $this->cohortStudent('Alpha Student');
        $waiting = $this->cohortStudent('Beta Student');
        $this->officialAttempt($this->homework, $waiting, '80.00000000');
        $waitingAttempt = $this->submission($this->blitz, $waiting, 'waiting_for_teacher_review');
        $homeworkAttempt = AssessmentAttempt::query()->where('assessment_id', $this->homework->id)->where('student_id', $waiting->id)->sole();
        $visibility = ['student_release_mode' => 'manual_teacher', 'student_visible' => false, 'student_released_at' => null,
            'can_release_to_student' => false, 'parent_release_mode' => 'manual_teacher', 'parent_visible' => false,
            'parent_released_at' => null, 'can_release_to_parent' => false];
        $empty = ['score_difference' => null, 'acceptable_difference' => null, 'consistency' => null, 'calculation_method' => null,
            'final_score' => null, 'category_score' => null];

        $items = $this->list()->assertOk()->json('data');

        $this->assertSame([
            'student' => ['id' => $absent->id, 'full_name' => 'Alpha Student'], 'result_status' => 'not_completed', 'closed_outcome' => null,
            'closed_at' => null, 'missing_component' => 'both',
            'homework' => ['assessment_id' => $this->homework->id, 'state' => 'missing', 'official_attempt_id' => null, 'attempt_number' => null, 'score' => null],
            'blitz' => ['assessment_id' => $this->blitz->id, 'state' => 'missing', 'official_attempt_id' => null, 'attempt_number' => null, 'score' => null],
            ...$empty, 'category' => ['code' => 'not_completed', 'label' => 'Not completed'], 'teacher_comment' => null,
            'visibility' => array_replace($visibility, ['can_release_to_student' => true]), 'can_close' => true,
        ], $items[0]);
        $this->assertSame([
            'student' => ['id' => $waiting->id, 'full_name' => 'Beta Student'], 'result_status' => 'waiting_for_teacher_review',
            'closed_outcome' => null, 'closed_at' => null, 'missing_component' => null,
            'homework' => ['assessment_id' => $this->homework->id, 'state' => 'ready', 'official_attempt_id' => $homeworkAttempt->id, 'attempt_number' => 1, 'score' => 80],
            'blitz' => ['assessment_id' => $this->blitz->id, 'state' => 'waiting_for_teacher_review', 'official_attempt_id' => null, 'attempt_number' => null, 'score' => null],
            ...$empty, 'category' => null, 'teacher_comment' => null, 'visibility' => $visibility, 'can_close' => false,
        ], $items[1]);
        $this->assertNotNull($waitingAttempt->id);
    }

    public function test_another_institutions_topic_or_student_is_not_found(): void
    {
        $member = $this->readyStudent('Alpha Student', '88', '84');
        $foreign = TopicResult::factory()->closedCalculated()->create();

        $this->read($this->teacher, '/api/v1/teacher/topics/'.$foreign->topic_id.'/results')->assertNotFound();
        $this->read($this->teacher, $this->listUri().'/'.$foreign->student_id)->assertNotFound();
        $this->read($this->teacher, $this->itemUri($member))->assertOk();
    }

    public function test_a_topic_without_a_cohort_has_no_results_and_zero_counts(): void
    {
        TopicResultPair::query()->update(['cohort_snapshotted_at' => null]);

        $response = $this->list()->assertOk();

        $this->assertSame([], $response->json('data'));
        $this->assertSame([0], array_values(array_unique($response->json('meta.counts'))));
    }

    public function test_other_teachers_and_former_teachers_cannot_read_the_results(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $colleague = User::factory()->teacher()->create(['institution_id' => $this->institution->id, 'must_change_password' => false]);
        GroupTeacherMembership::factory()->create(['institution_id' => $this->institution->id, 'group_id' => $this->group->id,
            'teacher_id' => $colleague->id, 'assigned_by_user_id' => $this->admin->id]);

        $this->read($colleague, $this->listUri())->assertNotFound();
        $this->read($colleague, $this->itemUri($student))->assertNotFound();

        GroupTeacherMembership::query()->where('teacher_id', $this->teacher->id)->update(['ended_at' => now()]);

        $this->list()->assertNotFound();
    }

    public function test_the_visibility_block_follows_the_release_modes(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        InstitutionSetting::query()->update(['student_result_release_mode' => 'automatic', 'parent_result_release_mode' => 'with_student']);

        $this->assertSame([true, true, false, false], $this->visibilityFlags($student));

        InstitutionSetting::query()->update(['parent_result_release_mode' => 'hidden']);

        $this->assertSame([true, false, false, false], $this->visibilityFlags($student));

        InstitutionSetting::query()->update(['parent_result_release_mode' => 'manual_teacher']);

        $this->assertSame([true, false, false, true], $this->visibilityFlags($student));
    }

    public function test_the_detail_adds_the_actors_and_a_closed_result_reads_its_snapshot(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->closedRow($student, ['teacher_comment' => 'Well done.', 'teacher_comment_updated_by_user_id' => $this->teacher->id,
            'teacher_comment_updated_at' => now()->subHour()]);

        $data = $this->read($this->teacher, $this->itemUri($student))->assertOk()->json('data');

        $this->assertSame([...self::ITEM_KEYS, 'teacher_comment_updated_at', 'teacher_comment_updated_by', 'student_released_by',
            'parent_released_by', 'closed_by', 'closure_reason'], array_keys($data));
        $this->assertSame(['closed', 'calculated', '2026-10-05T09:30:00Z', 12], [$data['result_status'], $data['closed_outcome'],
            $data['closed_at'], $data['acceptable_difference']]);
        $this->assertSame(['Well done.', '2026-10-05T09:00:00Z'], [$data['teacher_comment'], $data['teacher_comment_updated_at']]);
        $this->assertSame(['id' => $this->teacher->id, 'full_name' => $this->teacher->full_name], $data['closed_by']);
        $this->assertSame([null, null, 'teacher', false], [$data['student_released_by'], $data['parent_released_by'], $data['closure_reason'], $data['can_close']]);
    }

    public function test_the_detail_names_the_release_actors_and_an_archive_closure(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->closedRow($student, ['closure_reason' => TopicResultClosureReason::TopicArchived,
            'student_released_at' => now()->subMinutes(20), 'student_released_by_user_id' => $this->teacher->id,
            'parent_released_at' => now()->subMinutes(10), 'parent_released_by_user_id' => $this->teacher->id]);

        $data = $this->read($this->teacher, $this->itemUri($student))->assertOk()->json('data');

        $actor = ['id' => $this->teacher->id, 'full_name' => $this->teacher->full_name];
        $this->assertSame([$actor, $actor, 'topic_archived'], [$data['student_released_by'], $data['parent_released_by'], $data['closure_reason']]);
        $this->assertSame(['2026-10-05T09:40:00Z', '2026-10-05T09:50:00Z'], [$data['visibility']['student_released_at'], $data['visibility']['parent_released_at']]);
    }

    /** @return array<string, array{array<string, mixed>, string}> */
    public static function invalidDetailRequests(): array
    {
        return ['query parameter' => [['include' => 'attempts'], ''], 'body' => [[], '{}']];
    }

    #[DataProvider('invalidDetailRequests')]
    public function test_the_detail_takes_no_query_or_body(array $query, string $body): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $this->homeworkRaw($this->teacher, 'GET', $this->itemUri($student), $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_the_detail_of_a_student_outside_the_cohort_or_a_bad_id_is_not_found(): void
    {
        $outsider = $this->studentNamed('Outside Student');

        $this->read($this->teacher, $this->itemUri($outsider))->assertNotFound();
        $this->read($this->teacher, '/api/v1/teacher/topics/'.$this->topic->id.'/results/not-a-uuid')->assertNotFound();
    }

    public function test_the_comment_is_trimmed_saved_and_returned_with_the_detail(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $response = $this->comment($student, ['teacher_comment' => "\u{00A0} Revise\u{00A0}question 4.\n\u{3000}"])->assertOk();

        $response->assertJsonPath('message', 'Topic result comment saved successfully.')
            ->assertJsonPath('data.teacher_comment', "Revise\u{00A0}question 4.")
            ->assertJsonPath('data.teacher_comment_updated_at', '2026-10-05T10:00:00Z')
            ->assertJsonPath('data.teacher_comment_updated_by.id', $this->teacher->id);
        $this->assertSame("Revise\u{00A0}question 4.", TopicResult::query()->sole()->teacher_comment);
    }

    public function test_a_blank_or_null_comment_clears_it_and_an_unchanged_one_writes_nothing(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->comment($student, ['teacher_comment' => null])->assertOk();
        $this->assertSame(0, TopicResult::query()->count(), 'clearing a missing comment creates no row');

        $this->comment($student, ['teacher_comment' => 'First note.'])->assertOk();
        $updatedAt = TopicResult::query()->sole()->updated_at;
        $this->travelTo(now()->addHour());
        $this->comment($student, ['teacher_comment' => ' First note. '])->assertOk();
        $this->assertSame('2026-10-05T10:00:00Z', TopicResult::query()->sole()->teacher_comment_updated_at->utc()->format('Y-m-d\TH:i:s\Z'));
        $this->assertEquals($updatedAt, TopicResult::query()->sole()->updated_at);

        $this->comment($student, ['teacher_comment' => "\u{00A0}\u{3000}"])->assertOk()->assertJsonPath('data.teacher_comment', null);
        $row = TopicResult::query()->sole();
        $this->assertNull($row->teacher_comment);
        $this->assertSame($this->teacher->id, $row->teacher_comment_updated_by_user_id);
    }

    /** @return array<string, array{string}> */
    public static function invalidCommentBodies(): array
    {
        return [
            'missing key' => ['{}'],
            'extra key' => ['{"teacher_comment":"x","visible":true}'],
            'number' => ['{"teacher_comment":5}'],
            'array body' => ['["x"]'],
            'not json' => ['teacher_comment=x'],
            'above 2000 characters' => [json_encode(['teacher_comment' => ' '.str_repeat('é', 2001).' '], JSON_THROW_ON_ERROR)],
        ];
    }

    #[DataProvider('invalidCommentBodies')]
    public function test_the_comment_body_is_strict(string $body): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $this->homeworkRaw($this->teacher, 'PUT', $this->itemUri($student).'/comment', $body)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_the_limit_counts_2000_characters_after_trimming_and_query_parameters_are_rejected(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');

        $this->homeworkRaw($this->teacher, 'PUT', $this->itemUri($student).'/comment', '{"teacher_comment":"x"}', ['force' => 1])
            ->assertUnprocessable();
        $this->comment($student, ['teacher_comment' => "\u{00A0} ".str_repeat('é', 2000)." \u{3000}"])->assertOk();
        $this->assertSame(2000, mb_strlen((string) TopicResult::query()->sole()->teacher_comment));
    }

    public function test_a_changed_comment_records_the_new_author_and_time_and_null_clears_it(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $this->comment($student, ['teacher_comment' => 'First note.'])->assertOk();
        $this->travelTo(now()->addHour());

        $this->comment($student, ['teacher_comment' => 'Second note.'])->assertOk()
            ->assertJsonPath('data.teacher_comment', 'Second note.')
            ->assertJsonPath('data.teacher_comment_updated_at', '2026-10-05T11:00:00Z')
            ->assertJsonPath('data.teacher_comment_updated_by.full_name', $this->teacher->full_name);

        $this->travelTo(now()->addHour());
        $this->comment($student, ['teacher_comment' => null])->assertOk()->assertJsonPath('data.teacher_comment', null)
            ->assertJsonPath('data.teacher_comment_updated_at', '2026-10-05T12:00:00Z');
    }

    public function test_a_closed_result_rejects_every_comment_write(): void
    {
        $student = $this->readyStudent('Alpha Student', '88', '84');
        $row = $this->closedRow($student, ['teacher_comment' => 'Kept.', 'teacher_comment_updated_by_user_id' => $this->teacher->id,
            'teacher_comment_updated_at' => now()]);

        $this->comment($student, ['teacher_comment' => 'Kept.'])->assertConflict()->assertJsonPath('code', 'result_closed');
        $this->comment($student, ['teacher_comment' => 'Changed.'])->assertConflict()->assertJsonPath('code', 'result_closed');
        $this->assertSame('Kept.', $row->fresh()->teacher_comment);
    }

    public function test_comments_outside_the_cohort_or_the_teachers_topics_are_not_found(): void
    {
        $outsider = $this->studentNamed('Outside Student');
        $member = $this->readyStudent('Alpha Student', '88', '84');
        $colleague = User::factory()->teacher()->create(['institution_id' => $this->institution->id, 'must_change_password' => false]);

        $this->comment($outsider, ['teacher_comment' => 'x'])->assertNotFound();
        $this->homeworkJson($colleague, 'PUT', $this->itemUri($member).'/comment', ['teacher_comment' => 'x'])->assertNotFound();
        $this->homeworkJson($this->teacher, 'PUT', $this->listUri().'/not-a-uuid/comment', ['teacher_comment' => 'x'])->assertNotFound();
        $this->assertSame(0, TopicResult::query()->count());
    }

    public function test_the_list_runs_a_constant_number_of_queries(): void
    {
        $counts = [];

        foreach ([2, 5] as $size) {
            while (AssessmentAttempt::query()->where('assessment_id', $this->homework->id)->count() < $size) {
                $this->readyStudent('Student '.uniqid(), '88', '84');
            }

            DB::flushQueryLog();
            DB::enableQueryLog();
            $this->list()->assertOk();
            $counts[$size] = count(DB::getQueryLog());
            DB::disableQueryLog();
        }

        $this->assertSame($counts[2], $counts[5]);
    }

    /** A calculated result the Teacher closed: H 88, B 84, T 12 used, average 86. */
    private function closedRow(User $student, array $attributes): TopicResult
    {
        $attempts = AssessmentAttempt::query()->where('student_id', $student->id)->get()->keyBy('assessment_id');

        return TopicResult::factory()->create([
            'institution_id' => $this->institution->id, 'topic_id' => $this->topic->id, 'student_id' => $student->id,
            'closed_at' => now()->subMinutes(30), 'closed_by_user_id' => $this->teacher->id, 'closure_reason' => TopicResultClosureReason::Teacher,
            'closed_outcome' => TopicResultOutcome::Calculated, 'homework_assessment_id' => $this->homework->id, 'blitz_assessment_id' => $this->blitz->id,
            'homework_state' => TopicResultSideState::Ready, 'blitz_state' => TopicResultSideState::Ready,
            'homework_attempt_id' => $attempts[$this->homework->id]->id, 'homework_score' => '88.00000000',
            'blitz_attempt_id' => $attempts[$this->blitz->id]->id, 'blitz_score' => '84.00000000',
            'score_difference' => '4.00000000', 'acceptable_difference_used' => '12.00000000', 'calculation_method' => 'average',
            'consistency' => 'consistent', 'final_score' => '86.00000000', 'category_score' => 86, 'category_code' => 'understood_well',
            'category_min_score_used' => 86, 'category_max_score_used' => 100,
            ...$attributes,
        ]);
    }

    private function cohortStudent(string $name): User
    {
        $student = $this->studentNamed($name);
        $this->blitzRecipient($this->homework, $student, $this->teacher);
        $this->blitzRecipient($this->blitz, $student, $this->teacher);

        return $student;
    }

    private function readyStudent(string $name, string $homeworkScore, string $blitzScore): User
    {
        $student = $this->cohortStudent($name);
        $this->officialAttempt($this->homework, $student, $homeworkScore);
        $this->officialAttempt($this->blitz, $student, $blitzScore);

        return $student;
    }

    private function officialAttempt(Assessment $task, User $student, string $score): void
    {
        $attempt = $this->submission($task, $student, 'checked', ['normalized_score' => $score, 'earned_points' => '0.00000000']);
        OfficialTaskScore::factory()->create(['official_attempt_id' => $attempt->id]);
    }

    /** @return array{bool, bool, bool, bool} */
    private function visibilityFlags(User $student): array
    {
        $visibility = $this->read($this->teacher, $this->itemUri($student))->assertOk()->json('data.visibility');

        return [$visibility['student_visible'], $visibility['parent_visible'], $visibility['can_release_to_student'], $visibility['can_release_to_parent']];
    }

    /** @param array<string, mixed> $query */
    private function list(array $query = []): TestResponse
    {
        return $this->read($this->teacher, $this->listUri(), $query);
    }

    /** @param array<string, mixed> $query */
    private function read(User $teacher, string $uri, array $query = []): TestResponse
    {
        return $this->homeworkRaw($teacher, 'GET', $uri, '', $query);
    }

    /** @param array<string, mixed> $body */
    private function comment(User $student, array $body): TestResponse
    {
        return $this->homeworkJson($this->teacher, 'PUT', $this->itemUri($student).'/comment', $body);
    }

    private function listUri(): string
    {
        return '/api/v1/teacher/topics/'.$this->topic->id.'/results';
    }

    private function itemUri(User $student): string
    {
        return $this->listUri().'/'.$student->id;
    }
}
