<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\BlitzStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\BlitzAttemptException;
use App\Models\GroupTeacherMembership;
use App\Models\Institution;
use App\Models\OfficialTaskScore;
use App\Models\Question;
use App\Models\TopicResultPair;
use App\Models\User;
use App\Support\Checking\OfficialTaskScoreResolver;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTeacherSubmissionContext;
use Tests\TestCase;

/**
 * S09-BE-007A: a Teacher reads one Student's official task score, or why it is not ready
 * (docs/09 §24.1). Committed fixtures: the read owns a top-level snapshot transaction.
 */
class TeacherOfficialScoreApiTest extends TestCase
{
    use BuildsTeacherSubmissionContext;
    use UsesBlitzReadSnapshot;

    private User $student;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-30 10:00:00 UTC'));
        $this->submissionContext();
        $this->teacher->update(['must_change_password' => false]);
        $this->student = $this->studentNamed('Alpha Student');
        $this->student->update(['must_change_password' => false]);
    }

    public function test_the_route_is_registered_once_behind_the_teacher_gates(): void
    {
        $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/teacher/assessments/{assessment}/students/{student}/official-score');
        $this->assertCount(1, $routes);
        $this->assertSame(['GET', 'HEAD'], $routes->sole()->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'], $routes->sole()->middleware());
        $homework = $this->officialHomework();
        $this->recipientOf($homework);

        $this->getJson($this->uri($homework, $this->student))->assertUnauthorized();
        $this->read($homework, $this->student, $this->student)->assertForbidden();
    }

    /** @return array<string, array{string, string}> */
    public static function strictRequests(): array
    {
        return ['query parameter' => ['?include=attempts', ''], 'request body' => ['', '{}']];
    }

    #[DataProvider('strictRequests')]
    public function test_the_read_takes_no_query_or_body(string $query, string $body): void
    {
        $homework = $this->officialHomework();
        $this->recipientOf($homework);

        $this->homeworkRaw($this->teacher, 'GET', $this->uri($homework, $this->student).$query, $body)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public function test_reads_outside_the_teachers_topics_or_recipients_are_not_found(): void
    {
        $homework = $this->officialHomework();
        $this->recipientOf($homework);
        $other = $this->homeworkTask();
        $otherRecipient = $this->studentNamed('Beta Student');
        $this->recipientOf($other, $otherRecipient);
        $foreignTeacher = User::factory()->teacher(Institution::factory()->create())->create(['must_change_password' => false]);
        $colleague = User::factory()->teacher($this->institution)->create(['must_change_password' => false]);
        GroupTeacherMembership::factory()->create(['institution_id' => $this->institution->id, 'group_id' => $this->group->id,
            'teacher_id' => $colleague->id, 'assigned_by_user_id' => $this->admin->id]);

        $this->read($homework, $this->student)->assertOk();
        foreach ([
            '/api/v1/teacher/assessments/not-a-uuid/students/'.$this->student->id.'/official-score',
            '/api/v1/teacher/assessments/'.$homework->id.'/students/not-a-uuid/official-score',
            '/api/v1/teacher/assessments/'.Str::uuid().'/students/'.$this->student->id.'/official-score',
            '/api/v1/teacher/assessments/'.$homework->id.'/students/'.Str::uuid().'/official-score',
            // A recipient of another task of the same Topic, and a non-recipient Student.
            $this->uri($homework, $otherRecipient),
            $this->uri($other, $this->student),
            // A Teacher is not a recipient.
            $this->uri($homework, $this->teacher),
        ] as $uri) {
            $this->homeworkRaw($this->teacher, 'GET', $uri, '')->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $this->read($homework, $this->student, $foreignTeacher)->assertNotFound();
        $this->read($homework, $this->student, $colleague)->assertNotFound();
        GroupTeacherMembership::query()->where('teacher_id', $this->teacher->id)->update(['ended_at' => now()]);
        $this->read($homework, $this->student)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
    }

    public function test_a_practice_task_is_not_applicable(): void
    {
        $this->officialHomework();
        $practice = $this->homeworkTask();
        $this->submission($practice, $this->student, 'checked');

        $this->assertNotReady($this->read($practice, $this->student), $practice, 'not_applicable');
    }

    public function test_a_ready_homework_score_reports_the_best_checked_attempt(): void
    {
        $homework = $this->officialHomework();
        $this->submission($homework, $this->student, 'checked');
        $best = $this->submission($homework, $this->student, 'checked', ['earned_points' => '17.50000000', 'normalized_score' => '87.50000000']);
        $this->resolve($homework);

        $this->assertSame([
            'assessment_id' => $homework->id, 'assessment_type' => 'homework', 'student_id' => $this->student->id,
            'status' => 'ready', 'official_attempt_id' => $best->id, 'attempt_number' => 2, 'normalized_score' => 87.5,
            'selection_policy_code' => 'highest_valid_completed', 'selected_at' => '2026-09-30T10:00:00Z',
        ], $this->read($homework, $this->student)->assertOk()->json('data'));
    }

    public function test_a_later_attempt_that_cannot_overtake_keeps_the_score_ready(): void
    {
        $homework = $this->officialHomework();
        $first = $this->submission($homework, $this->student, 'checked', ['earned_points' => '18.00000000', 'normalized_score' => '90.00000000']);
        // Its bound is 5 of 20 points = 25, below 90.
        $this->waitingAnswer($this->submission($homework, $this->student, 'waiting_for_teacher_review'), '5.000000');
        $this->resolve($homework);

        $data = $this->read($homework, $this->student)->assertOk()->json('data');

        $this->assertSame(['ready', $first->id, 1, 90], [$data['status'], $data['official_attempt_id'], $data['attempt_number'], $data['normalized_score']]);
    }

    public function test_a_submitted_attempt_awaiting_automatic_checking_holds_the_score_back(): void
    {
        $homework = $this->officialHomework();
        $this->submission($homework, $this->student, 'submitted');

        $this->assertNotReady($this->read($homework, $this->student), $homework, 'automatic_checking_pending');
    }

    public function test_a_timed_out_blitz_attempt_awaiting_automatic_checking_holds_the_score_back(): void
    {
        $blitz = $this->officialBlitz(BlitzStatus::Closed);
        $this->submission($blitz, $this->student, 'timed_out_finalized', ['submitted_at' => null, 'finalization_reason' => 'timeout_auto_submit']);

        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'automatic_checking_pending');
    }

    public function test_automatic_checking_is_reported_before_teacher_review_when_both_block(): void
    {
        $homework = $this->officialHomework();
        $this->waitingAnswer($this->submission($homework, $this->student, 'waiting_for_teacher_review'), '5.000000');
        $this->submission($homework, $this->student, 'submitted');

        $this->assertNotReady($this->read($homework, $this->student), $homework, 'automatic_checking_pending');
    }

    public function test_a_later_submitted_attempt_that_could_overtake_holds_a_checked_score_back(): void
    {
        $homework = $this->officialHomework();
        $this->submission($homework, $this->student, 'checked');
        $this->resolve($homework);
        $this->submission($homework, $this->student, 'submitted');

        $this->assertNotReady($this->read($homework, $this->student), $homework, 'automatic_checking_pending');
    }

    public function test_a_waiting_attempt_holds_the_score_back(): void
    {
        $homework = $this->officialHomework();
        $this->waitingAnswer($this->submission($homework, $this->student, 'waiting_for_teacher_review'), '5.000000');

        $this->assertNotReady($this->read($homework, $this->student), $homework, 'waiting_for_teacher_review');
    }

    public function test_a_waiting_attempt_that_could_overtake_holds_a_checked_score_back(): void
    {
        $homework = $this->officialHomework();
        $this->submission($homework, $this->student, 'checked');
        // Its bound is 20 of 20 points = 100, above 75.
        $this->waitingAnswer($this->submission($homework, $this->student, 'waiting_for_teacher_review'), '20.000000');
        $this->resolve($homework);

        $this->assertDatabaseCount('official_task_scores', 0);
        $this->assertNotReady($this->read($homework, $this->student), $homework, 'waiting_for_teacher_review');
    }

    public function test_a_missing_or_differing_row_is_reported_as_automatic_checking_pending(): void
    {
        $homework = $this->officialHomework();
        $lower = $this->submission($homework, $this->student, 'checked', ['earned_points' => '10.00000000', 'normalized_score' => '50.00000000']);
        $best = $this->submission($homework, $this->student, 'checked');

        $this->assertNotReady($this->read($homework, $this->student), $homework, 'automatic_checking_pending');

        $row = OfficialTaskScore::factory()->create(['official_attempt_id' => $best->id, 'normalized_score' => '70.00000000']);
        $this->assertNotReady($this->read($homework, $this->student), $homework, 'automatic_checking_pending');

        $row->update(['official_attempt_id' => $lower->id, 'normalized_score' => '50.00000000']);
        $this->assertNotReady($this->read($homework, $this->student), $homework, 'automatic_checking_pending');

        // A tie goes to the lower attempt number, so a row naming the later tied Attempt is stale.
        $tied = $this->submission($homework, $this->student, 'checked');
        $row->update(['official_attempt_id' => $tied->id, 'normalized_score' => '75.00000000']);
        $this->assertNotReady($this->read($homework, $this->student), $homework, 'automatic_checking_pending');

        $row->update(['official_attempt_id' => $best->id, 'normalized_score' => '75.00000000']);
        $this->read($homework, $this->student)->assertOk()->assertJsonPath('data.status', 'ready');
    }

    public function test_a_student_without_completed_work_has_no_completed_attempt(): void
    {
        $homework = $this->officialHomework();
        $this->recipientOf($homework);
        $this->assertNotReady($this->read($homework, $this->student), $homework, 'no_completed_attempt');

        $this->submission($homework, $this->student, 'in_progress');
        $this->assertNotReady($this->read($homework, $this->student), $homework, 'no_completed_attempt');
    }

    public function test_a_checked_normal_blitz_attempt_is_ready(): void
    {
        $blitz = $this->officialBlitz(BlitzStatus::Closed);
        $normal = $this->submission($blitz, $this->student, 'checked');
        $this->resolve($blitz);

        $data = $this->read($blitz, $this->student)->assertOk()->json('data');

        $this->assertSame(['blitz', 'ready', $normal->id, 1, 75, 'valid_normal_blitz'], [$data['assessment_type'], $data['status'],
            $data['official_attempt_id'], $data['attempt_number'], $data['normalized_score'], $data['selection_policy_code']]);
    }

    public function test_a_waiting_normal_blitz_attempt_holds_the_score_back(): void
    {
        $blitz = $this->officialBlitz(BlitzStatus::Closed);
        $this->submission($blitz, $this->student, 'waiting_for_teacher_review');

        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'waiting_for_teacher_review');
    }

    public function test_an_active_blitz_with_an_exception_waits_for_the_replacement(): void
    {
        $blitz = $this->officialBlitz(BlitzStatus::Active);
        $exception = $this->exception($blitz);
        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'waiting_for_replacement');

        $replacement = $this->submission($blitz, $this->student, 'in_progress');
        $exception->update(['replacement_attempt_id' => $replacement->id]);
        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'waiting_for_replacement');

        $replacement->update(['status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit']);
        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'automatic_checking_pending');

        $replacement->update(['status' => 'checked', 'earned_points' => '18.00000000', 'normalized_score' => '90.00000000',
            'scoring_completed_at' => now()]);
        $this->resolve($blitz);
        $data = $this->read($blitz, $this->student)->assertOk()->json('data');
        $this->assertSame(['ready', $replacement->id, 2, 90, 'approved_blitz_exception_replacement'], [$data['status'],
            $data['official_attempt_id'], $data['attempt_number'], $data['normalized_score'], $data['selection_policy_code']]);
    }

    public function test_a_closed_blitz_with_an_exception_and_no_replacement_has_no_completed_attempt(): void
    {
        $blitz = $this->officialBlitz(BlitzStatus::Closed);
        $this->exception($blitz);

        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'no_completed_attempt');
    }

    public function test_an_active_blitz_without_an_exception_never_waits_for_a_replacement(): void
    {
        $blitz = $this->officialBlitz(BlitzStatus::Active);
        $this->recipientOf($blitz);
        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'no_completed_attempt');

        $normal = $this->submission($blitz, $this->student, 'in_progress');
        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'no_completed_attempt');

        $normal->update(['status' => 'submitted', 'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => 'student_submit']);
        $this->assertNotReady($this->read($blitz, $this->student), $blitz, 'automatic_checking_pending');
    }

    public function test_an_archived_topic_still_reads(): void
    {
        $homework = $this->officialHomework();
        $this->submission($homework, $this->student, 'checked');
        $this->resolve($homework);
        $this->topic->update(['status' => 'archived', 'closed_at' => now(), 'archived_at' => now()]);

        $this->read($homework, $this->student)->assertOk()->assertJsonPath('data.status', 'ready');
    }

    /** @return array<string, array{string, string, string}> */
    public static function commitsBetweenTheSnapshotReads(): array
    {
        return [
            'exception grant' => ['grant', 'automatic_checking_pending', 'waiting_for_replacement'],
            'replacement start' => ['start_replacement', 'waiting_for_replacement', 'waiting_for_replacement'],
        ];
    }

    /**
     * Another connection commits right after the read's Attempt SELECT. Outside one snapshot the
     * following exception SELECT would see an exception that the Attempts do not match.
     */
    #[DataProvider('commitsBetweenTheSnapshotReads')]
    public function test_a_commit_between_the_attempt_and_exception_reads_is_not_seen(string $operation, string $during, string $after): void
    {
        $blitz = $this->officialBlitz(BlitzStatus::Active);
        $normal = $operation === 'grant' ? $this->submission($blitz, $this->student, 'submitted') : null;
        $exception = $operation === 'grant' ? null : $this->exception($blitz);
        config(['database.connections.concurrent' => config('database.connections.'.DB::getDefaultConnection())]);
        $concurrent = DB::connection('concurrent');
        [$committed, $snapshot] = [false, null];
        DB::listen(function (QueryExecuted $query) use (&$committed, &$snapshot, $concurrent, $operation, $blitz, $normal, $exception): void {
            if ($query->connectionName !== DB::getDefaultConnection()) {
                return;
            }
            if (str_starts_with($query->sql, 'SET TRANSACTION')) {
                $snapshot = $query->sql;
            }
            if ($committed || ! str_starts_with($query->sql, 'select * from "assessment_attempts"')) {
                return;
            }
            $committed = true;
            if ($operation === 'grant') {
                $concurrent->table('assessment_attempts')->where('id', $normal->id)->update(['official_score_eligible' => false]);
                $concurrent->table('blitz_attempt_exceptions')->insert(BlitzAttemptException::factory()->make([
                    'assessment_id' => $blitz->id, 'institution_id' => $blitz->institution_id,
                    'assessment_student_id' => $normal->assessment_student_id, 'student_id' => $this->student->id,
                    'invalidated_attempt_id' => $normal->id, 'granted_by_user_id' => $this->teacher->id,
                ])->forceFill(['id' => (string) Str::uuid(), 'created_at' => now(), 'updated_at' => now()])->getAttributes());
            } else {
                $replacement = (string) Str::uuid();
                $concurrent->table('assessment_attempts')->insert(AssessmentAttempt::factory()->make([
                    'assessment_student_id' => $exception->assessment_student_id, 'attempt_number' => 2,
                ])->forceFill(['id' => $replacement, 'created_at' => now(), 'updated_at' => now()])->getAttributes());
                $concurrent->table('blitz_attempt_exceptions')->where('id', $exception->id)->update(['replacement_attempt_id' => $replacement]);
            }
        });

        try {
            $response = $this->read($blitz, $this->student);
        } finally {
            DB::disconnect('concurrent');
        }

        $this->assertTrue($committed);
        $this->assertSame('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY', $snapshot);
        $this->assertNotReady($response, $blitz, $during);
        $this->assertNotReady($this->read($blitz, $this->student), $blitz, $after);
    }

    private function officialHomework(): Assessment
    {
        $homework = $this->homeworkTask();
        TopicResultPair::factory()->create(['homework_assessment_id' => $homework->id]);

        return $homework;
    }

    private function officialBlitz(BlitzStatus $status): Assessment
    {
        $blitz = $this->persistedBlitz($this->institution, $this->teacher, $this->topic, AssessmentAssignmentMode::Group, $status);
        $this->officialBlitzPair($blitz, $this->teacher);

        return $blitz;
    }

    /** Invalidates the Student's checked normal Attempt #1 by an approved exception. */
    private function exception(Assessment $blitz): BlitzAttemptException
    {
        $normal = $this->submission($blitz, $this->student, 'checked', ['official_score_eligible' => false]);

        return BlitzAttemptException::factory()->create([
            'assessment_id' => $blitz->id, 'assessment_student_id' => $normal->assessment_student_id,
            'invalidated_attempt_id' => $normal->id, 'granted_by_user_id' => $this->teacher->id,
        ]);
    }

    private function recipientOf(Assessment $assessment, ?User $student = null): AssessmentStudent
    {
        return $this->blitzRecipient($assessment, $student ?? $this->student, $this->teacher);
    }

    private function waitingAnswer(AssessmentAttempt $attempt, string $points): void
    {
        $answer = $this->answerInState($attempt, 'waiting_for_teacher_review');
        Question::query()->whereKey($answer->question_id)->update(['points' => $points]);
    }

    private function resolve(Assessment $assessment): void
    {
        $recipient = AssessmentStudent::query()->where('assessment_id', $assessment->id)->where('student_id', $this->student->id)->sole();
        app(OfficialTaskScoreResolver::class)->resolve($assessment->fresh(), $recipient,
            AssessmentAttempt::query()->where('assessment_student_id', $recipient->id)->get(), now());
    }

    private function uri(Assessment $assessment, User $student): string
    {
        return '/api/v1/teacher/assessments/'.$assessment->id.'/students/'.$student->id.'/official-score';
    }

    private function read(Assessment $assessment, User $student, ?User $teacher = null): TestResponse
    {
        return $this->homeworkRaw($teacher ?? $this->teacher, 'GET', $this->uri($assessment, $student), '');
    }

    private function assertNotReady(TestResponse $response, Assessment $assessment, string $status): void
    {
        $this->assertSame([
            'assessment_id' => $assessment->id, 'assessment_type' => $assessment->type->value, 'student_id' => $this->student->id,
            'status' => $status, 'official_attempt_id' => null, 'attempt_number' => null, 'normalized_score' => null,
            'selection_policy_code' => null, 'selected_at' => null,
        ], $response->assertOk()->json('data'));
    }
}
