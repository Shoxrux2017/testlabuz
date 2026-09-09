<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AttemptAnswerCheckingStatus;
use App\Enums\QuestionType;
use App\Models\AnswerTextValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentHomeworkDeadlineReadReconciliationTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/student/homework';

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-09 09:00:00 UTC'));
    }

    #[DataProvider('dueReadCases')]
    public function test_read_reconciles_due_work_at_the_exact_deadline_without_changing_saved_answers(
        bool $detail,
        int $deadlineOffset,
    ): void {
        $student = $this->student();
        $deadline = now()->addSeconds($deadlineOffset);
        $homework = $this->homework($student, $deadline);
        $attempt = $this->attempt($homework, $student);
        $answer = AttemptAnswer::factory()->forQuestionType(QuestionType::ShortWritten)->create(['attempt_id' => $attempt]);
        $payload = AnswerTextValue::factory()->create([
            'answer_id' => $answer,
            'text_value' => 'Saved Student payload must remain private and unchanged.',
        ]);
        $answerBefore = $answer->fresh()->getAttributes();
        $payloadBefore = $payload->fresh()->getAttributes();
        $homeworkBefore = $homework->fresh()->getAttributes();

        $response = $this->requestAs($student, $detail ? self::URI.'/'.$homework->assessment_id : self::URI);

        $this->assertFinalizedAtDeadline($attempt, $deadline);
        $this->assertSame($answerBefore, $answer->fresh()->getAttributes());
        $this->assertSame($payloadBefore, $payload->fresh()->getAttributes());
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->fresh()->checking_status);
        $this->assertNull($answer->fresh()->awarded_points);
        $this->assertSame($homeworkBefore, $homework->fresh()->getAttributes());
        $prefix = $detail ? 'data' : 'data.0';
        $response->assertOk()
            ->assertJsonPath($prefix.'.my_status', 'submitted')
            ->assertJsonPath($prefix.'.attempts.used', 1)
            ->assertJsonPath($prefix.'.attempts.remaining', 0)
            ->assertJsonPath($prefix.'.score_visible', false);
        $this->assertStringNotContainsString($payload->text_value, $response->getContent());
        if ($detail) {
            $response->assertJsonPath('data.attempts.in_progress_attempt', null);
        }
    }

    public static function dueReadCases(): array
    {
        return [
            'list at deadline' => [false, 0],
            'list after deadline' => [false, -1],
            'detail at deadline' => [true, 0],
            'detail after deadline' => [true, -1],
        ];
    }

    public function test_expired_homework_reads_do_not_fabricate_an_attempt_for_a_never_started_recipient(): void
    {
        $student = $this->student();
        $homework = $this->homework($student, now()->subMinute());

        $this->requestAs($student, self::URI)->assertOk()
            ->assertJsonPath('data.0.my_status', 'not_started')
            ->assertJsonPath('data.0.attempts.used', 0)
            ->assertJsonPath('data.0.attempts.remaining', 0);
        $this->requestAs($student, self::URI.'/'.$homework->assessment_id)->assertOk()
            ->assertJsonPath('data.my_status', 'not_started')
            ->assertJsonPath('data.attempts.used', 0)
            ->assertJsonPath('data.attempts.remaining', 0)
            ->assertJsonPath('data.attempts.in_progress_attempt', null);

        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('attempt_answers', 0);
    }

    public function test_unauthorized_detail_does_not_reconcile_another_students_or_another_institutions_homework(): void
    {
        $student = $this->student();
        $otherStudent = $this->student($student->institution);
        $foreignStudent = $this->student();

        foreach ([$otherStudent, $foreignStudent] as $recipient) {
            $homework = $this->homework($recipient, now()->subMinute());
            $attempt = $this->attempt($homework, $recipient);
            $before = $attempt->fresh()->getAttributes();

            $response = $this->requestAs($student, self::URI.'/'.$homework->assessment_id);

            $this->assertSame($before, $attempt->fresh()->getAttributes());
            $response->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
    }

    #[DataProvider('readSurfaces')]
    public function test_reads_before_the_deadline_leave_attempt_finalization_write_free(bool $detail): void
    {
        $student = $this->student();
        $homework = $this->homework($student, now()->addSecond());
        $attempt = $this->attempt($homework, $student);
        $before = $attempt->fresh()->getAttributes();

        $response = $this->requestAs($student, $detail ? self::URI.'/'.$homework->assessment_id : self::URI);

        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $prefix = $detail ? 'data' : 'data.0';
        $response->assertOk()
            ->assertJsonPath($prefix.'.my_status', 'in_progress')
            ->assertJsonPath($prefix.'.attempts.remaining', 2);
        if ($detail) {
            $response->assertJsonPath('data.attempts.in_progress_attempt.id', $attempt->id);
        }
    }

    #[DataProvider('readSurfaces')]
    public function test_crossing_the_deadline_during_projection_preserves_one_read_decision_instant(bool $detail): void
    {
        $student = $this->student();
        $deadline = now()->addSecond();
        $homework = $this->homework($student, $deadline);
        $attempt = $this->attempt($homework, $student);
        $before = $attempt->fresh()->getAttributes();
        $clockAdvanced = false;
        DB::listen(function (QueryExecuted $query) use ($detail, $deadline, &$clockAdvanced): void {
            $readHasStarted = $detail
                ? str_contains($query->sql, 'from "questions"')
                : str_contains($query->sql, 'exists (select 1 from "assessment_attempts"');

            if (! $clockAdvanced && $readHasStarted) {
                $clockAdvanced = true;
                $this->travelTo($deadline->copy()->addSecond());
            }
        });

        $response = $this->requestAs($student, $detail ? self::URI.'/'.$homework->assessment_id : self::URI);

        $this->assertTrue($clockAdvanced, 'The test clock must cross the deadline after the read decision was captured.');
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $prefix = $detail ? 'data' : 'data.0';
        $response->assertOk()
            ->assertJsonPath($prefix.'.my_status', 'in_progress')
            ->assertJsonPath($prefix.'.attempts.remaining', 2);
        if ($detail) {
            $response->assertJsonPath('data.attempts.in_progress_attempt.id', $attempt->id);
        }

        $nextResponse = $this->requestAs($student, $detail ? self::URI.'/'.$homework->assessment_id : self::URI);

        $this->assertFinalizedAtDeadline($attempt, $deadline);
        $nextResponse->assertOk()
            ->assertJsonPath($prefix.'.my_status', 'submitted')
            ->assertJsonPath($prefix.'.attempts.remaining', 0);
    }

    public static function readSurfaces(): array
    {
        return ['list' => [false], 'detail' => [true]];
    }

    public function test_list_reconciles_only_assigned_due_homework_with_current_student_in_progress_work(): void
    {
        $student = $this->student();
        $otherStudent = $this->student($student->institution);
        $foreignStudent = $this->student();
        $due = $this->homework($student, now()->subMinute());
        $currentAttempt = $this->attempt($due, $student);
        $this->recipient($due, $otherStudent);
        $sameHomeworkOtherAttempt = $this->attempt($due, $otherStudent);
        $hidden = $this->homework($otherStudent, now()->subMinute());
        $foreign = $this->homework($foreignStudent, now()->subMinute());
        $draft = $this->homework($student, now()->subMinute(), 'draft');
        $closed = $this->homework($student, now()->subMinute(), 'closed');
        $future = $this->homework($student, now()->addMinute());
        $withoutDeadline = $this->homework($student, null);
        $onlyOtherStudentStarted = $this->homework($student, now()->subMinute());
        $this->recipient($onlyOtherStudentStarted, $otherStudent);
        $unchanged = [
            $this->attempt($hidden, $otherStudent),
            $this->attempt($foreign, $foreignStudent),
            $this->attempt($draft, $student),
            $this->attempt($closed, $student),
            $this->attempt($future, $student),
            $this->attempt($withoutDeadline, $student),
            $this->attempt($onlyOtherStudentStarted, $otherStudent),
        ];
        $before = array_map(fn (AssessmentAttempt $attempt) => $attempt->fresh()->getAttributes(), $unchanged);

        $response = $this->requestAs($student, self::URI);

        $this->assertFinalizedAtDeadline($currentAttempt, $due->deadline_at);
        $this->assertFinalizedAtDeadline($sameHomeworkOtherAttempt, $due->deadline_at);
        $this->assertSame($before, array_map(fn (AssessmentAttempt $attempt) => $attempt->fresh()->getAttributes(), $unchanged));
        $response->assertOk();
        $this->assertEqualsCanonicalizing([
            $due->assessment_id, $closed->assessment_id, $future->assessment_id,
            $withoutDeadline->assessment_id, $onlyOtherStudentStarted->assessment_id,
        ], collect($response->json('data'))->pluck('id')->all());
    }

    public function test_list_keyset_reconciliation_does_not_skip_candidates_when_the_due_result_set_shrinks(): void
    {
        $student = $this->student();
        $deadline = now()->subMinute();
        $base = Assessment::factory()->homework()->create(['institution_id' => $student->institution_id]);

        for ($index = 1; $index <= 101; $index++) {
            $homework = $this->homework($student, $deadline, assessmentAttributes: [
                'id' => sprintf('00000000-0000-4000-8000-%012d', $index),
                'topic_id' => $base->topic_id,
                'teacher_id' => $base->teacher_id,
            ]);
            $this->attempt($homework, $student);
        }

        $response = $this->requestAs($student, self::URI.'?per_page=1');

        $this->assertSame(101, AssessmentAttempt::query()
            ->where('student_id', $student->id)
            ->where('status', AssessmentAttemptStatus::Submitted->value)
            ->where('finalization_reason', AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit->value)
            ->where('finalized_at', $deadline)
            ->where('locked_at', $deadline)
            ->whereNull('submitted_at')
            ->count());
        $this->assertDatabaseMissing('assessment_attempts', [
            'student_id' => $student->id,
            'status' => AssessmentAttemptStatus::InProgress->value,
        ]);
        $response->assertOk()->assertJsonPath('meta.pagination.total', 101)
            ->assertJsonPath('data.0.my_status', 'submitted');
    }

    private function student(?Institution $institution = null): User
    {
        if ($institution === null) {
            $institution = Institution::factory()->create();
            InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        }

        return User::factory()->student($institution)->create(['must_change_password' => false]);
    }

    private function homework(
        User $student,
        ?CarbonInterface $deadline,
        string $state = 'active',
        array $assessmentAttributes = [],
    ): HomeworkAssignment {
        $assessment = Assessment::factory()->homework()->create(array_merge([
            'institution_id' => $student->institution_id,
        ], $assessmentAttributes));
        $homework = HomeworkAssignment::factory()->{$state}()->create([
            'assessment_id' => $assessment->id,
            'deadline_at' => $deadline,
        ]);
        $this->recipient($homework, $student);

        return $homework;
    }

    private function recipient(HomeworkAssignment $homework, User $student): AssessmentStudent
    {
        return AssessmentStudent::factory()->create([
            'assessment_id' => $homework->assessment_id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $homework->assessment->teacher_id,
        ]);
    }

    private function attempt(HomeworkAssignment $homework, User $student): AssessmentAttempt
    {
        $recipient = AssessmentStudent::query()
            ->where('institution_id', $student->institution_id)
            ->where('assessment_id', $homework->assessment_id)
            ->where('student_id', $student->id)
            ->firstOrFail();

        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id,
            'started_at' => now()->subHour(),
        ]);
    }

    private function requestAs(User $student, string $uri): TestResponse
    {
        $response = $this->call('GET', $uri, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('student-homework-deadline-read-test')->plainTextToken,
        ]);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function assertFinalizedAtDeadline(AssessmentAttempt $attempt, CarbonInterface $deadline): void
    {
        $attempt->refresh();
        $this->assertSame(AssessmentAttemptStatus::Submitted, $attempt->status);
        $this->assertNull($attempt->submitted_at);
        $this->assertTrue($deadline->equalTo($attempt->finalized_at));
        $this->assertTrue($deadline->equalTo($attempt->locked_at));
        $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $attempt->finalization_reason);
    }
}
