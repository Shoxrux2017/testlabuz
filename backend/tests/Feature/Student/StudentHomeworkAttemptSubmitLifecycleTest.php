<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\TopicStatus;
use App\Models\AnswerTextValue;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\GroupStudentMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\Topic;
use App\Models\User;
use App\Support\Assessment\HomeworkAttemptFinalizer;
use Closure;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentHomeworkAttemptSubmitLifecycleTest extends TestCase
{
    use RefreshDatabase;

    private const ANSWER_TABLES = [
        'attempt_answers', 'answer_choice_selections', 'answer_boolean_values', 'answer_text_values',
        'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files', 'files',
    ];

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-10 12:00:00 UTC'));
    }

    #[DataProvider('inaccessibleAttempts')]
    public function test_preliminary_authorization_hides_inaccessible_attempts_before_any_idempotency_access(string $target): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $this->savedText($attempt, $question);
        $attemptId = $attempt->id;

        if ($target === 'other Student') {
            $student = $this->student($student->institution);
        } elseif ($target === 'foreign Institution') {
            $student = $this->student();
        } elseif ($target === 'malformed UUID') {
            $attemptId = 'malformed-attempt';
        } elseif ($target === 'unknown UUID') {
            $attemptId = (string) Str::uuid();
        } elseif ($target === 'broken recipient chain') {
            $otherRecipient = AssessmentStudent::factory()->create([
                'assessment_id' => $homework->assessment_id,
                'student_id' => $this->student($student->institution)->id,
            ]);
            $attempt->update(['assessment_student_id' => $otherRecipient->id]);
        } elseif ($target === 'Blitz Assessment') {
            $homework->assessment->update(['type' => AssessmentType::Blitz]);
        } elseif ($target === 'draft Homework') {
            $homework->update(['status' => 'draft', 'activated_at' => null]);
        } elseif ($target === 'missing Homework assignment') {
            $homework->delete();
        }

        $before = $this->persistentState();
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $this->submit($student, $attemptId)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertSame([], array_values(array_filter(
                DB::getQueryLog(),
                fn (array $query): bool => str_contains($query['query'], 'idempotency_records'),
            )));
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame($before, $this->persistentState());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function inaccessibleAttempts(): array
    {
        $cases = ['other Student', 'foreign Institution', 'malformed UUID', 'unknown UUID',
            'broken recipient chain', 'Blitz Assessment', 'draft Homework', 'missing Homework assignment'];

        return array_combine($cases, array_map(fn (string $case): array => [$case], $cases));
    }

    public function test_removed_group_membership_preserves_the_assigned_students_right_to_submit(): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $membership = GroupStudentMembership::factory()->create([
            'institution_id' => $student->institution_id,
            'group_id' => $homework->assessment->topic->group_id,
            'student_id' => $student->id,
        ]);
        $membership->delete();
        $this->savedText($attempt, $question);
        $answersBefore = $this->tableState(self::ANSWER_TABLES);

        $this->submit($student, $attempt->id)->assertOk()
            ->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.finalization_reason', 'student_submit');

        $this->assertSame($answersBefore, $this->tableState(self::ANSWER_TABLES));
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    #[DataProvider('lifecyclePrecedence')]
    public function test_homework_lifecycle_then_active_topic_consistency_precede_deadline_and_terminal_editability(
        string $homeworkState,
        ?string $topicState,
        string $code,
    ): void {
        [$student, $homework, $attempt, $question] = $this->fixture(homeworkState: $homeworkState);
        $homework->update(['deadline_at' => now()]);
        if ($topicState !== null) {
            $homework->assessment->topic->update(match ($topicState) {
                'draft' => ['status' => TopicStatus::Draft, 'activated_at' => null],
                'closed' => ['status' => TopicStatus::Closed, 'closed_at' => now()],
                'archived' => ['status' => TopicStatus::Archived, 'closed_at' => now(), 'archived_at' => now()],
            });
        }
        $attempt->update($this->submittedAttributes());
        $this->savedText($attempt, $question);
        $before = $this->persistentState();

        $this->submit($student, $attempt->id)->assertConflict()->assertJsonPath('code', $code);

        $this->assertSame($before, $this->persistentState());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function lifecyclePrecedence(): array
    {
        return [
            'closed Homework' => ['closed', null, 'task_closed'],
            'archived Homework' => ['archivedAfterClose', null, 'task_archived'],
            'closed Homework before inactive Topic' => ['closed', 'closed', 'task_closed'],
            'archived Homework before inactive Topic' => ['archivedAfterClose', 'archived', 'task_archived'],
            'active Homework under draft Topic' => ['active', 'draft', 'task_not_active'],
            'active Homework under closed Topic' => ['active', 'closed', 'task_not_active'],
            'active Homework under archived Topic' => ['active', 'archived', 'task_not_active'],
        ];
    }

    public function test_homework_becoming_draft_after_preliminary_authorization_returns_task_not_active_without_a_claim(): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $homework->update(['deadline_at' => now()]);
        $this->savedText($attempt, $question);
        $before = $this->persistentState();

        $this->afterPreliminaryAuthorization($student, $attempt->id, function () use ($homework): void {
            $homework->update(['status' => 'draft', 'activated_at' => null]);
        })->assertConflict()->assertJsonPath('code', 'task_not_active');

        $this->assertSame($before, $this->persistentState());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('terminalStatuses')]
    public function test_new_key_on_every_structurally_valid_terminal_status_preserves_timestamps_and_pending_answers(string $status): void
    {
        [$student, , $attempt, $question] = $this->fixture();
        $attempt->update(array_merge($this->submittedAttributes(), ['status' => $status]));
        $answer = $this->savedText($attempt, $question);
        $before = $this->persistentState();
        $this->travel(1)->minutes();

        $this->submit($student, $attempt->id)->assertConflict()->assertJsonPath('code', 'attempt_not_editable');

        $this->assertSame($before, $this->persistentState());
        $this->assertDatabaseHas('attempt_answers', [
            'id' => $answer->id, 'checking_status' => 'pending', 'awarded_points' => null,
            'feedback' => null, 'checked_by_user_id' => null, 'checked_at' => null,
        ]);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function terminalStatuses(): array
    {
        return ['submitted' => ['submitted'], 'waiting for review' => ['waiting_for_teacher_review'], 'checked' => ['checked']];
    }

    #[DataProvider('nonProgressFinalizerStatuses')]
    public function test_explicit_finalizer_returns_false_without_writes_for_every_non_progress_status(string $status): void
    {
        [, , $attempt, $question] = $this->fixture();
        $attempt->update(array_merge($this->submittedAttributes(), ['status' => $status]));
        $this->savedText($attempt, $question);
        $before = $this->persistentState();
        $this->travel(1)->minutes();
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $result = DB::transaction(function () use ($attempt): bool {
                $locked = AssessmentAttempt::query()->whereKey($attempt->id)->lockForUpdate()->firstOrFail();

                return $this->app->make(HomeworkAttemptFinalizer::class)->finalizeByStudentSubmit($locked, now());
            });
            $this->assertFalse($result);
            $this->assertSame([], array_values(array_filter(
                DB::getQueryLog(),
                fn (array $query): bool => preg_match('/^\s*(insert|update|delete)\b/i', $query['query']) === 1,
            )));
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame($before, $this->persistentState());
    }

    public static function nonProgressFinalizerStatuses(): array
    {
        return array_merge(self::terminalStatuses(), ['Blitz terminal status' => ['timed_out_finalized']]);
    }

    #[DataProvider('corruptFinalizationFields')]
    public function test_explicit_finalizer_rejects_each_corrupt_in_progress_field_as_logic_exception_without_writes(string $field): void
    {
        [, , $attempt, $question] = $this->fixture();
        $attempt->update([$field => $field === 'finalization_reason' ? AssessmentAttemptFinalizationReason::StudentSubmit : now()]);
        $this->savedText($attempt, $question);
        $before = $this->persistentState();
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            try {
                DB::transaction(function () use ($attempt): void {
                    $locked = AssessmentAttempt::query()->whereKey($attempt->id)->lockForUpdate()->firstOrFail();
                    $this->app->make(HomeworkAttemptFinalizer::class)->finalizeByStudentSubmit($locked, now());
                });
                $this->fail('An inconsistent in-progress Attempt must fail the finalizer invariant.');
            } catch (LogicException) {
                $this->assertSame([], array_values(array_filter(
                    DB::getQueryLog(),
                    fn (array $query): bool => preg_match('/^\s*(insert|update|delete)\b/i', $query['query']) === 1,
                )));
            }
        } finally {
            DB::disableQueryLog();
        }

        $this->assertSame($before, $this->persistentState());
    }

    public static function corruptFinalizationFields(): array
    {
        $fields = ['submitted_at', 'finalized_at', 'locked_at', 'finalization_reason'];

        return array_combine($fields, array_map(fn (string $field): array => [$field], $fields));
    }

    #[DataProvider('corruptStructuralStates')]
    public function test_corrupt_homework_attempt_state_is_a_safe_server_invariant_without_any_submit_mutation(string $corruption): void
    {
        [$student, , $attempt, $question] = $this->fixture();
        $this->savedText($attempt, $question);
        $attempt->update(match ($corruption) {
            'in-progress deadline' => ['deadline_at' => now()->addHour()],
            'terminal deadline' => array_merge($this->submittedAttributes(), ['deadline_at' => now()->addHour()]),
            'Blitz-only status' => ['status' => AssessmentAttemptStatus::TimedOutFinalized],
            'in-progress Blitz-only reason' => ['finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit],
            'terminal Blitz-only reason' => array_merge($this->submittedAttributes(), ['finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit]),
            'submitted_at' => ['submitted_at' => now()],
            'finalized_at' => ['finalized_at' => now()],
            'locked_at' => ['locked_at' => now()],
            'finalization_reason' => ['finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit],
        });
        $before = $this->persistentState();

        $this->assertSafeServerError($this->submit($student, $attempt->id));

        $this->assertSame($before, $this->persistentState());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function corruptStructuralStates(): array
    {
        $cases = ['in-progress deadline', 'terminal deadline', 'Blitz-only status',
            'in-progress Blitz-only reason', 'terminal Blitz-only reason',
            'submitted_at', 'finalized_at', 'locked_at', 'finalization_reason'];

        return array_combine($cases, array_map(fn (string $case): array => [$case], $cases));
    }

    #[DataProvider('postAuthorizationDrift')]
    public function test_post_authorization_disappearance_or_identity_drift_is_a_safe_server_invariant_and_never_substitutes_an_attempt(string $drift): void
    {
        [$student, $homework, $attempt] = $this->fixture();
        $otherStudent = $this->student($student->institution);
        [$foreignStudent, , $foreignAttempt] = $this->fixture();
        [, , $otherAttempt] = $this->fixture($student);
        $foreignAttempt->update($this->submittedAttributes());
        $otherAttempt->update($this->submittedAttributes());
        $otherRecipient = AssessmentStudent::factory()->create([
            'assessment_id' => $homework->assessment_id, 'student_id' => $otherStudent->id,
        ]);
        $before = $this->persistentState();
        $attemptId = $attempt->id;

        $this->withoutExceptionHandling();
        try {
            $this->afterPreliminaryAuthorization($student, $attemptId, function () use (
                $drift, $attemptId, $foreignStudent, $foreignAttempt, $otherStudent, $otherAttempt, $otherRecipient,
            ): void {
                $attemptQuery = DB::table('assessment_attempts')->where('id', $attemptId);
                if ($drift === 'disappearance') {
                    $attemptQuery->delete();
                } else {
                    $attemptQuery->update(match ($drift) {
                        'Attempt identity' => ['id' => (string) Str::uuid()],
                        'Institution identity' => [
                            'institution_id' => $foreignStudent->institution_id, 'student_id' => $foreignStudent->id,
                            'assessment_id' => $foreignAttempt->assessment_id,
                            'assessment_student_id' => $foreignAttempt->assessment_student_id, 'attempt_number' => 2,
                        ],
                        'Student identity' => ['student_id' => $otherStudent->id],
                        'Assessment identity' => ['assessment_id' => $otherAttempt->assessment_id, 'attempt_number' => 2],
                        'authoritative recipient' => ['assessment_student_id' => $otherRecipient->id],
                    });
                }
            });
            $this->fail('Post-authorization drift must fail as a Homework Attempt invariant.');
        } catch (LogicException) {
            $this->assertSame($before, $this->persistentState());
        }

        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function postAuthorizationDrift(): array
    {
        $cases = ['disappearance', 'Attempt identity', 'Institution identity', 'Student identity',
            'Assessment identity', 'authoritative recipient'];

        return array_combine($cases, array_map(fn (string $case): array => [$case], $cases));
    }

    #[DataProvider('deadlineOffsets')]
    public function test_exact_or_past_deadline_commits_all_due_finalization_before_conflict_without_a_submit_claim_or_fabricated_attempt(int $offset): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $deadline = now()->addSeconds($offset);
        $homework->update(['deadline_at' => $deadline]);
        $this->savedText($attempt, $question);
        $otherRecipient = AssessmentStudent::factory()->create([
            'assessment_id' => $homework->assessment_id,
            'student_id' => $this->student($student->institution)->id,
        ]);
        $otherAttempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $otherRecipient->id, 'started_at' => now()->subHour(),
        ]);
        $neverStarted = AssessmentStudent::factory()->create([
            'assessment_id' => $homework->assessment_id,
            'student_id' => $this->student($student->institution)->id,
        ]);
        $answersBefore = $this->tableState(self::ANSWER_TABLES);
        $homeworkBefore = $homework->fresh()->getAttributes();

        $this->submit($student, $attempt->id)->assertConflict()->assertJsonPath('code', 'deadline_passed');

        foreach ([$attempt, $otherAttempt] as $dueAttempt) {
            $dueAttempt->refresh();
            $this->assertSame(AssessmentAttemptStatus::Submitted, $dueAttempt->status);
            $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $dueAttempt->finalization_reason);
            $this->assertNull($dueAttempt->submitted_at);
            $this->assertTrue($deadline->equalTo($dueAttempt->finalized_at));
            $this->assertTrue($deadline->equalTo($dueAttempt->locked_at));
            $this->assertNull($dueAttempt->earned_points);
            $this->assertNull($dueAttempt->normalized_score);
            $this->assertNull($dueAttempt->scoring_completed_at);
        }
        $this->assertSame($answersBefore, $this->tableState(self::ANSWER_TABLES));
        $this->assertSame($homeworkBefore, $homework->fresh()->getAttributes());
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_student_id' => $neverStarted->id]);
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function deadlineOffsets(): array
    {
        return ['exact deadline' => [0], 'past deadline' => [-1]];
    }

    public function test_deadline_precedes_valid_terminal_attempt_editability_and_preserves_the_earlier_explicit_submit(): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $attempt->update($this->submittedAttributes());
        $this->savedText($attempt, $question);
        $homework->update(['deadline_at' => now()->addSecond()]);
        $this->travel(1)->seconds();
        $before = $this->persistentState();

        $this->submit($student, $attempt->id)->assertConflict()->assertJsonPath('code', 'deadline_passed');

        $this->assertSame($before, $this->persistentState());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_submit_just_before_deadline_records_one_explicit_instant_and_preserves_saved_answers(): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $homework->update(['deadline_at' => now()->addSecond()]);
        $this->savedText($attempt, $question);
        $answersBefore = $this->tableState(self::ANSWER_TABLES);
        $submittedAt = now();

        $this->submit($student, $attempt->id)->assertOk()
            ->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.finalization_reason', 'student_submit');

        $attempt->refresh();
        $this->assertSame(AssessmentAttemptStatus::Submitted, $attempt->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::StudentSubmit, $attempt->finalization_reason);
        foreach (['submitted_at', 'finalized_at', 'locked_at'] as $field) {
            $this->assertTrue($submittedAt->equalTo($attempt->{$field}));
        }
        $this->assertSame($answersBefore, $this->tableState(self::ANSWER_TABLES));
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 1);
    }

    private function student(?Institution $institution = null): User
    {
        if ($institution === null) {
            $institution = Institution::factory()->create();
            InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        }

        return User::factory()->student($institution)->create(['must_change_password' => false]);
    }

    private function fixture(?User $student = null, string $homeworkState = 'active'): array
    {
        $student ??= $this->student();
        $topic = Topic::factory()->active()->create(['institution_id' => $student->institution_id]);
        $assessment = Assessment::factory()->homework()->create([
            'institution_id' => $student->institution_id, 'topic_id' => $topic->id,
            'teacher_id' => $topic->teacher_id, 'total_possible_points' => '1.000000',
        ]);
        $homework = HomeworkAssignment::factory()->{$homeworkState}()->create([
            'assessment_id' => $assessment->id, 'deadline_at' => now()->addHour(),
        ]);
        $recipient = AssessmentStudent::factory()->create([
            'assessment_id' => $assessment->id, 'student_id' => $student->id,
            'assigned_by_user_id' => $assessment->teacher_id,
        ]);
        $attempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id, 'started_at' => now()->subHour(),
        ]);
        $question = Question::factory()->shortWrittenAutomatic()->create(['assessment_id' => $assessment->id]);

        return [$student, $homework, $attempt, $question];
    }

    private function savedText(AssessmentAttempt $attempt, Question $question): AttemptAnswer
    {
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        AnswerTextValue::factory()->create(['answer_id' => $answer->id, 'text_value' => 'Preserve this Student answer.']);

        return $answer;
    }

    private function submittedAttributes(): array
    {
        return [
            'status' => AssessmentAttemptStatus::Submitted,
            'submitted_at' => now(), 'finalized_at' => now(), 'locked_at' => now(),
            'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit,
        ];
    }

    private function submit(User $student, string $attemptId): TestResponse
    {
        try {
            return $this->call('POST', '/api/v1/student/attempts/'.$attemptId.'/submit', [], [], [], [
                'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('student-submit-lifecycle-test')->plainTextToken,
                'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
            ], '');
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }

    private function afterPreliminaryAuthorization(User $student, string $attemptId, Closure $interleave): TestResponse
    {
        $interleaved = false;
        $interleaveCompleted = false;
        DB::listen(function (QueryExecuted $query) use ($interleave, &$interleaved, &$interleaveCompleted): void {
            if (! $interleaved && str_contains($query->sql, 'from "topics"') && str_contains($query->sql, 'for share')) {
                $interleaved = true;
                $interleave();
                $interleaveCompleted = true;
            }
        });

        try {
            return $this->submit($student, $attemptId);
        } finally {
            $this->assertTrue($interleaved, 'The fixture must change only after preliminary authorization reaches the locked parent chain.');
            $this->assertTrue($interleaveCompleted, 'The fixture interleave must finish before the Submit invariant is evaluated.');
        }
    }

    private function persistentState(): array
    {
        return $this->tableState([
            'assessment_attempts', 'assessment_students', 'homework_assignments', 'topic_result_pairs',
            'idempotency_records', ...self::ANSWER_TABLES,
        ]);
    }

    private function tableState(array $tables): array
    {
        $snapshot = [];
        foreach ($tables as $table) {
            $snapshot[$table] = DB::table($table)->get()
                ->map(fn (object $row): string => json_encode($row, JSON_THROW_ON_ERROR))->sort()->values()->all();
        }

        return $snapshot;
    }

    private function assertSafeServerError(TestResponse $response): void
    {
        $response->assertStatus(500)->assertExactJson([
            'message' => 'An unexpected server error occurred.', 'code' => 'server_error', 'errors' => [],
        ]);
    }
}
