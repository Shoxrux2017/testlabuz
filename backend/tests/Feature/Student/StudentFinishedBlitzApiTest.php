<?php

namespace Tests\Feature\Student;

use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzAttemptException;
use App\Models\BlitzTask;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * S09-BE-007C: a Student lists the finished Blitz tasks with the counting Attempt's result and
 * feedback when results are released automatically (docs/09 §20.6).
 */
class StudentFinishedBlitzApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/student/blitz/finished';

    private const HIDDEN = ['visible' => false, 'normalized_score' => null, 'feedback' => []];

    private Institution $institution;

    private User $student;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        $this->institution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $this->institution->id, 'student_result_release_mode' => 'automatic']);
        $this->student = $this->studentUser();
    }

    public function test_the_route_is_registered_once_before_the_blitz_read_behind_the_student_gates(): void
    {
        $uris = collect(Route::getRoutes())->map(fn ($route): string => $route->uri())->values();
        $finished = $uris->search('api/v1/student/blitz/finished');
        $this->assertSame(1, $uris->filter(fn (string $uri): bool => $uri === 'api/v1/student/blitz/finished')->count());
        $this->assertLessThan($uris->search('api/v1/student/blitz/{blitz}'), $finished);
        $route = collect(Route::getRoutes())->first(fn ($route): bool => $route->uri() === 'api/v1/student/blitz/finished');
        $this->assertSame(['GET', 'HEAD'], $route->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'], $route->middleware());

        $this->getJson(self::URI)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $teacher = User::factory()->teacher($this->institution)->create(['must_change_password' => false]);
        $this->finished([], $teacher)->assertForbidden()->assertJsonPath('code', 'forbidden');
    }

    /** @return array<string, array{array<string, mixed>, string, string}> */
    public static function invalidRequests(): array
    {
        return [
            'unknown parameter' => [['status' => 'closed'], '', 'status'],
            'page zero' => [['page' => 0], '', 'page'],
            'page text' => [['page' => 'first'], '', 'page'],
            'per_page above 100' => [['per_page' => 101], '', 'per_page'],
            'per_page zero' => [['per_page' => 0], '', 'per_page'],
            'body' => [[], '{}', 'body'],
        ];
    }

    /** @param array<string, mixed> $query */
    #[DataProvider('invalidRequests')]
    public function test_the_list_takes_only_page_and_per_page(array $query, string $body, string $error): void
    {
        $response = $this->finished($query, body: $body);

        $response->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame([$error], array_keys($response->json('errors')));
    }

    public function test_only_the_students_activated_and_finished_blitz_tasks_are_listed(): void
    {
        $closed = $this->blitz('closed');
        $archived = $this->blitz('archived_after_close');
        foreach (['active', 'scheduled', 'draft', 'archived_from_draft'] as $state) {
            $this->blitz($state);
        }
        $this->blitz('closed', recipient: $this->studentUser());
        $this->blitz('closed', assigned: false);
        $foreign = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $foreign->id]);
        $this->blitz('closed', recipient: User::factory()->student($foreign)->create());

        $this->assertEqualsCanonicalizing([$closed->id, $archived->id], array_column($this->finished()->assertOk()->json('data'), 'id'));
    }

    public function test_the_list_is_ordered_by_close_time_then_id_and_paged(): void
    {
        // Activation and archive times deliberately disagree with the close order.
        $older = $this->blitz('closed', closedAt: now()->subDays(2), activatedAt: now()->subDays(2)->subMinutes(5));
        [$first, $second] = [$this->blitz('closed', closedAt: now()->subDay()), $this->blitz('closed', closedAt: now()->subDay())];
        $newest = $this->blitz('archived_after_close', closedAt: now()->subHour(), activatedAt: now()->subDays(5));
        $archivedLate = $this->blitz('archived_after_close', closedAt: now()->subDays(3), archivedAt: now()->subMinute());
        $tied = collect([$first, $second])->sortByDesc('id')->values();

        $this->assertSame([$newest->id, $tied[0]->id, $tied[1]->id, $older->id, $archivedLate->id],
            array_column($this->finished()->json('data'), 'id'));
        $this->assertSame(['archived', '2026-09-27T10:00:00Z'], [$this->item($archivedLate)['status'], $this->item($archivedLate)['closed_at']]);
        $page = $this->finished(['page' => 2, 'per_page' => 3])->assertOk();
        $this->assertSame([$older->id, $archivedLate->id], array_column($page->json('data'), 'id'));
        $this->assertSame(['page' => 2, 'per_page' => 3, 'total' => 5, 'last_page' => 2], $page->json('meta.pagination'));
        $this->assertSame(['page' => 1, 'per_page' => 25, 'total' => 5, 'last_page' => 1], $this->finished()->json('meta.pagination'));
        // P3-4: the upper bound is accepted, and a page past the end is empty.
        $this->assertCount(5, $this->finished(['per_page' => 100])->assertOk()->json('data'));
        $past = $this->finished(['page' => 3, 'per_page' => 3])->assertOk();
        $this->assertSame([[], ['page' => 3, 'per_page' => 3, 'total' => 5, 'last_page' => 2]], [$past->json('data'), $past->json('meta.pagination')]);
    }

    public function test_a_checked_normal_attempt_shows_its_score_and_feedback_by_question_position(): void
    {
        $blitz = $this->blitz('closed');
        $attempt = $this->attempt($blitz, 1, 'checked');
        $late = $this->question($blitz, 2);
        $early = $this->question($blitz, 1);
        $silent = $this->question($blitz, 3);
        $this->reviewedAnswer($attempt, $late, 'Second remark.');
        $this->reviewedAnswer($attempt, $early, 'First remark.');
        $this->reviewedAnswer($attempt, $silent, null);

        $item = $this->item($blitz);

        $this->assertSame([
            'id' => $blitz->id, 'topic' => ['id' => $blitz->topic_id, 'title' => $blitz->topic->title], 'title' => $blitz->title,
            'status' => 'closed', 'closed_at' => '2026-09-30T10:00:00Z', 'attempt_exception' => false,
            'result' => ['attempt_number' => 1, 'visible' => true, 'normalized_score' => 75, 'feedback' => [
                ['question_id' => $early->id, 'position' => 1, 'text' => 'First remark.'],
                ['question_id' => $late->id, 'position' => 2, 'text' => 'Second remark.'],
            ]],
        ], $item);
    }

    public function test_an_archived_blitz_still_shows_the_released_result_and_feedback(): void
    {
        $blitz = $this->blitz('archived_after_close');
        $attempt = $this->attempt($blitz, 1, 'checked');
        $question = $this->question($blitz, 1);
        $this->reviewedAnswer($attempt, $question, 'Archived remark.');

        $item = $this->item($blitz);

        $this->assertSame('archived', $item['status']);
        $this->assertSame(['attempt_number' => 1, 'visible' => true, 'normalized_score' => 75, 'feedback' => [
            ['question_id' => $question->id, 'position' => 1, 'text' => 'Archived remark.'],
        ]], $item['result']);
    }

    public function test_attempts_that_are_not_checked_stay_hidden_with_their_feedback(): void
    {
        foreach (['waiting_for_teacher_review', 'submitted', 'timed_out_finalized'] as $status) {
            $blitz = $this->blitz('closed');
            $attempt = $this->attempt($blitz, 1, $status);
            $this->reviewedAnswer($attempt, $this->question($blitz, 1), 'Partial remark.');

            $this->assertSame(['attempt_number' => 1] + self::HIDDEN, $this->item($blitz)['result'], $status);
        }
    }

    public function test_a_student_who_never_started_has_no_result(): void
    {
        $blitz = $this->blitz('closed');

        $this->assertSame([false, null], [$this->item($blitz)['attempt_exception'], $this->item($blitz)['result']]);
    }

    public function test_after_an_exception_only_the_checked_replacement_counts(): void
    {
        $blitz = $this->blitz('closed');
        $normal = $this->attempt($blitz, 1, 'checked', ['official_score_eligible' => false, 'normalized_score' => '100.00000000',
            'earned_points' => '20.00000000']);
        $this->reviewedAnswer($normal, $this->question($blitz, 1), 'Invalidated remark.');
        $exception = BlitzAttemptException::factory()->create(['assessment_id' => $blitz->id,
            'assessment_student_id' => $normal->assessment_student_id, 'invalidated_attempt_id' => $normal->id,
            'granted_by_user_id' => $blitz->teacher_id]);

        $this->assertSame([true, null], [$this->item($blitz)['attempt_exception'], $this->item($blitz)['result']]);

        $replacement = $this->attempt($blitz, 2, 'checked', ['normalized_score' => '50.00000000', 'earned_points' => '10.00000000']);
        $exception->update(['replacement_attempt_id' => $replacement->id]);
        $this->reviewedAnswer($replacement, $this->question($blitz, 2), 'Replacement remark.');

        $item = $this->item($blitz);
        $this->assertTrue($item['attempt_exception']);
        $this->assertSame(['attempt_number' => 2, 'visible' => true, 'normalized_score' => 50, 'feedback' => [
            ['question_id' => $this->questionAt($blitz, 2)->id, 'position' => 2, 'text' => 'Replacement remark.'],
        ]], $item['result']);
    }

    public function test_a_classmate_on_the_same_blitz_never_changes_the_students_item(): void
    {
        $blitz = $this->blitz('closed');
        $classmate = $this->studentUser();
        AssessmentStudent::factory()->create(['assessment_id' => $blitz->id, 'student_id' => $classmate->id,
            'assigned_by_user_id' => $blitz->teacher_id]);
        $first = $this->question($blitz, 1);
        $second = $this->question($blitz, 2);
        $theirs = $this->attempt($blitz, 1, 'checked', ['official_score_eligible' => false, 'normalized_score' => '90.00000000',
            'earned_points' => '18.00000000'], $classmate);
        $this->reviewedAnswer($theirs, $first, 'Classmate remark.');
        $exception = BlitzAttemptException::factory()->create(['assessment_id' => $blitz->id,
            'assessment_student_id' => $theirs->assessment_student_id, 'invalidated_attempt_id' => $theirs->id,
            'granted_by_user_id' => $blitz->teacher_id]);
        $replacement = $this->attempt($blitz, 2, 'checked', ['normalized_score' => '95.00000000', 'earned_points' => '19.00000000'], $classmate);
        $exception->update(['replacement_attempt_id' => $replacement->id]);
        $this->reviewedAnswer($replacement, $second, 'Classmate replacement remark.');

        $this->assertSame([false, null], [$this->item($blitz)['attempt_exception'], $this->item($blitz)['result']]);

        $mine = $this->attempt($blitz, 1, 'checked');
        $this->reviewedAnswer($mine, $second, 'My remark.');

        $this->assertSame(['attempt_exception' => false, 'result' => ['attempt_number' => 1, 'visible' => true, 'normalized_score' => 75,
            'feedback' => [['question_id' => $second->id, 'position' => 2, 'text' => 'My remark.']]]],
            array_intersect_key($this->item($blitz), ['attempt_exception' => true, 'result' => true]));
    }

    public function test_nothing_is_visible_unless_results_are_released_automatically(): void
    {
        $blitz = $this->blitz('closed');
        $this->reviewedAnswer($this->attempt($blitz, 1, 'checked'), $this->question($blitz, 1), 'Hidden remark.');

        foreach (['manual_teacher', null] as $mode) {
            InstitutionSetting::query()->whereKey($this->institution->id)->update(['student_result_release_mode' => $mode]);

            $this->assertSame(['attempt_number' => 1] + self::HIDDEN, $this->item($blitz)['result'], (string) $mode);
        }
    }

    public function test_the_list_query_count_stays_bounded_as_rows_grow(): void
    {
        $this->finishedBlitzWithFeedback();
        DB::enableQueryLog();
        $this->finished()->assertOk()->assertJsonCount(1, 'data');
        $small = count(DB::getQueryLog());
        for ($index = 0; $index < 11; $index++) {
            $this->finishedBlitzWithFeedback();
        }
        DB::flushQueryLog();

        $large = $this->finished()->assertOk()->assertJsonCount(12, 'data');

        $this->assertLessThanOrEqual($small + 2, count(DB::getQueryLog()));
        $this->assertSame(array_fill(0, 12, 1), array_map(fn (array $item): int => count($item['result']['feedback']), $large->json('data')));
        DB::disableQueryLog();
    }

    private function finishedBlitzWithFeedback(): void
    {
        $blitz = $this->blitz('closed');
        $this->reviewedAnswer($this->attempt($blitz, 1, 'checked'), $this->question($blitz, 1), 'Remark.');
    }

    private function studentUser(): User
    {
        return User::factory()->student($this->institution)->create(['must_change_password' => false]);
    }

    /** A Blitz in the recipient's Institution, assigned to the recipient (by default the test's Student). */
    private function blitz(
        string $state,
        ?CarbonInterface $closedAt = null,
        ?User $recipient = null,
        bool $assigned = true,
        ?CarbonInterface $activatedAt = null,
        ?CarbonInterface $archivedAt = null,
    ): Assessment {
        $recipient ??= $this->student;
        $assessment = Assessment::factory()->blitz()->create(['institution_id' => $recipient->institution_id]);
        $closedAt ??= now();
        $activatedAt ??= $closedAt->copy()->subMinutes(30);
        $activated = ['created_at' => $activatedAt->copy()->subHour(), 'activated_at' => $activatedAt];
        match ($state) {
            'closed' => BlitzTask::factory()->closedIndividual()->create(['assessment_id' => $assessment->id, 'closed_at' => $closedAt] + $activated),
            'archived_after_close' => BlitzTask::factory()->archivedAfterCloseIndividual()->create(['assessment_id' => $assessment->id,
                'closed_at' => $closedAt, 'archived_at' => $archivedAt ?? $closedAt->copy()->addMinute()] + $activated),
            'active' => BlitzTask::factory()->activeIndividual()->create(['assessment_id' => $assessment->id]),
            'scheduled' => BlitzTask::factory()->scheduled()->create(['assessment_id' => $assessment->id]),
            'draft' => BlitzTask::factory()->draft()->create(['assessment_id' => $assessment->id]),
            'archived_from_draft' => BlitzTask::factory()->archivedFromDraft()->create(['assessment_id' => $assessment->id]),
        };
        if ($assigned) {
            AssessmentStudent::factory()->create(['assessment_id' => $assessment->id, 'student_id' => $recipient->id,
                'assigned_by_user_id' => $assessment->teacher_id]);
        }

        return $assessment->fresh(['topic']);
    }

    /** @param array<string, mixed> $attributes */
    private function attempt(Assessment $blitz, int $number, string $status, array $attributes = [], ?User $student = null): AssessmentAttempt
    {
        $recipient = AssessmentStudent::query()->where('assessment_id', $blitz->id)->where('student_id', ($student ?? $this->student)->id)->sole();
        $finalizedAt = now()->subMinutes(40 - $number);

        return AssessmentAttempt::factory()->create(array_merge([
            'assessment_student_id' => $recipient->id, 'attempt_number' => $number, 'status' => $status,
            'started_at' => $finalizedAt->copy()->subMinutes(5), 'finalized_at' => $finalizedAt, 'locked_at' => $finalizedAt,
            'submitted_at' => $status === 'timed_out_finalized' ? null : $finalizedAt,
            'finalization_reason' => $status === 'timed_out_finalized' ? 'timeout_auto_submit' : 'student_submit',
            'possible_points' => '20.000000',
            'earned_points' => $status === 'checked' ? '15.00000000' : null,
            'normalized_score' => $status === 'checked' ? '75.00000000' : null,
            'scoring_completed_at' => $status === 'checked' ? now()->subMinutes(10) : null,
        ], $attributes))->fresh();
    }

    private function question(Assessment $blitz, int $position): Question
    {
        return Question::factory()->openWritten()->create(['institution_id' => $blitz->institution_id, 'assessment_id' => $blitz->id,
            'position' => $position]);
    }

    private function questionAt(Assessment $blitz, int $position): Question
    {
        return Question::query()->where('assessment_id', $blitz->id)->where('position', $position)->sole();
    }

    private function reviewedAnswer(AssessmentAttempt $attempt, Question $question, ?string $feedback): void
    {
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        DB::table('attempt_answers')->where('id', $answer->id)->update(['checking_status' => 'teacher_checked',
            'awarded_points' => '1.00000000', 'feedback' => $feedback, 'checked_at' => now()]);
    }

    /** @return array<string, mixed> */
    private function item(Assessment $blitz): array
    {
        return collect($this->finished()->assertOk()->json('data'))->firstWhere('id', $blitz->id);
    }

    /** @param array<string, mixed> $query */
    private function finished(array $query = [], ?User $as = null, string $body = ''): TestResponse
    {
        $user = $as ?? $this->student;
        $server = ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$user->createToken('finished-blitz-test')->plainTextToken];
        try {
            return $this->call('GET', self::URI.($query === [] ? '' : '?'.http_build_query($query)), [], [], [], $server, $body);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }
}
