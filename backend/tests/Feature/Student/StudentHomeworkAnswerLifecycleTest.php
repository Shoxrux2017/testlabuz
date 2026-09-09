<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\TopicStatus;
use App\Models\AnswerBooleanValue;
use App\Models\AnswerFile;
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
use App\Models\QuestionChoiceOption;
use App\Models\Topic;
use App\Models\User;
use Closure;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentHomeworkAnswerLifecycleTest extends TestCase
{
    use RefreshDatabase;

    private const ANSWER_TABLES = [
        'attempt_answers', 'answer_choice_selections', 'answer_boolean_values', 'answer_text_values',
        'answer_matching_pairs', 'answer_ordering_items', 'answer_fill_blank_values', 'answer_files',
    ];

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
    }

    public function test_preliminary_access_hides_other_students_foreign_attempts_wrong_assessment_questions_and_malformed_ids(): void
    {
        [$student, , $attempt, $question] = $this->fixture();
        [, $otherHomework, $otherAttempt, $otherQuestion] = $this->fixture($this->student($student->institution));
        [, $foreignHomework, $foreignAttempt, $foreignQuestion] = $this->fixture();
        $otherHomework->update(['deadline_at' => now()]);
        $foreignHomework->update(['deadline_at' => now()]);
        $this->savedText($otherAttempt, $otherQuestion);
        $this->savedText($foreignAttempt, $foreignQuestion);
        $attemptsBefore = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $answersBefore = $this->answerState();

        foreach ([
            [$otherAttempt->id, $otherQuestion->id],
            [$foreignAttempt->id, $foreignQuestion->id],
            [$attempt->id, $otherQuestion->id],
            [$attempt->id, $foreignQuestion->id],
            ['malformed-attempt', $question->id],
            [(string) Str::uuid(), $question->id],
            [$attempt->id, 'malformed-question'],
            [$attempt->id, (string) Str::uuid()],
        ] as [$attemptId, $questionId]) {
            $this->withoutAnswerWrites(fn () => $this->requestAs(
                $student,
                'PUT',
                '/api/v1/student/attempts/'.$attemptId.'/answers/'.$questionId,
                ['type' => 'short_written', 'text' => 'Replacement'],
            ), true)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($attemptsBefore, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
    }

    public function test_ended_group_membership_preserves_assigned_own_attempt_editability(): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        GroupStudentMembership::factory()->ended()->create([
            'institution_id' => $student->institution_id,
            'group_id' => $homework->assessment->topic->group_id,
            'student_id' => $student->id,
        ]);
        $attemptBefore = $attempt->fresh()->getAttributes();

        $this->save($student, $attempt, $question, '  Persisted assignment remains authoritative.  ')
            ->assertOk()->assertJsonPath('data.answer.text', '  Persisted assignment remains authoritative.  ');

        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('attempt_answers', 1);
        $this->assertDatabaseCount('answer_text_values', 1);
    }

    #[DataProvider('terminalAttemptStatuses')]
    public function test_structurally_valid_terminal_attempt_is_not_editable_without_mutating_saved_answers(string $status): void
    {
        [$student, , $attempt, $question] = $this->fixture();
        $attempt->update(array_merge($this->submittedAttributes(), ['status' => $status]));
        $this->savedText($attempt, $question);
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->answerState();

        $this->withoutAnswerWrites(fn () => $this->save($student, $attempt, $question, 'Replacement'), true)
            ->assertConflict()->assertJsonPath('code', 'attempt_not_editable')
            ->assertJsonPath('message', 'This Homework attempt is no longer editable.');

        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function terminalAttemptStatuses(): array
    {
        return [
            'explicit submission' => ['submitted'],
            'waiting for review' => ['waiting_for_teacher_review'],
            'checked' => ['checked'],
        ];
    }

    #[DataProvider('corruptAttemptMutations')]
    public function test_corrupt_locked_homework_attempt_fails_as_a_server_invariant_before_creating_replacing_clearing_or_noop(
        string $corruption,
        string $mutation,
    ): void {
        [$student, , $attempt, $question] = $this->fixture();
        if ($mutation !== 'create') {
            $this->savedText($attempt, $question);
        }
        $attempt->update(match ($corruption) {
            'homework attempt deadline' => ['deadline_at' => now()->addDay()],
            'blitz status' => ['status' => AssessmentAttemptStatus::TimedOutFinalized],
            'blitz reason' => array_merge($this->submittedAttributes(), ['finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit]),
            'submitted timestamp' => ['submitted_at' => now()],
            'finalized timestamp' => ['finalized_at' => now()],
            'locked timestamp' => ['locked_at' => now()],
            'finalization reason' => ['finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit],
        });
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->answerState();
        $text = match ($mutation) {
            'clear' => '',
            'noop' => 'Original Student answer',
            default => 'Replacement Student answer',
        };

        $response = $this->withoutAnswerWrites(fn () => $this->save($student, $attempt, $question, $text), true);

        $this->assertSafeServerError($response);
        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function corruptAttemptMutations(): array
    {
        $cases = [];
        foreach ([
            'homework attempt deadline', 'blitz status', 'blitz reason', 'submitted timestamp',
            'finalized timestamp', 'locked timestamp', 'finalization reason',
        ] as $corruption) {
            foreach (['create', 'replace', 'clear', 'noop'] as $mutation) {
                $cases[$corruption.' before '.$mutation] = [$corruption, $mutation];
            }
        }

        return $cases;
    }

    #[DataProvider('lifecyclePrecedence')]
    public function test_homework_lifecycle_precedes_deadline_and_attempt_corruption_without_any_mutation(
        string $homeworkState,
        bool $inactiveTopic,
        string $code,
    ): void {
        [$student, $homework, $attempt, $question] = $this->fixture(homeworkState: $homeworkState);
        $homework->update(['deadline_at' => now()]);
        if ($inactiveTopic) {
            $homework->assessment->topic->update(['status' => TopicStatus::Closed, 'closed_at' => now()]);
        }
        $attempt->update(['submitted_at' => now()]);
        $this->savedText($attempt, $question);
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->answerState();

        $this->withoutAnswerWrites(fn () => $this->save($student, $attempt, $question, 'Replacement'), true)
            ->assertConflict()->assertJsonPath('code', $code);

        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function lifecyclePrecedence(): array
    {
        return [
            'teacher closed' => ['closed', false, 'task_closed'],
            'archived' => ['archivedAfterClose', false, 'task_archived'],
            'closed before inactive Topic' => ['closed', true, 'task_closed'],
            'archived before inactive Topic' => ['archivedAfterClose', true, 'task_archived'],
            'active Homework under inactive Topic' => ['active', true, 'task_not_active'],
        ];
    }

    #[DataProvider('dueSaves')]
    public function test_exact_and_past_deadlines_reconcile_due_attempts_without_creating_replacing_or_clearing_answers(
        int $offset,
        string $mutation,
    ): void {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $deadline = now()->addSeconds($offset);
        $homework->update(['deadline_at' => $deadline]);
        if ($mutation !== 'create') {
            $this->savedText($attempt, $question);
        }
        $otherStudent = $this->student($student->institution);
        $otherRecipient = AssessmentStudent::factory()->create([
            'assessment_id' => $homework->assessment_id, 'student_id' => $otherStudent->id,
        ]);
        $otherAttempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $otherRecipient->id, 'started_at' => now()->subHour(),
        ]);
        $answersBefore = $this->answerState();
        $homeworkBefore = $homework->fresh()->getAttributes();

        $this->withoutAnswerWrites(fn () => $this->save($student, $attempt, $question, $mutation === 'clear' ? '' : 'Late replacement'))
            ->assertConflict()->assertJsonPath('code', 'deadline_passed');

        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($homeworkBefore, $homework->fresh()->getAttributes());
        foreach ([$attempt, $otherAttempt] as $dueAttempt) {
            $dueAttempt->refresh();
            $this->assertSame(AssessmentAttemptStatus::Submitted, $dueAttempt->status);
            $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $dueAttempt->finalization_reason);
            $this->assertTrue($deadline->equalTo($dueAttempt->finalized_at));
            $this->assertTrue($deadline->equalTo($dueAttempt->locked_at));
            $this->assertNull($dueAttempt->submitted_at);
            $this->assertNull($dueAttempt->earned_points);
            $this->assertNull($dueAttempt->normalized_score);
            $this->assertNull($dueAttempt->scoring_completed_at);
        }
    }

    public static function dueSaves(): array
    {
        $cases = [];
        foreach (['exact deadline' => 0, 'after deadline' => -1] as $boundary => $offset) {
            foreach (['create', 'replace', 'clear'] as $mutation) {
                $cases[$boundary.' '.$mutation] = [$offset, $mutation];
            }
        }

        return $cases;
    }

    public function test_deadline_precedes_terminal_attempt_editability(): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $homework->update(['deadline_at' => now()]);
        $attempt->update($this->submittedAttributes());
        $this->savedText($attempt, $question);
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->answerState();

        $this->withoutAnswerWrites(fn () => $this->save($student, $attempt, $question, 'Late replacement'), true)
            ->assertConflict()->assertJsonPath('code', 'deadline_passed');

        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public function test_save_just_before_deadline_succeeds_without_touching_attempt_fields(): void
    {
        [$student, $homework, $attempt, $question] = $this->fixture();
        $homework->update(['deadline_at' => now()->addSecond()]);
        $attemptBefore = $attempt->fresh()->getAttributes();

        $this->save($student, $attempt, $question, 'On time')->assertOk()->assertJsonPath('data.answer.text', 'On time');

        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public function test_repeated_same_text_is_write_free_and_preserves_parent_child_and_attempt_timestamps(): void
    {
        [$student, , $attempt, $question] = $this->fixture();
        $original = $this->save($student, $attempt, $question, '  Exact Student text  ')->assertOk()->json('data');
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->answerState();

        foreach ([1, 2] as $minutes) {
            $this->travel($minutes)->minutes();
            $response = $this->withoutAnswerWrites(fn () => $this->save($student, $attempt, $question, '  Exact Student text  '), true)->assertOk();
            $this->assertSame($original, $response->json('data'));
            $this->assertSame($answersBefore, $this->answerState());
            $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        }
    }

    public function test_clear_when_absent_is_write_free_and_returns_an_unanswered_state(): void
    {
        [$student, , $attempt, $question] = $this->fixture();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->answerState();

        $this->withoutAnswerWrites(fn () => $this->save($student, $attempt, $question, ''), true)->assertOk()->assertExactJson([
            'data' => ['question_id' => $question->id, 'type' => 'short_written', 'answer' => null, 'updated_at' => null],
        ]);

        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    #[DataProvider('corruptReadGraphs')]
    public function test_get_and_start_resume_reject_corrupt_persisted_answers_as_safe_server_invariants_without_repair(
        string $corruption,
        bool $resume,
    ): void {
        [$student, $homework, $attempt, $question] = $this->fixture();
        if ($corruption === 'wrong Question choice child') {
            $question->update(['type' => 'single_choice']);
            QuestionChoiceOption::factory()->create(['question_id' => $question->id, 'is_correct' => true]);
            $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
            $otherQuestion = Question::factory()->singleChoice()->create(['assessment_id' => $homework->assessment_id, 'position' => 2]);
            $option = QuestionChoiceOption::factory()->create(['question_id' => $otherQuestion->id]);
            $answer->selectedOptions()->attach($option->id, ['institution_id' => $student->institution_id, 'created_at' => now()]);
        } elseif ($corruption === 'missing typed payload') {
            $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        } else {
            $answer = $this->savedText($attempt, $question);
            if ($corruption === 'Question from another Assessment') {
                $otherAssessment = Assessment::factory()->homework()->create(['institution_id' => $student->institution_id]);
                $otherQuestion = Question::factory()->shortWrittenAutomatic()->create(['assessment_id' => $otherAssessment->id]);
                $answer->update(['question_id' => $otherQuestion->id]);
            } elseif ($corruption === 'mixed typed families') {
                AnswerBooleanValue::factory()->create(['answer_id' => $answer->id, 'boolean_value' => true]);
            } else {
                AnswerFile::factory()->create(['answer_id' => $answer->id]);
            }
        }
        $answersBefore = $this->answerState();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->travel(1)->minutes();
        $request = fn (): TestResponse => $resume
            ? $this->requestAs($student, 'POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts')
            : $this->requestAs($student, 'GET', '/api/v1/student/attempts/'.$attempt->id);

        $this->withoutExceptionHandling();
        try {
            $request();
            $this->fail('Persisted answer corruption must reach the API boundary as a LogicException.');
        } catch (LogicException) {
            $this->assertSame($answersBefore, $this->answerState());
            $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        } finally {
            $this->withExceptionHandling();
        }

        $response = $this->withoutAnswerWrites($request, true);
        $this->assertSafeServerError($response);
        foreach ([$answer->id, $question->id, ...array_keys($answersBefore), 'SQL', 'LogicException',
            'question_id', 'option_id', 'answer_id', 'is_correct', 'correct_value', 'accepted_answers',
            'correct_position', 'match_key', 'checking_status', 'awarded_points', 'Original Student answer'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
        foreach ($answersBefore as $rows) {
            foreach ($rows as $row) {
                foreach (json_decode($row, true, flags: JSON_THROW_ON_ERROR) as $field => $value) {
                    if ($value !== null && ($field === 'id' || str_ends_with($field, '_id'))) {
                        $this->assertStringNotContainsString($value, $response->getContent());
                    }
                }
            }
        }
        $this->assertSame($answersBefore, $this->answerState());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    public static function corruptReadGraphs(): array
    {
        $cases = [];
        foreach ([
            'Question from another Assessment', 'wrong Question choice child', 'mixed typed families',
            'missing typed payload', 'non-file Answer with file',
        ] as $corruption) {
            foreach (['GET' => false, 'Start/resume' => true] as $surface => $resume) {
                $cases[$surface.' '.$corruption] = [$corruption, $resume];
            }
        }

        return $cases;
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
        AnswerTextValue::factory()->create(['answer_id' => $answer->id, 'text_value' => 'Original Student answer']);

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

    private function save(User $student, AssessmentAttempt $attempt, Question $question, string $text): TestResponse
    {
        return $this->requestAs($student, 'PUT', '/api/v1/student/attempts/'.$attempt->id.'/answers/'.$question->id, [
            'type' => 'short_written', 'text' => $text,
        ]);
    }

    private function requestAs(User $student, string $method, string $uri, ?array $payload = null): TestResponse
    {
        $server = [
            'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('student-answer-lifecycle-test')->plainTextToken,
        ];
        if ($method === 'POST') {
            $server['HTTP_IDEMPOTENCY_KEY'] = (string) Str::uuid();
        }

        try {
            return $this->call($method, $uri, [], [], [], $server, $payload === null ? '' : json_encode($payload, JSON_THROW_ON_ERROR));
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }

    private function answerState(): array
    {
        $snapshot = [];
        foreach ([...self::ANSWER_TABLES, 'files'] as $table) {
            $snapshot[$table] = DB::table($table)->get()->map(fn (object $row): string => json_encode($row, JSON_THROW_ON_ERROR))->sort()->values()->all();
        }

        return $snapshot;
    }

    private function withoutAnswerWrites(Closure $request, bool $includeAttempt = false): TestResponse
    {
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $response = $request();
            $tables = $includeAttempt ? [...self::ANSWER_TABLES, 'assessment_attempts'] : self::ANSWER_TABLES;
            $writes = array_filter(DB::getQueryLog(), function (array $query) use ($tables): bool {
                if (! preg_match('/^\s*(insert|update|delete)\b/i', $query['query'])) {
                    return false;
                }
                foreach ($tables as $table) {
                    if (str_contains($query['query'], '"'.$table.'"')) {
                        return true;
                    }
                }

                return false;
            });
            $this->assertSame([], array_values($writes), 'The request must not issue answer or protected Attempt writes.');

            return $response;
        } finally {
            DB::disableQueryLog();
        }
    }

    private function assertSafeServerError(TestResponse $response): void
    {
        $response->assertStatus(500)->assertExactJson([
            'message' => 'An unexpected server error occurred.', 'code' => 'server_error', 'errors' => [],
        ]);
    }
}
