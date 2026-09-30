<?php

namespace Tests\Feature\Teacher;

use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherSubmissionContext;
use Tests\TestCase;

class TeacherSubmissionQueueApiTest extends TestCase
{
    use BuildsTeacherSubmissionContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        $this->submissionContext();
    }

    public function test_the_route_is_registered_once_behind_the_teacher_gates(): void
    {
        $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/teacher/submissions');
        $this->assertCount(1, $routes);
        $this->assertSame(['GET', 'HEAD'], $routes->sole()->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'], $routes->sole()->middleware());
        $this->getJson('/api/v1/teacher/submissions')->assertUnauthorized();
        $student = $this->studentNamed('Some Student');
        $student->update(['must_change_password' => false]);
        $this->submissionsRequest($student)->assertForbidden();
    }

    public function test_only_terminal_work_of_the_teachers_visible_topics_is_listed(): void
    {
        $student = $this->studentNamed('Alpha Student');
        $homework = $this->homeworkTask();
        $blitz = $this->blitzTask();
        $visible = [
            $this->submission($homework, $student, 'submitted'),
            $this->submission($homework, $student, 'waiting_for_teacher_review'),
            $this->submission($homework, $student, 'checked'),
            $this->submission($blitz, $student, 'timed_out_finalized', ['submitted_at' => null, 'finalization_reason' => 'timeout_auto_submit']),
        ];
        $this->submission($this->homeworkTask(), $student, 'in_progress');
        // Another Teacher's Topic in the same Group.
        $otherTeacher = User::factory()->teacher($this->institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create(['institution_id' => $this->institution->id, 'group_id' => $this->group->id,
            'teacher_id' => $otherTeacher->id, 'assigned_by_user_id' => $this->admin->id]);
        $otherTopic = Topic::factory()->active()->create(['institution_id' => $this->institution->id,
            'group_id' => $this->group->id, 'teacher_id' => $otherTeacher->id]);
        $this->submission($this->homeworkTask(topic: $otherTopic), $student, 'checked');
        // Another Institution.
        [$foreignInstitution, $foreignTeacher, $foreignAdmin, $foreignGroup, $foreignTopic] = $this->homeworkContext(TopicStatus::Active);
        $foreignStudent = $this->eligibleStudent($foreignInstitution, $foreignAdmin, $foreignGroup);
        $foreignHomework = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);
        $this->blitzAttempt($foreignHomework, $foreignStudent, $foreignTeacher, ['status' => 'checked', 'possible_points' => '20.000000',
            'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(), 'finalization_reason' => 'student_submit',
            'earned_points' => '1.00000000', 'normalized_score' => '5.00000000', 'scoring_completed_at' => now()]);

        // Attempts whose recipient row belongs to another Student or another task.
        $mismatchedTask = $this->homeworkTask();
        $otherRecipient = $this->blitzRecipient($mismatchedTask, $this->studentNamed('Other Student'), $this->teacher);
        $foreignRecipientAttempt = $this->submission($mismatchedTask, $student, 'checked', ['assessment_student_id' => $otherRecipient->id]);
        $blitzRecipient = AssessmentStudent::query()->where('assessment_id', $blitz->id)->where('student_id', $student->id)->sole();
        $crossTaskAttempt = $this->submission($mismatchedTask, $student, 'checked', ['assessment_student_id' => $blitzRecipient->id]);

        $this->assertIds($visible, $this->submissionsRequest($this->teacher)->assertOk());
        foreach ([$foreignRecipientAttempt, $crossTaskAttempt] as $mismatched) {
            $this->homeworkRaw($this->teacher, 'GET', '/api/v1/teacher/submissions/'.$mismatched->id, '')->assertNotFound();
        }

        // An ended membership hides the whole Topic.
        GroupTeacherMembership::query()->where('teacher_id', $this->teacher->id)->update(['ended_at' => now()]);
        $this->submissionsRequest($this->teacher)->assertOk()->assertJsonPath('data', []);
    }

    public function test_an_item_has_exactly_the_contract_fields(): void
    {
        $student = $this->studentNamed('Alpha Student');
        $homework = $this->homeworkTask(['review_due_at' => now()->addDays(2)], ['title' => 'Homework 1']);
        $this->officialPair($homework);
        $waiting = $this->submission($homework, $student, 'waiting_for_teacher_review', ['finalized_at' => now()->subHours(3)]);
        $this->answerInState($waiting, 'waiting_for_teacher_review');
        $this->answerInState($waiting, 'teacher_checked', '2.00000000', $this->teacher);
        $this->answerInState($waiting, 'auto_checked', '1.00000000');
        $blitz = $this->blitzTask();
        $checked = $this->submission($blitz, $student, 'checked', ['finalized_at' => now()->subHours(2)]);

        $data = $this->submissionsRequest($this->teacher)->assertOk()->json('data');

        $this->assertSame([
            'id' => $waiting->id,
            'assessment' => ['id' => $homework->id, 'type' => 'homework', 'title' => 'Homework 1'],
            'official' => true,
            'topic' => ['id' => $this->topic->id, 'title' => $this->topic->title],
            'group' => ['id' => $this->group->id, 'name' => $this->group->name],
            'student' => ['id' => $student->id, 'full_name' => 'Alpha Student'],
            'attempt_number' => 1,
            'status' => 'waiting_for_teacher_review',
            'official_score_eligible' => true,
            'finalization_reason' => 'student_submit',
            'finalized_at' => '2026-09-30T07:00:00Z',
            'review' => ['waiting_answers' => 1, 'reviewed_answers' => 1],
            'review_due_at' => '2026-10-02T10:00:00Z',
            'review_overdue' => false,
            'score' => ['earned_points' => null, 'possible_points' => 20, 'normalized_score' => null],
        ], $data[0]);
        $this->assertSame($checked->id, $data[1]['id']);
        $this->assertSame(['id' => $blitz->id, 'type' => 'blitz', 'title' => $blitz->title], $data[1]['assessment']);
        $this->assertFalse($data[1]['official']);
        $this->assertNull($data[1]['review_due_at']);
        $this->assertSame(['earned_points' => 15, 'possible_points' => 20, 'normalized_score' => 75], $data[1]['score']);
    }

    public function test_filters_narrow_the_teachers_scope(): void
    {
        $alpha = $this->studentNamed('Alpha Student');
        $bravo = $this->studentNamed('Bravo Student');
        $charlie = $this->studentNamed('Charlie Student');
        $homework = $this->homeworkTask(['review_due_at' => now()->subMinute()]);
        $blitz = $this->blitzTask();
        $this->officialPair($homework, $blitz);
        $practice = $this->homeworkTask();
        $overdue = $this->submission($homework, $alpha, 'waiting_for_teacher_review');
        $checked = $this->submission($homework, $bravo, 'checked');
        $pending = $this->submission($practice, $alpha, 'submitted');
        $invalidated = $this->submission($blitz, $bravo, 'checked', ['official_score_eligible' => false]);
        $officialBlitz = $this->submission($blitz, $charlie, 'timed_out_finalized',
            ['submitted_at' => null, 'finalization_reason' => 'timeout_auto_submit']);
        // Another of the Teacher's Topics in a second Group.
        $secondGroup = Group::factory()->create(['institution_id' => $this->institution->id, 'created_by_user_id' => $this->admin->id]);
        GroupTeacherMembership::factory()->create(['institution_id' => $this->institution->id, 'group_id' => $secondGroup->id,
            'teacher_id' => $this->teacher->id, 'assigned_by_user_id' => $this->admin->id]);
        $secondTopic = Topic::factory()->active()->create(['institution_id' => $this->institution->id,
            'group_id' => $secondGroup->id, 'teacher_id' => $this->teacher->id]);
        $elsewhere = $this->submission($this->homeworkTask(topic: $secondTopic),
            $this->eligibleStudent($this->institution, $this->admin, $secondGroup), 'checked');
        $all = [$overdue, $checked, $pending, $invalidated, $officialBlitz, $elsewhere];

        $this->assertIds([$overdue, $checked], $this->submissionsRequest($this->teacher, ['assessment_id' => $homework->id]));
        $this->assertIds([$elsewhere], $this->submissionsRequest($this->teacher, ['topic_id' => $secondTopic->id]));
        $this->assertIds([$overdue, $checked, $pending, $invalidated, $officialBlitz], $this->submissionsRequest($this->teacher, ['group_id' => $this->group->id]));
        $this->assertIds([$elsewhere], $this->submissionsRequest($this->teacher, ['group_id' => $secondGroup->id]));
        $this->assertIds([$overdue, $pending], $this->submissionsRequest($this->teacher, ['student_id' => $alpha->id]));
        $this->assertIds([$overdue], $this->submissionsRequest($this->teacher, ['checking_status' => 'waiting_for_teacher_review']));
        $this->assertIds([$checked, $invalidated, $elsewhere], $this->submissionsRequest($this->teacher, ['checking_status' => 'checked']));
        $this->assertIds([$pending, $officialBlitz], $this->submissionsRequest($this->teacher, ['checking_status' => 'automatic_checking_pending']));
        $this->assertIds([$invalidated, $officialBlitz], $this->submissionsRequest($this->teacher, ['type' => 'blitz']));
        $this->assertIds([$overdue, $checked, $pending, $elsewhere], $this->submissionsRequest($this->teacher, ['type' => 'homework']));
        $this->assertIds([$overdue, $checked, $officialBlitz], $this->submissionsRequest($this->teacher, ['official' => 'true']));
        $this->assertIds([$pending, $invalidated, $elsewhere], $this->submissionsRequest($this->teacher, ['official' => 'false']));
        $this->assertIds([$overdue], $this->submissionsRequest($this->teacher, ['overdue' => 'true']));
        $this->assertIds([$overdue, $checked], $this->submissionsRequest($this->teacher, ['assessment_id' => $homework->id, 'official' => 'true']));
        $this->assertIds($all, $this->submissionsRequest($this->teacher));
        // Another Teacher's real work matches nothing, whichever of its ids the filter names.
        $otherTeacher = User::factory()->teacher($this->institution)->create(['must_change_password' => false]);
        $otherGroup = Group::factory()->create(['institution_id' => $this->institution->id, 'created_by_user_id' => $this->admin->id]);
        GroupTeacherMembership::factory()->create(['institution_id' => $this->institution->id, 'group_id' => $otherGroup->id,
            'teacher_id' => $otherTeacher->id, 'assigned_by_user_id' => $this->admin->id]);
        $otherTopic = Topic::factory()->active()->create(['institution_id' => $this->institution->id,
            'group_id' => $otherGroup->id, 'teacher_id' => $otherTeacher->id]);
        $otherHomework = $this->persistedHomework($this->institution, $otherTeacher, $otherTopic);
        $otherStudent = $this->eligibleStudent($this->institution, $this->admin, $otherGroup);
        $this->blitzAttempt($otherHomework, $otherStudent, $otherTeacher, ['status' => 'checked', 'possible_points' => '20.000000',
            'started_at' => now()->subHours(2), 'submitted_at' => now()->subHour(), 'finalized_at' => now()->subHour(),
            'locked_at' => now()->subHour(), 'finalization_reason' => 'student_submit', 'earned_points' => '1.00000000',
            'normalized_score' => '5.00000000', 'scoring_completed_at' => now()]);
        foreach (['assessment_id' => $otherHomework->id, 'topic_id' => $otherTopic->id, 'group_id' => $otherGroup->id,
            'student_id' => $otherStudent->id] as $filter => $id) {
            $this->submissionsRequest($this->teacher, [$filter => $id])->assertOk()->assertJsonPath('data', []);
        }
    }

    public function test_review_is_overdue_only_while_waiting_at_or_after_the_review_due_time(): void
    {
        $student = $this->studentNamed('Alpha Student');
        $due = $this->homeworkTask(['review_due_at' => now()]);
        $future = $this->homeworkTask(['review_due_at' => now()->addSecond()]);
        $none = $this->homeworkTask();
        $waitingDue = $this->submission($due, $student, 'waiting_for_teacher_review');
        $checkedDue = $this->submission($due, $student, 'checked');
        $waitingFuture = $this->submission($future, $student, 'waiting_for_teacher_review');
        $waitingNone = $this->submission($none, $student, 'waiting_for_teacher_review');

        $items = collect($this->submissionsRequest($this->teacher)->json('data'))->keyBy('id');

        $this->assertTrue($items[$waitingDue->id]['review_overdue']);
        $this->assertFalse($items[$checkedDue->id]['review_overdue']);
        $this->assertFalse($items[$waitingFuture->id]['review_overdue']);
        $this->assertFalse($items[$waitingNone->id]['review_overdue']);
        $this->assertNull($items[$waitingNone->id]['review_due_at']);
    }

    public function test_the_default_order_is_official_then_overdue_then_oldest_first(): void
    {
        $student = $this->studentNamed('Alpha Student');
        $official = $this->homeworkTask(['review_due_at' => now()->subDay()]);
        $this->officialPair($official);
        $practiceDue = $this->homeworkTask(['review_due_at' => now()->subDay()]);
        $practice = $this->homeworkTask();
        $expected = [
            $this->submission($official, $student, 'waiting_for_teacher_review', ['finalized_at' => now()->subHours(1)]),
            $this->submission($official, $student, 'checked', ['finalized_at' => now()->subHours(5)]),
            $this->submission($practiceDue, $student, 'waiting_for_teacher_review', ['finalized_at' => now()->subHours(1)]),
            $this->submission($practice, $student, 'checked', ['finalized_at' => now()->subHours(6)]),
            $this->submission($practice, $student, 'checked', ['finalized_at' => now()->subHours(2)]),
        ];

        $this->assertIds($expected, $this->submissionsRequest($this->teacher), ordered: true);
        $this->assertIds($expected, $this->submissionsRequest($this->teacher, ['sort' => 'default', 'direction' => 'desc']), ordered: true);
    }

    /** @return array<string, array{string, string}> */
    public static function explicitSorts(): array
    {
        return [
            'finalized ascending' => ['finalized_at', 'asc'], 'finalized descending' => ['finalized_at', 'desc'],
            'name ascending' => ['student_name', 'asc'], 'name descending' => ['student_name', 'desc'],
            'review due ascending' => ['review_due_at', 'asc'], 'review due descending' => ['review_due_at', 'desc'],
        ];
    }

    #[DataProvider('explicitSorts')]
    public function test_explicit_sorts_follow_direction_with_an_id_tie_break(string $sort, string $direction): void
    {
        $bravo = $this->studentNamed('Bravo Student');
        $alpha = $this->studentNamed('alpha Student');
        $early = $this->homeworkTask(['review_due_at' => now()->addDay()]);
        $late = $this->homeworkTask(['review_due_at' => now()->addDays(2)]);
        $undated = $this->homeworkTask();
        $rows = [
            'a' => $this->submission($early, $alpha, 'checked', ['finalized_at' => now()->subHours(3)]),
            'b' => $this->submission($late, $bravo, 'checked', ['finalized_at' => now()->subHours(1)]),
            'c' => $this->submission($undated, $alpha, 'checked', ['finalized_at' => now()->subHours(2)]),
            'd' => $this->submission($early, $bravo, 'checked', ['finalized_at' => now()->subHours(3)]),
        ];
        $keys = fn (array $order): array => array_map(fn (string $key) => $rows[$key], $order);
        $byId = fn (string ...$keys): array => collect($keys)->sortBy(fn (string $key) => $rows[$key]->id)->values()->all();
        $asc = match ($sort) {
            // a and d share finalized_at; the id breaks the tie.
            'finalized_at' => [...$byId('a', 'd'), 'c', 'b'],
            'student_name' => [...$byId('a', 'c'), ...$byId('b', 'd')],
            'review_due_at' => [...$byId('a', 'd'), 'b', 'c'],
        };
        $order = $direction === 'asc' ? $asc : ($sort === 'review_due_at'
            ? ['b', ...array_reverse($byId('a', 'd')), 'c'] // nulls stay last
            : array_reverse($asc));

        $this->assertIds($keys($order), $this->submissionsRequest($this->teacher, ['sort' => $sort, 'direction' => $direction]), ordered: true);
    }

    /** @return array<string, array{bool}> */
    public static function caseOnlyNames(): array
    {
        return ['lowercase name has the lower id' => [true], 'capitalized name has the lower id' => [false]];
    }

    #[DataProvider('caseOnlyNames')]
    public function test_names_that_differ_only_in_case_tie_and_fall_back_to_the_attempt_id(bool $lowercaseFirst): void
    {
        $homework = $this->homeworkTask();
        [$lowerId, $upperId] = $lowercaseFirst
            ? ['00000000-0000-7000-8000-000000000001', '00000000-0000-7000-8000-000000000002']
            : ['00000000-0000-7000-8000-000000000002', '00000000-0000-7000-8000-000000000001'];
        $lower = $this->submission($homework, $this->studentNamed('alpha Student'), 'checked', ['id' => $lowerId]);
        $upper = $this->submission($homework, $this->studentNamed('Alpha Student'), 'checked', ['id' => $upperId]);
        // Any case-sensitive order would put the same name first in both data sets.
        $expected = $lowercaseFirst ? [$lower, $upper] : [$upper, $lower];

        $this->assertIds($expected, $this->submissionsRequest($this->teacher, ['sort' => 'student_name']), ordered: true);
        $this->assertIds(array_reverse($expected), $this->submissionsRequest($this->teacher,
            ['sort' => 'student_name', 'direction' => 'desc']), ordered: true);
    }

    public function test_pages_carry_the_pagination_meta(): void
    {
        $homework = $this->homeworkTask();
        foreach (range(1, 5) as $hour) {
            $this->submission($homework, $this->studentNamed('Student '.$hour), 'checked', ['finalized_at' => now()->subHours($hour)]);
        }

        $this->submissionsRequest($this->teacher, ['per_page' => 2, 'page' => 3])->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.pagination', ['page' => 3, 'per_page' => 2, 'total' => 5, 'last_page' => 3]);
        $this->submissionsRequest($this->teacher)->assertJsonPath('meta.pagination.per_page', 25);
        $this->submissionsRequest($this->teacher, ['per_page' => 100])->assertOk();
    }

    /** @return array<string, array{array<string, mixed>, string, string}> */
    public static function invalidQueries(): array
    {
        return [
            'unknown parameter' => [['status' => 'checked'], '', 'status'],
            'malformed assessment id' => [['assessment_id' => 'not-a-uuid'], '', 'assessment_id'],
            'malformed topic id' => [['topic_id' => '12'], '', 'topic_id'],
            'malformed group id' => [['group_id' => 'x'], '', 'group_id'],
            'malformed student id' => [['student_id' => 'x'], '', 'student_id'],
            'unknown checking status' => [['checking_status' => 'pending'], '', 'checking_status'],
            'unknown type' => [['type' => 'quiz'], '', 'type'],
            'non-boolean official' => [['official' => 'yes'], '', 'official'],
            'overdue false' => [['overdue' => 'false'], '', 'overdue'],
            'unknown sort' => [['sort' => 'score'], '', 'sort'],
            'unknown direction' => [['direction' => 'up'], '', 'direction'],
            'page zero' => [['page' => 0], '', 'page'],
            'per page above maximum' => [['per_page' => 101], '', 'per_page'],
            'per page zero' => [['per_page' => 0], '', 'per_page'],
            'request body' => [[], '{}', 'body'],
        ];
    }

    /** @param array<string, mixed> $query */
    #[DataProvider('invalidQueries')]
    public function test_invalid_requests_are_rejected(array $query, string $body, string $field): void
    {
        $this->submissionsRequest($this->teacher, $query, $body)->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')->assertJsonValidationErrors($field);
    }

    public function test_the_number_of_queries_does_not_grow_with_the_page(): void
    {
        $counts = [];
        $counting = null;
        DB::listen(function () use (&$counts, &$counting): void {
            if ($counting !== null) {
                $counts[$counting] = ($counts[$counting] ?? 0) + 1;
            }
        });
        foreach ([1, 6] as $size) {
            $homework = $this->homeworkTask();
            foreach (range(1, $size) as $index) {
                $student = $this->studentNamed("Student {$size}-{$index}");
                $this->answerInState($this->submission($homework, $student, 'waiting_for_teacher_review'), 'waiting_for_teacher_review');
            }
            $counting = $size;
            $this->submissionsRequest($this->teacher, ['assessment_id' => $homework->id])->assertOk()->assertJsonCount($size, 'data');
            $counting = null;
        }

        $this->assertSame($counts[1], $counts[6]);
    }

    private function officialPair(Assessment $homework, ?Assessment $blitz = null): void
    {
        TopicResultPair::factory()->create([
            'institution_id' => $this->institution->id, 'topic_id' => $homework->topic_id,
            'homework_assessment_id' => $homework->id, 'blitz_assessment_id' => $blitz?->id,
            'designated_by_user_id' => $this->teacher->id,
        ]);
    }

    /** @param list<AssessmentAttempt> $expected */
    private function assertIds(array $expected, TestResponse $response, bool $ordered = false): void
    {
        $response->assertOk();
        $actual = array_column($response->json('data'), 'id');
        $expectedIds = array_map(fn ($attempt): string => $attempt->id, $expected);
        if (! $ordered) {
            sort($actual);
            sort($expectedIds);
        }
        $this->assertSame($expectedIds, $actual);
    }
}
