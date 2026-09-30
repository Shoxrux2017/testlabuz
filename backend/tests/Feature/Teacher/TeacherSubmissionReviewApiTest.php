<?php

namespace Tests\Feature\Teacher;

use App\Actions\Checking\CheckFrozenAttempt;
use App\Models\AnswerTextValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\GroupTeacherMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\OfficialTaskScore;
use App\Models\Question;
use App\Models\TopicResultPair;
use App\Models\User;
use ArrayObject;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkAnswerContext;
use Tests\TestCase;

/**
 * S09-BE-006: a Teacher saves points and feedback for the manual answers of a submission
 * (docs/09 §23.1) and corrects them later (§23.2).
 */
class TeacherSubmissionReviewApiTest extends TestCase
{
    use BuildsStudentHomeworkAnswerContext;
    use RefreshDatabase;

    private User $student;

    private HomeworkAssignment $homework;

    private AssessmentAttempt $attempt;

    private User $teacher;

    private Question $trueFalse;

    private Question $essay;

    private Question $explanation;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        [$this->student, $this->homework, $this->attempt] = $this->answerContext();
        $this->teacher = $this->homework->assessment->teacher;
        $this->teacher->update(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $this->teacher->institution_id, 'group_id' => $this->homework->assessment->topic->group_id,
            'teacher_id' => $this->teacher->id, 'assigned_by_user_id' => $this->teacher->id,
        ]);
        // 1 + 3 + 4 = the Attempt's 8 possible points.
        $this->trueFalse = $this->answerQuestion($this->homework, 'true_false', 1);
        $this->essay = $this->answerQuestion($this->homework, 'open_written', 2);
        $this->essay->update(['points' => '3.000000']);
        $this->explanation = $this->answerQuestion($this->homework, 'open_written', 3);
        $this->explanation->update(['points' => '4.000000']);
    }

    public function test_a_partial_review_saves_the_answer_and_keeps_the_submission_waiting(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $this->travel(1)->hours();

        $response = $this->review($this->attempt, [$this->item($this->essay, 2.5, "  Good start.\n ")]);

        $response->assertOk()->assertJsonPath('message', 'Submission review saved successfully.');
        $essay = $this->answerTo($this->attempt, $this->essay);
        $this->assertSame(['teacher_checked', '2.50000000', 'Good start.', $this->teacher->id],
            [$essay->getRawOriginal('checking_status'), $essay->awarded_points, $essay->feedback, $essay->checked_by_user_id]);
        $this->assertTrue($essay->checked_at->equalTo(now()));
        $this->assertSame('waiting_for_teacher_review', $this->answerTo($this->attempt, $this->explanation)->getRawOriginal('checking_status'));
        $attempt = $this->attempt->fresh();
        $this->assertSame(['waiting_for_teacher_review', null, null, null], [$attempt->getRawOriginal('status'),
            $attempt->earned_points, $attempt->normalized_score, $attempt->scoring_completed_at]);
        $this->assertTrue($attempt->updated_at->equalTo(now()));
        $data = $response->json('data');
        $this->assertSame([$this->attempt->id, 'waiting_for_teacher_review'], [$data['id'], $data['status']]);
        $this->assertSame(['id' => $essay->id, 'checking_status' => 'teacher_checked', 'awarded_points' => 2.5,
            'feedback' => 'Good start.', 'checked_by' => ['id' => $this->teacher->id, 'full_name' => $this->teacher->full_name],
            'checked_at' => now()->toIso8601ZuluString()], array_diff_key($data['questions'][1]['answer'], ['value' => true]));
    }

    public function test_reviewing_the_last_waiting_answer_checks_the_submission_with_exact_scores(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $this->review($this->attempt, [$this->item($this->essay, 2.5, null)])->assertOk();
        $this->travel(1)->hours();

        $response = $this->review($this->attempt, [$this->item($this->explanation, 4, 'Complete.')]);

        $response->assertOk();
        $attempt = $this->attempt->fresh();
        // 1 automatic + 2.5 + 4 = 7.5 of 8 points.
        $this->assertSame(['checked', '7.50000000', '93.75000000'], [$attempt->getRawOriginal('status'),
            $attempt->earned_points, $attempt->normalized_score]);
        $this->assertTrue($attempt->scoring_completed_at->equalTo(now()));
        $this->assertSame(['status' => 'checked', 'score' => ['earned_points' => 7.5, 'possible_points' => 8, 'normalized_score' => 93.75]],
            array_intersect_key($response->json('data'), ['status' => true, 'score' => true]));
    }

    public function test_one_save_may_review_several_answers_at_the_bounds_of_their_points(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);

        $this->review($this->attempt, [$this->item($this->essay, 0, null), $this->item($this->explanation, 4.0, null)])->assertOk();

        $this->assertSame(['0.00000000', '4.00000000'], [$this->answerTo($this->attempt, $this->essay)->awarded_points,
            $this->answerTo($this->attempt, $this->explanation)->awarded_points]);
        $this->assertSame(['checked', '5.00000000', '62.50000000'], [$this->attempt->fresh()->getRawOriginal('status'),
            $this->attempt->fresh()->earned_points, $this->attempt->fresh()->normalized_score]);
    }

    public function test_awarded_points_keep_six_fractional_digits(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);

        $this->review($this->attempt, [$this->item($this->essay, 2.123456, null)])->assertOk();

        $this->assertSame('2.12345600', $this->answerTo($this->attempt, $this->essay)->awarded_points);
    }

    public function test_a_correction_keeps_the_submission_checked_and_recalculates_it(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $this->review($this->attempt, [$this->item($this->essay, 3, 'Great.'), $this->item($this->explanation, 4, 'Complete.')])->assertOk();
        $this->assertSame('100.00000000', $this->attempt->fresh()->normalized_score);
        $this->travel(2)->hours();

        $this->review($this->attempt, [$this->item($this->essay, 1, "  \n ")])->assertOk();

        $essay = $this->answerTo($this->attempt, $this->essay);
        $this->assertSame(['teacher_checked', '1.00000000', null], [$essay->getRawOriginal('checking_status'), $essay->awarded_points, $essay->feedback]);
        $this->assertTrue($essay->checked_at->equalTo(now()));
        $this->assertSame('Complete.', $this->answerTo($this->attempt, $this->explanation)->feedback);
        $attempt = $this->attempt->fresh();
        $this->assertSame(['checked', '6.00000000', '75.00000000'], [$attempt->getRawOriginal('status'),
            $attempt->earned_points, $attempt->normalized_score]);
        $this->assertTrue($attempt->scoring_completed_at->equalTo(now()));
    }

    public function test_review_changes_no_answer_content_save_time_automatic_result_or_frozen_attempt_field(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $reviewColumns = array_flip(['checking_status', 'awarded_points', 'feedback', 'checked_by_user_id', 'checked_at']);
        $content = fn (): array => array_map(fn (array $rows): array => array_map(
            fn (array $row): array => array_diff_key($row, $reviewColumns), $rows), $this->answerSnapshot());
        $automatic = fn (): array => (array) DB::table('attempt_answers')->where('id', $this->answerTo($this->attempt, $this->trueFalse)->id)->first();
        $frozen = fn (): array => array_intersect_key((array) DB::table('assessment_attempts')->where('id', $this->attempt->id)->first(),
            array_flip(['attempt_number', 'started_at', 'submitted_at', 'finalized_at', 'locked_at', 'finalization_reason',
                'possible_points', 'official_score_eligible', 'deadline_at', 'created_at']));
        [$before, $automaticBefore, $frozenBefore] = [$content(), $automatic(), $frozen()];
        $this->travel(1)->hours();

        $this->review($this->attempt, [$this->item($this->essay, 2, 'Fine.'), $this->item($this->explanation, 3, null)])->assertOk();
        $this->travel(1)->hours();
        $this->review($this->attempt, [$this->item($this->essay, 1, null)])->assertOk();

        $this->assertSame($before, $content());
        $this->assertSame($automaticBefore, $automatic());
        $this->assertSame(['auto_checked', '1.00000000'], [$automaticBefore['checking_status'], $automaticBefore['awarded_points']]);
        $this->assertSame($frozenBefore, $frozen());
    }

    /** @return array<string, array{string, int, string}> */
    public static function changesWhileWaitingForTheLocks(): array
    {
        return [
            'access ended' => ['membership', 404, 'resource_not_found'],
            'back to automatic checking' => ['attempt', 409, 'automatic_checking_pending'],
            'answer no longer manual' => ['answer', 422, 'validation_failed'],
        ];
    }

    #[DataProvider('changesWhileWaitingForTheLocks')]
    public function test_access_state_and_items_are_evaluated_again_under_the_scoring_locks(string $change, int $status, string $code): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $essay = $this->answerTo($this->attempt, $this->essay);
        $before = $this->answerSnapshot();
        $changed = false;
        // Runs in the save's transaction right after the recipient lock: what a concurrent writer
        // committed while this save waited for the lock, after its checks before the lock passed.
        DB::listen(function ($query) use (&$changed, $change, $essay): void {
            if ($changed || ! str_contains($query->sql, 'from "assessment_students"') || ! str_ends_with($query->sql, 'for update')) {
                return;
            }
            $changed = true;
            match ($change) {
                'membership' => DB::table('group_teacher_memberships')->where('teacher_id', $this->teacher->id)->update(['ended_at' => now()]),
                'attempt' => DB::table('assessment_attempts')->where('id', $this->attempt->id)->update(['status' => 'submitted']),
                'answer' => DB::table('attempt_answers')->where('id', $essay->id)
                    ->update(['checking_status' => 'auto_checked', 'awarded_points' => '0', 'checked_at' => now()]),
            };
        });

        $response = $this->review($this->attempt, [$this->item($this->essay, 2, 'Fine.')]);

        $this->assertTrue($changed);
        $response->assertStatus($status)->assertJsonPath('code', $code);
        if ($change === 'answer') {
            $this->assertSame(['answers.0.answer_id'], array_keys($response->json('errors')));
        }
        // The rejected save rolled back together with the change it saw.
        $this->assertSame($before, $this->answerSnapshot());
        $this->assertSame('waiting_for_teacher_review', $this->attempt->fresh()->getRawOriginal('status'));
    }

    public function test_a_blitz_submission_is_reviewed_under_its_blitz_task_lock(): void
    {
        $assessment = Assessment::factory()->blitz()->create([
            'institution_id' => $this->teacher->institution_id, 'topic_id' => $this->homework->assessment->topic_id,
            'teacher_id' => $this->teacher->id, 'total_possible_points' => '2.000000',
        ]);
        $blitz = BlitzTask::factory()->closedIndividual()->create(['assessment_id' => $assessment->id]);
        $written = $this->answerQuestion($blitz, 'open_written');
        $written->update(['points' => '2.000000']);
        $recipient = AssessmentStudent::factory()->create(['assessment_id' => $assessment->id, 'student_id' => $this->student->id,
            'assigned_by_user_id' => $this->teacher->id]);
        $attempt = AssessmentAttempt::factory()->create(['assessment_student_id' => $recipient->id, 'possible_points' => '2.000000',
            'started_at' => now()->subMinutes(20)])->fresh();
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $written->id]);
        AnswerTextValue::factory()->create(['answer_id' => $answer->id, 'text_value' => 'DNS resolves names.']);
        $this->freeze($attempt);
        $this->check($attempt);
        $locks = $this->recordLocks();

        $this->review($attempt, [$this->item($written, 1.5, null, $attempt)])->assertOk()->assertJsonPath('data.status', 'checked');

        $this->assertSame(['topics share', 'assessments share', 'blitz_tasks share', 'assessment_students update',
            'assessment_attempts update', 'attempt_answers update'], $locks->getArrayCopy());
        $this->assertSame('75.00000000', $attempt->fresh()->normalized_score);
    }

    public function test_completing_the_review_stores_the_official_score_and_a_correction_moves_it(): void
    {
        TopicResultPair::factory()->create(['homework_assessment_id' => $this->homework->assessment_id]);
        $this->answerRequest($this->student, $this->attempt, $this->essay, $this->answerPayload($this->essay))->assertOk();
        $this->answerRequest($this->student, $this->attempt, $this->explanation, $this->answerPayload($this->explanation))->assertOk();
        $this->freezeAndCheck($this->attempt);
        $this->assertDatabaseCount('official_task_scores', 0);
        $this->review($this->attempt, [$this->item($this->essay, 3, null)])->assertOk();
        $this->assertDatabaseCount('official_task_scores', 0);
        $this->travel(1)->hours();

        $this->review($this->attempt, [$this->item($this->explanation, 4, null)])->assertOk();

        // 0 + 3 + 4 = 7 of 8 points.
        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$this->attempt->id, '87.50000000'], [$row->official_attempt_id, $row->normalized_score]);
        $this->assertTrue($row->selected_at->equalTo(now()));
        $second = AssessmentAttempt::factory()->create(['assessment_student_id' => $this->attempt->assessment_student_id,
            'attempt_number' => 2, 'possible_points' => '8.000000', 'started_at' => now()])->fresh();
        $this->answerRequest($this->student, $second, $this->trueFalse, ['type' => 'true_false', 'value' => true])->assertOk();
        $this->freezeAndCheck($second);
        $this->assertSame($this->attempt->id, OfficialTaskScore::query()->sole()->official_attempt_id);
        $this->travel(1)->hours();

        $this->review($this->attempt, [$this->item($this->essay, 0, null), $this->item($this->explanation, 0, null)])->assertOk();

        $row = OfficialTaskScore::query()->sole();
        $this->assertSame([$second->id, '12.50000000'], [$row->official_attempt_id, $row->normalized_score]);
        $this->assertTrue($row->selected_at->equalTo(now()));
    }

    public function test_an_official_review_takes_the_scoring_locks_in_order_with_the_official_row_last(): void
    {
        TopicResultPair::factory()->create(['homework_assessment_id' => $this->homework->assessment_id]);
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $locks = $this->recordLocks();

        $this->review($this->attempt, [$this->item($this->essay, 1, null), $this->item($this->explanation, 1, null)])->assertOk();

        $this->assertSame(['topics share', 'assessments share', 'homework_assignments share', 'assessment_students update',
            'assessment_attempts update', 'attempt_answers update', 'official_task_scores update'], $locks->getArrayCopy());
    }

    public function test_a_submission_awaiting_automatic_checking_cannot_be_reviewed(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);

        foreach (['submitted', 'timed_out_finalized'] as $status) {
            $this->uncheckFrozenAttempt($this->attempt, $status);
            $before = $this->answerSnapshot();

            $this->review($this->attempt, [$this->item($this->essay, 1, null)])->assertStatus(409)->assertExactJson([
                'message' => 'The submission is still waiting for automatic checking.',
                'code' => 'automatic_checking_pending', 'errors' => [],
            ]);

            $this->assertSame($before, $this->answerSnapshot(), $status);
            $this->assertSame($status, $this->attempt->fresh()->getRawOriginal('status'));
        }
    }

    public function test_work_outside_the_review_rule_is_not_found(): void
    {
        $this->answerAll($this->attempt);
        $body = [$this->item($this->essay, 1, null)];
        $this->review($this->attempt, $body)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->freezeAndCheck($this->attempt);
        $otherTeacher = User::factory()->teacher($this->teacher->institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create([
            'institution_id' => $this->teacher->institution_id, 'group_id' => $this->homework->assessment->topic->group_id,
            'teacher_id' => $otherTeacher->id, 'assigned_by_user_id' => $this->teacher->id,
        ]);
        $foreignTeacher = User::factory()->teacher(Institution::factory()->create())->create(['must_change_password' => false]);
        $before = $this->answerSnapshot();

        foreach (['not-a-uuid', (string) Str::uuid()] as $id) {
            $this->reviewRaw($id, json_encode(['answers' => $body]))->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->review($this->attempt, $body, $otherTeacher)->assertNotFound();
        $this->review($this->attempt, $body, $foreignTeacher)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        GroupTeacherMembership::query()->where('teacher_id', $this->teacher->id)->update(['ended_at' => now()]);
        $this->review($this->attempt, $body)->assertNotFound();

        $this->assertSame($before, $this->answerSnapshot());
    }

    public function test_the_review_route_is_registered_once_behind_the_teacher_gates(): void
    {
        $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/teacher/submissions/{submission}/review');
        $this->assertCount(1, $routes);
        $this->assertSame(['PUT'], $routes->sole()->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'], $routes->sole()->middleware());
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $body = json_encode(['answers' => [$this->item($this->essay, 1, null)]]);

        $this->call('PUT', '/api/v1/teacher/submissions/'.$this->attempt->id.'/review', [], [], [],
            ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'], $body)
            ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $this->answerHttp($this->student, 'PUT', '/api/v1/teacher/submissions/'.$this->attempt->id.'/review', $body)
            ->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->assertSame('waiting_for_teacher_review', $this->answerTo($this->attempt, $this->essay)->getRawOriginal('checking_status'));
    }

    /** @return array<string, array{string, list<string>}> */
    public static function invalidShapes(): array
    {
        $item = '{"answer_id":"%essay%","awarded_points":1,"feedback":null}';

        return [
            'empty body' => ['', ['body']],
            'invalid JSON' => ['{"answers":', ['body']],
            'JSON array body' => ['[]', ['body']],
            'missing answers' => ['{}', ['answers']],
            'unknown top-level key' => ['{"answers":['.$item.'],"note":"x"}', ['note']],
            'answers not an array' => ['{"answers":{"0":'.$item.'}}', ['answers']],
            'empty answers' => ['{"answers":[]}', ['answers']],
            'item not an object' => ['{"answers":[1]}', ['answers.0']],
            'item without keys' => ['{"answers":[{}]}', ['answers.0.answer_id', 'answers.0.awarded_points', 'answers.0.feedback']],
            'unknown item key' => ['{"answers":[{"answer_id":"%essay%","awarded_points":1,"feedback":null,"points":1}]}', ['answers.0.points']],
            'answer id not a UUID' => ['{"answers":[{"answer_id":"essay","awarded_points":1,"feedback":null}]}', ['answers.0.answer_id']],
            'answer id not a string' => ['{"answers":[{"answer_id":12,"awarded_points":1,"feedback":null}]}', ['answers.0.answer_id']],
            'points as a string' => ['{"answers":[{"answer_id":"%essay%","awarded_points":"1","feedback":null}]}', ['answers.0.awarded_points']],
            'points as a boolean' => ['{"answers":[{"answer_id":"%essay%","awarded_points":true,"feedback":null}]}', ['answers.0.awarded_points']],
            'points null' => ['{"answers":[{"answer_id":"%essay%","awarded_points":null,"feedback":null}]}', ['answers.0.awarded_points']],
            'feedback not a string' => ['{"answers":[{"answer_id":"%essay%","awarded_points":1,"feedback":5}]}', ['answers.0.feedback']],
            'feedback too long' => ['{"answers":[{"answer_id":"%essay%","awarded_points":1,"feedback":"%long%"}]}', ['answers.0.feedback']],
            'duplicate answer id' => ['{"answers":['.$item.',{"answer_id":"%ESSAY%","awarded_points":2,"feedback":null}]}', ['answers.1.answer_id']],
        ];
    }

    /** @param list<string> $errors */
    #[DataProvider('invalidShapes')]
    public function test_the_review_body_has_a_strict_shape(string $body, array $errors): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $essay = $this->answerTo($this->attempt, $this->essay)->id;
        $before = $this->answerSnapshot();

        $response = $this->reviewRaw($this->attempt->id, strtr($body, ['%essay%' => $essay, '%ESSAY%' => strtoupper($essay),
            '%long%' => str_repeat('a', 2001)]));

        $response->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($errors, array_keys($response->json('errors')));
        $this->assertSame($before, $this->answerSnapshot());
    }

    public function test_the_review_takes_no_query_parameters_or_non_json_body(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $body = json_encode(['answers' => [$this->item($this->essay, 1, null)]]);

        $this->reviewRaw($this->attempt->id, $body, '?notify=1')->assertUnprocessable()->assertJsonPath('errors.notify.0', 'Query parameters are not allowed for this endpoint.');
        $response = $this->reviewRaw($this->attempt->id, $body, '', 'text/plain');
        $response->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame(['body'], array_keys($response->json('errors')));
        $this->assertSame('waiting_for_teacher_review', $this->answerTo($this->attempt, $this->essay)->getRawOriginal('checking_status'));
    }

    public function test_feedback_is_trimmed_and_limited_after_trimming(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $feedback = str_repeat('я', 2000);

        $this->review($this->attempt, [$this->item($this->essay, 1, "  {$feedback}\n")])->assertOk();

        $this->assertSame($feedback, $this->answerTo($this->attempt, $this->essay)->feedback);
    }

    public function test_shape_is_checked_before_access_access_before_state_and_state_before_items(): void
    {
        $this->answerAll($this->attempt);
        $this->reviewRaw((string) Str::uuid(), '{}')->assertUnprocessable();
        $this->freeze($this->attempt);
        $otherTeacher = User::factory()->teacher($this->teacher->institution)->create(['must_change_password' => false]);

        $this->review($this->attempt, [$this->item($this->essay, 1, null)], $otherTeacher)->assertNotFound();
        $this->reviewRaw($this->attempt->id, json_encode(['answers' => [['answer_id' => (string) Str::uuid(), 'awarded_points' => 99, 'feedback' => null]]]))
            ->assertStatus(409)->assertJsonPath('code', 'automatic_checking_pending');
    }

    public function test_items_must_be_manual_answers_of_this_submission_within_the_question_points(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);
        $second = AssessmentAttempt::factory()->create(['assessment_student_id' => $this->attempt->assessment_student_id,
            'attempt_number' => 2, 'possible_points' => '8.000000', 'started_at' => now()])->fresh();
        $this->answerRequest($this->student, $second, $this->essay, $this->answerPayload($this->essay))->assertOk();
        $this->freezeAndCheck($second);
        $essay = $this->answerTo($this->attempt, $this->essay)->id;
        $before = $this->answerSnapshot();
        $invalid = [
            'another submission' => [['answer_id' => $this->answerTo($second, $this->essay)->id, 'awarded_points' => 1, 'feedback' => null], 'answers.1.answer_id'],
            'automatic answer' => [['answer_id' => $this->answerTo($this->attempt, $this->trueFalse)->id, 'awarded_points' => 1, 'feedback' => null], 'answers.1.answer_id'],
            'unknown answer' => [['answer_id' => (string) Str::uuid(), 'awarded_points' => 1, 'feedback' => null], 'answers.1.answer_id'],
            'above the question points' => [$this->item($this->explanation, 4.000001, null), 'answers.1.awarded_points'],
            'negative' => [$this->item($this->explanation, -1, null), 'answers.1.awarded_points'],
            'seven decimals' => [$this->item($this->explanation, 1.0000001, null), 'answers.1.awarded_points'],
        ];

        foreach ($invalid as $case => [$item, $error]) {
            $response = $this->review($this->attempt, [['answer_id' => $essay, 'awarded_points' => 1, 'feedback' => null], $item]);

            $response->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            $this->assertSame([$error], array_keys($response->json('errors')), $case);
            $this->assertSame($before, $this->answerSnapshot(), $case);
        }
    }

    public function test_all_item_errors_are_reported_together(): void
    {
        $this->answerAll($this->attempt);
        $this->freezeAndCheck($this->attempt);

        $response = $this->review($this->attempt, [$this->item($this->essay, 5, null),
            ['answer_id' => $this->answerTo($this->attempt, $this->trueFalse)->id, 'awarded_points' => -2, 'feedback' => null]]);

        $response->assertUnprocessable();
        $this->assertSame(['answers.0.awarded_points', 'answers.1.answer_id', 'answers.1.awarded_points'], array_keys($response->json('errors')));
    }

    private function answerAll(AssessmentAttempt $attempt): void
    {
        $this->answerRequest($this->student, $attempt, $this->trueFalse, ['type' => 'true_false', 'value' => true])->assertOk();
        $this->answerRequest($this->student, $attempt, $this->essay, $this->answerPayload($this->essay))->assertOk();
        $this->answerRequest($this->student, $attempt, $this->explanation, $this->answerPayload($this->explanation, true))->assertOk();
    }

    private function freeze(AssessmentAttempt $attempt): void
    {
        DB::table('assessment_attempts')->where('id', $attempt->id)->update([
            'status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit',
        ]);
    }

    private function check(AssessmentAttempt $attempt): void
    {
        $this->assertTrue(app(CheckFrozenAttempt::class)($attempt->id));
    }

    private function freezeAndCheck(AssessmentAttempt $attempt): void
    {
        $this->freeze($attempt);
        $this->check($attempt);
    }

    private function answerTo(AssessmentAttempt $attempt, Question $question): AttemptAnswer
    {
        return AttemptAnswer::query()->where('attempt_id', $attempt->id)->where('question_id', $question->id)->sole();
    }

    /** @return array{answer_id: string, awarded_points: int|float, feedback: ?string} */
    private function item(Question $question, int|float $points, ?string $feedback, ?AssessmentAttempt $attempt = null): array
    {
        return ['answer_id' => $this->answerTo($attempt ?? $this->attempt, $question)->id, 'awarded_points' => $points, 'feedback' => $feedback];
    }

    /** @param list<array<string, mixed>> $answers */
    private function review(AssessmentAttempt $attempt, array $answers, ?User $teacher = null): TestResponse
    {
        return $this->reviewRaw($attempt->id, json_encode(['answers' => $answers], JSON_THROW_ON_ERROR | JSON_PRESERVE_ZERO_FRACTION), '', 'application/json', $teacher);
    }

    private function reviewRaw(string $submissionId, string $body, string $query = '', string $contentType = 'application/json', ?User $teacher = null): TestResponse
    {
        return $this->answerHttp($teacher ?? $this->teacher, 'PUT', '/api/v1/teacher/submissions/'.$submissionId.'/review'.$query, $body, $contentType);
    }

    /** @return ArrayObject<int, string> The share and update locks taken from now on, as "table mode". */
    private function recordLocks(): ArrayObject
    {
        $locks = new ArrayObject;
        DB::listen(function ($query) use ($locks): void {
            if (preg_match('/from "(\w+)".* for (share|update)$/s', $query->sql, $matches) === 1) {
                $locks[] = $matches[1].' '.$matches[2];
            }
        });

        return $locks;
    }
}
