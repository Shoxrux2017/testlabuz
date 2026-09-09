<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\TopicStatus;
use App\Enums\UserRole;
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
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentHomeworkAttemptStartApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
    }

    public function test_exact_routes_use_student_middleware_and_all_authentication_and_role_gates(): void
    {
        $expected = [
            'api/v1/student/homework/{homework}/attempts' => ['POST'],
            'api/v1/student/attempts/{attempt}' => ['GET'],
        ];
        foreach ($expected as $uri => $methods) {
            $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === $uri);
            $this->assertCount(1, $routes);
            $this->assertSame($methods, array_values(array_diff($routes->sole()->methods(), ['HEAD'])));
            $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'], $routes->sole()->middleware());
        }

        $student = $this->student();
        $actors = [
            [$this->student($student->institution, ['is_active' => false]), 'user_inactive'],
            [$this->student($student->institution, ['must_change_password' => true]), 'password_change_required'],
            [$this->student(Institution::factory()->inactive()->create()), 'institution_inactive'],
        ];
        foreach ([UserRole::Teacher, UserRole::InstitutionAdmin, UserRole::Parent, UserRole::PlatformOwner] as $role) {
            $actors[] = [$role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($student->institution)->create(['role' => $role, 'must_change_password' => false]), 'forbidden'];
        }

        foreach (['POST' => $this->startUri((string) Str::uuid()), 'GET' => '/api/v1/student/attempts/'.Str::uuid()] as $method => $uri) {
            $this->requestAs(null, $method, $uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
            foreach ($actors as [$actor, $code]) {
                $this->requestAs($actor, $method, $uri)->assertForbidden()->assertJsonPath('code', $code);
            }
        }
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('invalidStartRequests')]
    public function test_post_rejects_invalid_headers_bodies_and_query_parameters(?string $key, string $body, string $contentType, string $query): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $response = $this->requestAs($student, 'POST', $this->startUri($homework->assessment_id).$query, $key, $body, $contentType)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        if ($key === null || $key === 'invalid-uuid') {
            $response->assertJsonValidationErrors('idempotency_key');
        }
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function invalidStartRequests(): array
    {
        $key = '10000000-0000-4000-8000-000000000001';

        return [
            'missing key' => [null, '', 'application/json', ''],
            'malformed key' => ['invalid-uuid', '', 'application/json', ''],
            'non-empty object' => [$key, '{"attempt_number":2}', 'application/json', ''],
            'empty array' => [$key, '[]', 'application/json', ''],
            'non-empty array' => [$key, '[1]', 'application/json', ''],
            'null' => [$key, 'null', 'application/json', ''],
            'string scalar' => [$key, '"hello"', 'application/json', ''],
            'number scalar' => [$key, '1', 'application/json', ''],
            'boolean scalar' => [$key, 'false', 'application/json', ''],
            'malformed JSON' => [$key, '{', 'application/json', ''],
            'non-JSON body' => [$key, 'attempt_number=2', 'application/x-www-form-urlencoded', ''],
            'query key' => [$key, '', 'application/json', '?unexpected=1'],
        ];
    }

    #[DataProvider('acceptedStartRequests')]
    public function test_create_persists_exact_attempt_fields_and_only_the_safe_public_resource(string $body, bool $hasDeadline): void
    {
        $student = $this->student();
        $homework = $this->homework($student, attributes: ['deadline_at' => $hasDeadline ? now()->addDay() : null]);
        $recipient = $this->recipientFor($homework, $student);
        $response = $this->requestAs($student, 'POST', $this->startUri($homework->assessment_id), strtoupper((string) Str::uuid()), $body)
            ->assertCreated();
        $attempt = AssessmentAttempt::query()->sole();

        $this->assertSame([
            'id' => $attempt->id, 'assessment_id' => $homework->assessment_id,
            'attempt_number' => 1, 'status' => 'in_progress', 'started_at' => '2026-09-09T12:00:00Z',
            'submitted_at' => null, 'finalized_at' => null, 'finalization_reason' => null,
            'deadline_at' => $hasDeadline ? '2026-09-10T12:00:00Z' : null, 'questions' => [], 'answers' => [],
        ], $response->json('data'));
        $this->assertSame(['data'], array_keys($response->json()));
        $this->assertTrue(Str::isUuid($attempt->id));
        $this->assertDatabaseHas('assessment_attempts', [
            'id' => $attempt->id, 'institution_id' => $student->institution_id,
            'assessment_id' => $homework->assessment_id, 'assessment_student_id' => $recipient->id,
            'student_id' => $student->id, 'attempt_number' => 1, 'status' => 'in_progress',
            'started_at' => '2026-09-09 12:00:00', 'deadline_at' => null, 'submitted_at' => null,
            'finalized_at' => null, 'finalization_reason' => null, 'locked_at' => null,
            'official_score_eligible' => true, 'earned_points' => null, 'possible_points' => '7.250000',
            'normalized_score' => null, 'scoring_completed_at' => null,
        ]);
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertDatabaseCount('files', 0);
    }

    public static function acceptedStartRequests(): array
    {
        return ['empty body and null deadline' => ['', false], 'empty object and future deadline' => ['{}', true]];
    }

    public function test_different_key_resumes_without_changing_attempt_timestamps(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $created = $this->start($student, $homework)->assertCreated();
        $before = AssessmentAttempt::query()->sole()->getAttributes();
        $this->travel(2)->minutes();

        $this->start($student, $homework)->assertOk()->assertJsonPath('data.id', $created->json('data.id'))
            ->assertJsonPath('data.attempt_number', 1)->assertJsonPath('data.started_at', '2026-09-09T12:00:00Z');

        $this->assertSame($before, AssessmentAttempt::query()->sole()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 2);
    }

    public function test_normal_attempts_allocate_two_then_three_resume_three_and_exhaust_only_after_completion(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $this->attempt($homework, $student, 1, true);
        foreach ([2, 3] as $number) {
            $response = $this->start($student, $homework)->assertCreated()->assertJsonPath('data.attempt_number', $number);
            $attempt = AssessmentAttempt::query()->findOrFail($response->json('data.id'));
            if ($number === 3) {
                $before = $attempt->getAttributes();
                $this->start($student, $homework)->assertOk()->assertJsonPath('data.id', $attempt->id);
                $this->assertSame($before, $attempt->fresh()->getAttributes());
            }
            $attempt->update($this->completedAttributes());
        }
        $recordsBefore = DB::table('idempotency_records')->count();
        $this->start($student, $homework)->assertConflict()->assertJsonPath('code', 'attempts_exhausted')
            ->assertJsonPath('message', 'No Homework attempts remain.');
        $this->assertSame([1, 2, 3], AssessmentAttempt::query()->orderBy('attempt_number')->pluck('attempt_number')->all());
        $this->assertDatabaseCount('idempotency_records', $recordsBefore);
    }

    #[DataProvider('corruptedHistory')]
    public function test_corrupt_history_is_an_invariant_before_resume_capacity_or_pair_mutation(string $corruption): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $attempt = $this->attempt($homework, $student);
        $pair = TopicResultPair::factory()->create(['homework_assessment_id' => $homework->assessment_id, 'cohort_snapshotted_at' => now()]);
        if ($corruption === 'wrong assessment recipient') {
            $wrong = $this->recipientFor($this->homework($student), $student);
            $attempt->update(['assessment_student_id' => $wrong->id]);
        } elseif ($corruption === 'wrong student recipient') {
            $other = $this->student($student->institution);
            $wrong = AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id, 'student_id' => $other->id]);
            $attempt->update(['assessment_student_id' => $wrong->id]);
        } elseif ($corruption === 'gap 2') {
            $attempt->update(['attempt_number' => 2]);
        } elseif ($corruption === 'gap 1 3') {
            $attempt->update($this->completedAttributes());
            $this->attempt($homework, $student, 3, true);
        } else {
            $attempt->update(match ($corruption) {
                'deadline' => ['deadline_at' => now()->addDay()],
                'blitz status' => ['status' => AssessmentAttemptStatus::TimedOutFinalized],
                'blitz reason' => array_merge($this->completedAttributes(), ['finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit]),
                'submitted timestamp' => ['submitted_at' => now()],
                'finalized timestamp' => ['finalized_at' => now()],
                'locked timestamp' => ['locked_at' => now()],
                'finalization reason' => ['finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit],
            });
        }
        $before = AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all();
        $pairBefore = $pair->fresh()->getAttributes();
        $this->withoutExceptionHandling();
        try {
            $this->start($student, $homework);
            $this->fail('Corrupt Homework Attempt history must fail as an internal invariant.');
        } catch (LogicException) {
            $this->assertSame($before, AssessmentAttempt::query()->orderBy('id')->get()->map->getAttributes()->all());
            $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
            $this->assertDatabaseCount('idempotency_records', 0);
        }
    }

    public static function corruptedHistory(): array
    {
        return array_combine($cases = [
            'wrong assessment recipient', 'wrong student recipient', 'deadline', 'blitz status', 'blitz reason',
            'submitted timestamp', 'finalized timestamp', 'locked timestamp', 'finalization reason', 'gap 2', 'gap 1 3',
        ], array_map(fn (string $case): array => [$case], $cases));
    }

    public function test_ended_current_membership_does_not_revoke_snapshot_start_or_own_attempt_read(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        GroupStudentMembership::factory()->ended()->create([
            'institution_id' => $student->institution_id,
            'group_id' => $homework->assessment->topic->group_id, 'student_id' => $student->id,
        ]);
        $attemptId = $this->start($student, $homework)->assertCreated()->json('data.id');
        $this->requestAs($student, 'GET', '/api/v1/student/attempts/'.$attemptId)->assertOk()->assertJsonPath('data.id', $attemptId);
    }

    public function test_preliminary_access_hides_malformed_foreign_unassigned_draft_and_blitz_targets_before_idempotency_queries(): void
    {
        $student = $this->student();
        $other = $this->student($student->institution);
        $blitz = $this->homework($student);
        $blitz->assessment->update(['type' => AssessmentType::Blitz]);
        $ids = ['not-a-uuid', (string) Str::uuid(), $this->homework($this->student())->assessment_id,
            $this->homework($other)->assessment_id, $this->homework($student, 'draft')->assessment_id, $blitz->assessment_id];
        foreach ($ids as $id) {
            DB::flushQueryLog();
            DB::enableQueryLog();
            try {
                $this->requestAs($student, 'POST', $this->startUri($id))->assertNotFound()->assertJsonPath('code', 'resource_not_found');
                $this->assertEmpty(array_filter(DB::getQueryLog(), fn (array $query): bool => str_contains($query['query'], 'idempotency_records')));
            } finally {
                DB::disableQueryLog();
            }
        }
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('lifecycleFailures')]
    public function test_new_start_preserves_lifecycle_error_precedence_and_leaves_no_claim(string $state, bool $inactiveTopic, string $code): void
    {
        $student = $this->student();
        $homework = $this->homework($student, $state, ['deadline_at' => now()]);
        if ($inactiveTopic) {
            $homework->assessment->topic->update(['status' => TopicStatus::Closed, 'closed_at' => now()]);
        }
        $this->start($student, $homework)->assertConflict()->assertJsonPath('code', $code);
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function lifecycleFailures(): array
    {
        return ['closed' => ['closed', false, 'task_closed'], 'archived' => ['archivedAfterClose', false, 'task_archived'],
            'inactive Topic first' => ['closed', true, 'task_not_active'], 'active Homework under inactive Topic' => ['active', true, 'task_not_active']];
    }

    public function test_disappearing_previously_authorized_recipient_uses_student_specific_assignment_error(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $recipient = $this->recipientFor($homework, $student);
        $removed = false;
        DB::listen(function (QueryExecuted $query) use ($recipient, &$removed): void {
            if (! $removed && str_contains($query->sql, 'from "topics"') && str_contains($query->sql, 'for update')) {
                $removed = true;
                $recipient->delete();
            }
        });
        $this->start($student, $homework)->assertConflict()->assertJsonPath('code', 'assessment_not_assigned')
            ->assertJsonPath('message', 'This Homework is no longer assigned to the current Student.');
        $this->assertTrue($removed);
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('deadlineOffsets')]
    public function test_exact_and_past_deadlines_commit_all_due_reconciliation_without_a_start_claim_or_fabricated_attempt(int $offset, bool $ownAttemptExists): void
    {
        $student = $this->student();
        $deadline = now()->addSeconds($offset);
        $homework = $this->homework($student, attributes: ['deadline_at' => $deadline]);
        $other = $this->student($student->institution);
        AssessmentStudent::factory()->create(['assessment_id' => $homework->assessment_id, 'student_id' => $other->id]);
        $attempt = $this->attempt($homework, $other);
        $attempt->update(['started_at' => now()->subHour()]);
        $attempts = [$attempt];
        if ($ownAttemptExists) {
            $ownAttempt = $this->attempt($homework, $student);
            $ownAttempt->update(['started_at' => now()->subHour()]);
            $attempts[] = $ownAttempt;
        }
        $this->start($student, $homework)->assertConflict()->assertJsonPath('code', 'deadline_passed');
        foreach ($attempts as $dueAttempt) {
            $dueAttempt->refresh();
            $this->assertSame(AssessmentAttemptStatus::Submitted, $dueAttempt->status);
            $this->assertSame(AssessmentAttemptFinalizationReason::HomeworkDeadlineAutoSubmit, $dueAttempt->finalization_reason);
            $this->assertTrue($deadline->equalTo($dueAttempt->finalized_at));
            $this->assertTrue($deadline->equalTo($dueAttempt->locked_at));
            $this->assertNull($dueAttempt->submitted_at);
        }
        if (! $ownAttemptExists) {
            $this->assertDatabaseMissing('assessment_attempts', ['student_id' => $student->id]);
        }
        $this->assertDatabaseCount('assessment_attempts', count($attempts));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function deadlineOffsets(): array
    {
        return ['exact boundary before first Start' => [0, false], 'past deadline before first Start' => [-1, false],
            'exact boundary blocks resume' => [0, true], 'past deadline blocks resume' => [-1, true]];
    }

    public function test_own_attempt_get_reconciles_due_state_and_returns_safe_questions_and_saved_answers(): void
    {
        $student = $this->student();
        $homework = $this->homework($student, attributes: ['deadline_at' => now()->addMinute()]);
        $question = Question::factory()->singleChoice()->create(['assessment_id' => $homework->assessment_id, 'institution_id' => $student->institution_id]);
        $option = QuestionChoiceOption::factory()->create(['question_id' => $question->id, 'option_text' => 'Visible choice', 'is_correct' => true]);
        $attempt = $this->attempt($homework, $student);
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        $answer->selectedOptions()->attach($option->id, ['institution_id' => $student->institution_id, 'created_at' => now()]);
        $answerBefore = $answer->fresh()->getAttributes();
        $safeQuestions = $this->requestAs($student, 'GET', '/api/v1/student/homework/'.$homework->assessment_id)->assertOk()->json('data.questions');
        $this->travel(2)->minutes();
        $response = $this->requestAs($student, 'GET', '/api/v1/student/attempts/'.$attempt->id)->assertOk()
            ->assertJsonPath('data.status', 'submitted')->assertJsonPath('data.finalized_at', '2026-09-09T12:01:00Z')
            ->assertJsonPath('data.finalization_reason', 'homework_deadline_auto_submit');
        $this->assertSame(['id', 'assessment_id', 'attempt_number', 'status', 'started_at', 'submitted_at',
            'finalized_at', 'finalization_reason', 'deadline_at', 'questions', 'answers'], array_keys($response->json('data')));
        $this->assertSame($safeQuestions, $response->json('data.questions'));
        $this->assertSame([[
            'question_id' => $question->id, 'type' => 'single_choice',
            'answer' => ['selected_option_ids' => [$option->id]], 'updated_at' => '2026-09-09T12:00:00Z',
        ]], $response->json('data.answers'));
        $this->assertSame($answerBefore, $answer->fresh()->getAttributes());
        foreach (['is_correct', 'correct_value', 'accepted_answers', 'correct_position', 'match_key',
            'checking_status', 'awarded_points', 'feedback', 'checked_by_user_id', 'checked_at', 'attempt_id',
            'checking_mode', 'earned_points', 'possible_points', 'assessment_student_id', 'student_id', 'institution_id'] as $hidden) {
            $this->assertStringNotContainsString('"'.$hidden.'"', $response->getContent());
        }
    }

    public function test_get_rejects_any_input_and_hides_other_students_foreign_and_inconsistent_recipient_graphs(): void
    {
        $student = $this->student();
        $homework = $this->homework($student);
        $attempt = $this->attempt($homework, $student);
        $uri = '/api/v1/student/attempts/'.$attempt->id;
        foreach (['{}', '[]', 'null', ' ', '{"x":1}'] as $body) {
            $this->requestAs($student, 'GET', $uri, body: $body)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->requestAs($student, 'GET', $uri.'?x=1')->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        foreach ([$this->student($student->institution), $this->student()] as $other) {
            $this->requestAs($other, 'GET', $uri)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        foreach (['invalid', (string) Str::uuid()] as $id) {
            $this->requestAs($student, 'GET', '/api/v1/student/attempts/'.$id)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $wrongRecipient = $this->recipientFor($this->homework($student), $student);
        $attempt->update(['assessment_student_id' => $wrongRecipient->id]);
        $this->requestAs($student, 'GET', $uri)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
    }

    private function student(?Institution $institution = null, array $attributes = []): User
    {
        if ($institution === null) {
            $institution = Institution::factory()->create();
            InstitutionSetting::factory()->create(['institution_id' => $institution->id]);
        }

        return User::factory()->student($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    private function homework(User $student, string $state = 'active', array $attributes = []): HomeworkAssignment
    {
        $topic = Topic::factory()->active()->create(['institution_id' => $student->institution_id]);
        $assessment = Assessment::factory()->homework()->create([
            'institution_id' => $student->institution_id, 'topic_id' => $topic->id,
            'teacher_id' => $topic->teacher_id, 'total_possible_points' => '7.250000',
        ]);
        $homework = HomeworkAssignment::factory()->{$state}()->create(array_merge(['assessment_id' => $assessment->id], $attributes));
        AssessmentStudent::factory()->create(['assessment_id' => $assessment->id, 'student_id' => $student->id, 'assigned_by_user_id' => $assessment->teacher_id]);

        return $homework;
    }

    private function recipientFor(HomeworkAssignment $homework, User $student): AssessmentStudent
    {
        return AssessmentStudent::query()->where('assessment_id', $homework->assessment_id)->where('student_id', $student->id)->sole();
    }

    private function attempt(HomeworkAssignment $homework, User $student, int $number = 1, bool $completed = false): AssessmentAttempt
    {
        return AssessmentAttempt::factory()->create(array_merge([
            'assessment_student_id' => $this->recipientFor($homework, $student)->id, 'attempt_number' => $number,
        ], $completed ? $this->completedAttributes() : []));
    }

    private function completedAttributes(): array
    {
        return ['status' => AssessmentAttemptStatus::Submitted, 'submitted_at' => now(), 'finalized_at' => now(),
            'locked_at' => now(), 'finalization_reason' => AssessmentAttemptFinalizationReason::StudentSubmit];
    }

    private function start(User $student, HomeworkAssignment $homework): TestResponse
    {
        return $this->requestAs($student, 'POST', $this->startUri($homework->assessment_id));
    }

    private function startUri(string $homeworkId): string
    {
        return '/api/v1/student/homework/'.$homeworkId.'/attempts';
    }

    private function requestAs(?User $actor, string $method, string $uri, ?string $key = '', string $body = '', string $contentType = 'application/json'): TestResponse
    {
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json'];
        if ($actor !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$actor->createToken('homework-attempt-api-test')->plainTextToken;
        }
        if ($key !== null) {
            $server['HTTP_IDEMPOTENCY_KEY'] = $key === '' ? (string) Str::uuid() : $key;
        }
        try {
            return $this->call($method, $uri, [], [], [], $server, $body);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }
}
