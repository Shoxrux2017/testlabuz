<?php

namespace Tests\Feature\Student;

use App\Actions\Checking\CheckFrozenAttempt;
use App\Actions\Teacher\ReviewTeacherSubmission;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\InstitutionSetting;
use App\Models\OfficialTaskScore;
use App\Models\Question;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Checking\OfficialTaskScoreResolver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkAnswerContext;
use Tests\TestCase;

/**
 * S09-BE-007B: with automatic result release a Student reads the score of each checked Homework
 * Attempt, the Teacher's feedback on its answers and the official Homework score (docs/09 §17).
 */
class StudentHomeworkResultsApiTest extends TestCase
{
    use BuildsStudentHomeworkAnswerContext;
    use RefreshDatabase;

    private const HIDDEN = ['visible' => false, 'normalized_score' => null];

    private User $student;

    private HomeworkAssignment $homework;

    private AssessmentAttempt $attempt;

    private User $teacher;

    private Question $trueFalse;

    private Question $essay;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        [$this->student, $this->homework, $this->attempt] = $this->answerContext();
        $this->teacher = $this->homework->assessment->teacher;
        GroupTeacherMembership::factory()->create([
            'institution_id' => $this->teacher->institution_id, 'group_id' => $this->homework->assessment->topic->group_id,
            'teacher_id' => $this->teacher->id, 'assigned_by_user_id' => $this->teacher->id,
        ]);
        // 1 automatic + 7 manual = the Attempt's 8 possible points.
        $this->trueFalse = $this->answerQuestion($this->homework, 'true_false', 1);
        $this->essay = $this->answerQuestion($this->homework, 'open_written', 2);
        $this->essay->update(['points' => '7.000000']);
    }

    public function test_a_checked_attempt_shows_its_score_and_feedback_when_results_are_released(): void
    {
        $this->release('automatic');
        $key = (string) Str::uuid();
        $unanswered = $this->answerQuestion($this->homework, 'open_written', 3);
        $unanswered->update(['points' => '0.000000']);
        $this->answerAll($this->attempt);
        // Submit runs checking after its response; the essay then waits for review.
        $this->submit($this->attempt, $key)->assertOk()->assertJsonPath('data.result', self::HIDDEN);
        $this->review($this->attempt, 5, "  Well argued.\n");

        // 1 + 5 = 6 of 8 points.
        $visible = ['visible' => true, 'normalized_score' => 75];
        $attempt = $this->attemptRead($this->attempt)->assertOk();
        $attempt->assertJsonPath('data.result', $visible);
        // The unanswered Question has no answer entry, so it has no feedback either.
        $this->assertSame([$this->trueFalse->id, $this->essay->id], array_column($attempt->json('data.answers'), 'question_id'));
        $this->assertSame([null, 'Well argued.'], array_column($attempt->json('data.answers'), 'feedback'));
        $this->submit($this->attempt, $key)->assertOk()->assertJsonPath('data.result', $visible)
            ->assertJsonPath('data.answers.1.feedback', 'Well argued.');
        $this->assertSame([['attempt_id' => $this->attempt->id, 'attempt_number' => 1, 'status' => 'checked', 'result' => $visible]],
            $this->detail()->assertOk()->json('data.attempt_results'));
    }

    public function test_attempts_that_are_not_checked_stay_hidden_with_their_feedback(): void
    {
        $this->release('automatic');
        $second = $this->answerQuestion($this->homework, 'open_written', 3);
        $this->answerAll($this->attempt);
        $this->answerRequest($this->student, $this->attempt, $second, $this->answerPayload($second))->assertOk();
        $this->freeze($this->attempt);
        $this->attemptRead($this->attempt)->assertOk()->assertJsonPath('data.status', 'submitted')->assertJsonPath('data.result', self::HIDDEN);
        $this->assertSame([['attempt_id' => $this->attempt->id, 'attempt_number' => 1, 'status' => 'submitted', 'result' => self::HIDDEN]],
            $this->detail()->json('data.attempt_results'));
        $this->assertTrue(app(CheckFrozenAttempt::class)($this->attempt->id));
        // Only the essay is reviewed, so the Attempt keeps waiting for the second answer.
        $this->review($this->attempt, 5, 'Partial feedback.');

        $waiting = $this->attemptRead($this->attempt)->assertOk();

        $waiting->assertJsonPath('data.status', 'waiting_for_teacher_review')->assertJsonPath('data.result', self::HIDDEN);
        $this->assertSame([null, null, null], array_column($waiting->json('data.answers'), 'feedback'));
        $this->assertSame('Partial feedback.', AttemptAnswer::query()->where('question_id', $this->essay->id)->sole()->feedback);
    }

    public function test_nothing_is_visible_unless_results_are_released_automatically(): void
    {
        $this->designate();
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $this->review($this->attempt, 5, 'Well argued.');
        $this->assertDatabaseCount('official_task_scores', 1);

        foreach (['manual_teacher', null] as $mode) {
            $this->release($mode);

            $attempt = $this->attemptRead($this->attempt)->assertOk();
            $attempt->assertJsonPath('data.result', self::HIDDEN);
            $this->assertSame([null, null], array_column($attempt->json('data.answers'), 'feedback'));
            $detail = $this->detail()->assertOk();
            $this->assertSame([false, null, self::HIDDEN], [$detail->json('data.score_visible'), $detail->json('data.official_score'),
                $detail->json('data.attempt_results.0.result')]);
            $this->assertSame([false, null], [$this->listItem()['score_visible'], $this->listItem()['official_score']]);
        }
    }

    public function test_the_official_homework_score_shows_when_it_is_ready_and_released(): void
    {
        $this->release('automatic');
        $this->designate();
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        // #1: 1 + 2 = 3 of 8 = 37.5; #2: 1 + 5 = 6 of 8 = 75.
        $this->review($this->attempt, 2, null);
        $second = AssessmentAttempt::factory()->create(['assessment_student_id' => $this->attempt->assessment_student_id,
            'attempt_number' => 2, 'possible_points' => '8.000000', 'started_at' => now()])->fresh();
        $this->answerAll($second);
        $this->freezeAndCheck($second);
        $this->review($second, 5, null);

        $official = ['normalized_score' => 75, 'attempt_number' => 2];
        $detail = $this->detail()->assertOk();
        $this->assertSame([true, $official], [$detail->json('data.score_visible'), $detail->json('data.official_score')]);
        $this->assertSame([true, $official], [$this->listItem()['score_visible'], $this->listItem()['official_score']]);
    }

    public function test_a_classmates_official_row_attempts_and_feedback_never_change_the_students_results(): void
    {
        $this->release('automatic');
        $this->designate();
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $this->review($this->attempt, 2, 'Own remark.');
        $reads = fn (): array => [$this->listItem(), $this->detail()->assertOk()->json('data'), $this->attemptRead($this->attempt)->assertOk()->json('data')];
        $own = $reads();
        $this->assertSame(['normalized_score' => 37.5, 'attempt_number' => 1], $own[0]['official_score']);

        // A classmate on the same Homework with a better reviewed Attempt, feedback and a stored official row.
        $classmate = AssessmentStudent::factory()->create(['assessment_id' => $this->homework->assessment_id, 'assigned_by_user_id' => $this->teacher->id]);
        $theirs = AssessmentAttempt::factory()->create(['assessment_student_id' => $classmate->id, 'status' => 'checked',
            'started_at' => now()->subHour(), 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit', 'possible_points' => '8.000000', 'earned_points' => '7.00000000',
            'normalized_score' => '87.50000000', 'scoring_completed_at' => now()]);
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $theirs->id, 'question_id' => $this->essay->id]);
        DB::table('attempt_answers')->where('id', $answer->id)->update(['checking_status' => 'teacher_checked',
            'awarded_points' => '7.00000000', 'feedback' => 'Classmate remark.', 'checked_by_user_id' => $this->teacher->id, 'checked_at' => now()]);
        OfficialTaskScore::factory()->create(['institution_id' => $classmate->institution_id, 'assessment_id' => $classmate->assessment_id,
            'student_id' => $classmate->student_id, 'official_attempt_id' => $theirs->id, 'normalized_score' => '87.50000000',
            'selection_policy_code' => 'highest_valid_completed', 'selected_at' => now()]);

        $this->assertSame($own, $reads());
    }

    public function test_no_official_score_shows_for_a_practice_task_or_an_unconfirmed_row(): void
    {
        $this->release('automatic');
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $this->review($this->attempt, 5, null);
        $this->assertNoOfficialScore();

        // A row matching the live evaluation does not count while the pair names another Homework.
        $other = Assessment::factory()->homework()->create(['institution_id' => $this->student->institution_id,
            'topic_id' => $this->homework->assessment->topic_id]);
        $pair = TopicResultPair::factory()->create(['homework_assessment_id' => $other->id]);
        $row = OfficialTaskScore::factory()->create(['official_attempt_id' => $this->attempt->id, 'normalized_score' => '75.00000000']);
        $this->assertNoOfficialScore();

        // Designated and ready by the live rule, but not stored yet.
        $row->delete();
        $pair->update(['homework_assessment_id' => $this->homework->assessment_id]);
        $this->assertNoOfficialScore();

        $this->resolve();
        $row = OfficialTaskScore::query()->sole();
        $row->update(['normalized_score' => '70.00000000']);
        $this->assertNoOfficialScore();

        $row->update(['normalized_score' => '75.00000000']);
        $this->detail()->assertJsonPath('data.score_visible', true);
        // A later Attempt that could still overtake withdraws the score.
        $second = AssessmentAttempt::factory()->create(['assessment_student_id' => $this->attempt->assessment_student_id,
            'attempt_number' => 2, 'possible_points' => '8.000000', 'started_at' => now()])->fresh();
        $this->answerRequest($this->student, $second, $this->essay, $this->answerPayload($this->essay))->assertOk();
        $this->freezeAndCheck($second);
        $this->assertDatabaseCount('official_task_scores', 0);
        $this->assertNoOfficialScore();
        $this->assertSame([['checked', 75], ['waiting_for_teacher_review', null]], array_map(
            fn (array $row): array => [$row['status'], $row['result']['normalized_score']], $this->detail()->json('data.attempt_results')));
    }

    public function test_an_in_progress_attempt_has_a_hidden_result_on_start_and_read(): void
    {
        $this->release('automatic');
        $this->attempt->delete();

        $start = $this->answerHttp($this->student, 'POST', '/api/v1/student/homework/'.$this->homework->assessment_id.'/attempts', '',
            'application/json', ['HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid()]);

        $start->assertCreated()->assertJsonPath('data.result', self::HIDDEN)->assertJsonPath('data.answers', []);
        $saved = AssessmentAttempt::query()->findOrFail($start->json('data.id'));
        $this->answerAll($saved);
        $this->assertSame([null, null], array_column($this->attemptRead($saved)->json('data.answers'), 'feedback'));
        $this->attemptRead(AssessmentAttempt::query()->findOrFail($start->json('data.id')))->assertJsonPath('data.result', self::HIDDEN);
        $this->assertSame([], $this->detail()->json('data.attempt_results'));
    }

    public function test_the_homework_responses_have_exactly_the_stage_nine_keys(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);

        $this->assertSame(['id', 'topic', 'title', 'status', 'deadline_at', 'attempts', 'my_status', 'score_visible', 'official_score'],
            array_keys($this->listItem()));
        $this->assertSame(['id', 'topic', 'title', 'description', 'student_instructions', 'status', 'deadline_at', 'total_possible_points',
            'attempts', 'my_status', 'score_visible', 'official_score', 'attempt_results', 'questions'], array_keys($this->detail()->json('data')));
        $attempt = $this->attemptRead($this->attempt)->json('data');
        $this->assertSame(['id', 'assessment_id', 'attempt_number', 'status', 'started_at', 'submitted_at', 'finalized_at',
            'finalization_reason', 'deadline_at', 'result', 'questions', 'answers'], array_keys($attempt));
        $this->assertSame(['question_id', 'type', 'answer', 'updated_at', 'feedback'], array_keys($attempt['answers'][0]));
    }

    public function test_an_answer_save_response_keeps_its_stage_seven_keys(): void
    {
        $this->release('automatic');

        $saved = $this->answerRequest($this->student, $this->attempt, $this->trueFalse, ['type' => 'true_false', 'value' => true]);

        $this->assertSame(['question_id', 'type', 'answer', 'updated_at'], array_keys($saved->assertOk()->json('data')));
    }

    public function test_the_list_reads_released_official_scores_in_a_bounded_number_of_queries(): void
    {
        $this->release('automatic');
        $this->officialHomeworkWithHistory();
        [$small, $smallQueries] = $this->recordListQueries();
        // The fixture's own practice Homework is listed too.
        $this->assertCount(2, $small->json('data'));
        for ($index = 0; $index < 11; $index++) {
            $this->officialHomeworkWithHistory();
        }

        [$large, $largeQueries] = $this->recordListQueries();

        $this->assertCount(13, $large->json('data'));
        $this->assertSame(array_fill(0, 12, ['normalized_score' => 50, 'attempt_number' => 1]),
            array_values(array_filter(array_column($large->json('data'), 'official_score'))));
        $this->assertLessThanOrEqual(count($smallQueries) + 2, count($largeQueries));
    }

    /**
     * Another official Homework of this Student in its own Topic: #1 checked (4 of 8 = 50), #2
     * waiting on a 3-point answer (bound 3 of 8 = 37.5), so the stored score stays confirmed.
     */
    private function officialHomeworkWithHistory(): void
    {
        $assessment = Assessment::factory()->homework()->create(['institution_id' => $this->student->institution_id,
            'total_possible_points' => '8.000000']);
        HomeworkAssignment::factory()->closed()->create(['assessment_id' => $assessment->id]);
        TopicResultPair::factory()->create(['homework_assessment_id' => $assessment->id]);
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $assessment->id, 'student_id' => $this->student->id,
            'assigned_by_user_id' => $assessment->teacher_id]);
        $frozen = ['submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(), 'finalization_reason' => 'student_submit',
            'possible_points' => '8.000000', 'started_at' => now()->subHour()];
        $checked = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id, 'status' => 'checked',
            'earned_points' => '4.00000000', 'normalized_score' => '50.00000000', 'scoring_completed_at' => now()] + $frozen);
        $waiting = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id, 'attempt_number' => 2,
            'status' => 'waiting_for_teacher_review'] + $frozen);
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $waiting->id]);
        Question::query()->whereKey($answer->question_id)->update(['points' => '3.000000']);
        DB::table('attempt_answers')->where('id', $answer->id)->update(['checking_status' => 'waiting_for_teacher_review']);
        app(OfficialTaskScoreResolver::class)->resolve($assessment->fresh(), $recipient,
            AssessmentAttempt::query()->where('assessment_student_id', $recipient->id)->get(), now());
        $this->assertSame($checked->id, OfficialTaskScore::query()->where('assessment_id', $assessment->id)->sole()->official_attempt_id);
    }

    private function assertNoOfficialScore(): void
    {
        $this->assertSame([false, null], [$this->detail()->json('data.score_visible'), $this->detail()->json('data.official_score')]);
        $this->assertSame([false, null], [$this->listItem()['score_visible'], $this->listItem()['official_score']]);
    }

    private function release(?string $mode): void
    {
        InstitutionSetting::query()->where('institution_id', $this->student->institution_id)->update(['student_result_release_mode' => $mode]);
    }

    private function designate(): void
    {
        TopicResultPair::factory()->create(['homework_assessment_id' => $this->homework->assessment_id]);
    }

    private function resolve(): void
    {
        $recipient = AssessmentStudent::query()->findOrFail($this->attempt->assessment_student_id);
        app(OfficialTaskScoreResolver::class)->resolve(Assessment::query()->findOrFail($this->homework->assessment_id), $recipient,
            AssessmentAttempt::query()->where('assessment_student_id', $recipient->id)->get(), now());
    }

    private function answerAll(AssessmentAttempt $attempt): void
    {
        $this->answerRequest($this->student, $attempt, $this->trueFalse, ['type' => 'true_false', 'value' => true])->assertOk();
        $this->answerRequest($this->student, $attempt, $this->essay, $this->answerPayload($this->essay))->assertOk();
    }

    private function freeze(AssessmentAttempt $attempt): void
    {
        DB::table('assessment_attempts')->where('id', $attempt->id)->update([
            'status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit',
        ]);
    }

    private function freezeAndCheck(AssessmentAttempt $attempt): void
    {
        $this->freeze($attempt);
        $this->assertTrue(app(CheckFrozenAttempt::class)($attempt->id));
    }

    /** The Teacher reviews the essay answer of the Attempt. */
    private function review(AssessmentAttempt $attempt, int $points, ?string $feedback): void
    {
        $essay = AttemptAnswer::query()->where('attempt_id', $attempt->id)->where('question_id', $this->essay->id)->sole();
        app(ReviewTeacherSubmission::class)($this->teacher, $attempt->id,
            [['answer_id' => $essay->id, 'awarded_points' => $points, 'feedback' => $feedback === null ? null : trim($feedback)]]);
    }

    private function submit(AssessmentAttempt $attempt, string $key): TestResponse
    {
        return $this->answerHttp($this->student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', '',
            'application/json', ['HTTP_IDEMPOTENCY_KEY' => $key]);
    }

    private function attemptRead(AssessmentAttempt $attempt): TestResponse
    {
        return $this->answerHttp($this->student, 'GET', '/api/v1/student/attempts/'.$attempt->id);
    }

    private function detail(): TestResponse
    {
        return $this->answerHttp($this->student, 'GET', '/api/v1/student/homework/'.$this->homework->assessment_id);
    }

    /** @return array<string, mixed> */
    private function listItem(): array
    {
        return collect($this->answerHttp($this->student, 'GET', '/api/v1/student/homework')->assertOk()->json('data'))
            ->firstWhere('id', $this->homework->assessment_id);
    }

    /** @return array{TestResponse, list<array<string, mixed>>} */
    private function recordListQueries(): array
    {
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $response = $this->answerHttp($this->student, 'GET', '/api/v1/student/homework?per_page=100')->assertOk();

            return [$response, DB::getQueryLog()];
        } finally {
            DB::disableQueryLog();
        }
    }
}
