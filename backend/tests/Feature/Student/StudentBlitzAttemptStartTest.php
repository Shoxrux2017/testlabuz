<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\BlitzStatus;
use App\Enums\FileExtension;
use App\Enums\UserRole;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzAttemptStartTest extends TestCase
{
    use BuildsStudentBlitzContext, BuildsStudentHomeworkFileAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_exact_routes_use_all_student_authentication_account_and_role_gates(): void
    {
        foreach (['api/v1/student/blitz/active' => ['GET'], 'api/v1/student/blitz/{blitz}' => ['GET'],
            'api/v1/student/blitz/{blitz}/attempts' => ['POST']] as $uri => $methods) {
            $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === $uri);
            $this->assertCount(1, $routes);
            $this->assertSame($methods, array_values(array_diff($routes->sole()->methods(), ['HEAD'])));
            $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'], $routes->sole()->middleware());
        }
        $student = $this->studentBlitzActor();
        $actors = [
            [$this->studentBlitzActor($student->institution, ['is_active' => false]), 'user_inactive'],
            [$this->studentBlitzActor($student->institution, ['must_change_password' => true]), 'password_change_required'],
            [$this->studentBlitzActor(Institution::factory()->inactive()->create()), 'institution_inactive'],
        ];
        foreach ([UserRole::Teacher, UserRole::InstitutionAdmin, UserRole::Parent, UserRole::PlatformOwner] as $role) {
            $actors[] = [$role === UserRole::PlatformOwner ? User::factory()->platformOwner()->create()
                : User::factory()->for($student->institution)->create(['role' => $role, 'must_change_password' => false]), 'forbidden'];
        }
        foreach ([['GET', '/api/v1/student/blitz/active'], ['GET', '/api/v1/student/blitz/'.Str::uuid()],
            ['POST', '/api/v1/student/blitz/'.Str::uuid().'/attempts']] as [$method, $uri]) {
            $body = $method === 'POST' ? '{"intent":"start_normal"}' : '';
            $this->studentBlitzRequest(null, $method, $uri, $body)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
            foreach ($actors as [$actor, $code]) {
                $this->studentBlitzRequest($actor, $method, $uri, $body)->assertForbidden()->assertJsonPath('code', $code);
            }
        }
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('invalidStartRequests')]
    public function test_start_rejects_every_noncanonical_request_shape(?string $key, string $body, string $query = '', string $contentType = 'application/json'): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/blitz/'.$assessment->id.'/attempts'.$query,
            $body, $key, $contentType)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function invalidStartRequests(): array
    {
        return [
            'missing key' => [null, '{"intent":"start_normal"}'],
            'malformed key' => ['bad-key', '{"intent":"start_normal"}'],
            'empty body' => ['', ''], 'empty object' => ['', '{}'],
            'unknown intent' => ['', '{"intent":"start_replacement"}'],
            'missing resume target' => ['', '{"intent":"resume"}'],
            'malformed resume target' => ['', '{"intent":"resume","attempt_id":"bad"}'],
            'null resume target' => ['', '{"intent":"resume","attempt_id":null}'],
            'normal target forbidden' => ['', '{"intent":"start_normal","attempt_id":"10000000-0000-4000-8000-000000000001"}'],
            'normal null target forbidden' => ['', '{"intent":"start_normal","attempt_id":null}'],
            'unknown field' => ['', '{"intent":"start_normal","attempt_number":1}'],
            'client time' => ['', '{"intent":"start_normal","server_now":"2000-01-01T00:00:00Z"}'],
            'client deadline' => ['', '{"intent":"start_normal","deadline_at":"2100-01-01T00:00:00Z"}'],
            'client mode' => ['', '{"intent":"start_normal","timer_mode":"individual"}'],
            'empty array' => ['', '[]'], 'array' => ['', '[{"intent":"start_normal"}]'],
            'null' => ['', 'null'], 'boolean' => ['', 'true'], 'number' => ['', '1'], 'string' => ['', '"start_normal"'],
            'malformed JSON' => ['', '{'],
            'non-JSON' => ['', 'intent=start_normal', '', 'application/x-www-form-urlencoded'],
            'query' => ['', '{"intent":"start_normal"}', '?unexpected=1'],
        ];
    }

    #[DataProvider('timerModes')]
    public function test_new_normal_attempt_persists_exact_server_time_and_returns_only_safe_question_surface(string $mode): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        [$choice, $file] = $this->studentBlitzQuestions($assessment);
        InstitutionSetting::query()->whereKey($student->institution_id)->update(['student_submission_max_mb' => 6]);
        $this->travelTo(Carbon::parse('2026-09-17T17:00:00.500000+05:00'));
        $response = $this->startStudentBlitz($student, $assessment)->assertCreated()
            ->assertJsonPath('message', 'Blitz attempt started successfully.');
        $attempt = AssessmentAttempt::query()->sole();
        $deadline = $mode === 'synchronized' ? '2026-09-17T12:05:00Z' : '2026-09-17T12:10:00Z';
        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame(['id', 'assessment_id', 'attempt_number', 'status', 'started_at', 'deadline_at', 'submitted_at', 'finalized_at', 'finalization_reason', 'timing', 'questions', 'answers'], array_keys($response->json('data')));
        $response->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.assessment_id', $assessment->id)
            ->assertJsonPath('data.attempt_number', 1)->assertJsonPath('data.status', 'in_progress')
            ->assertJsonPath('data.started_at', '2026-09-17T12:00:00Z')->assertJsonPath('data.deadline_at', $deadline)
            ->assertJsonPath('data.timing.server_now', '2026-09-17T12:00:00Z')
            ->assertJsonPath('data.timing.mode', $mode)->assertJsonPath('data.timing.remaining_seconds', $mode === 'synchronized' ? 300 : 600)
            ->assertJsonPath('data.questions.0.id', $choice->id)->assertJsonPath('data.questions.0.prompt', $choice->prompt)
            ->assertJsonPath('data.questions.0.answer_ui.options.0.text', 'Secret option seven')
            ->assertJsonPath('data.questions.1.id', $file->id)
            ->assertJsonPath('data.questions.1.answer_ui.allowed_extensions', FileExtension::values())
            ->assertJsonPath('data.questions.1.answer_ui.max_size_bytes', 6 * 1024 * 1024)
            ->assertJsonPath('data.answers', []);
        $this->assertDatabaseHas('assessment_attempts', [
            'id' => $attempt->id, 'institution_id' => $student->institution_id, 'assessment_id' => $assessment->id,
            'assessment_student_id' => AssessmentStudent::query()->where('assessment_id', $assessment->id)->sole()->id,
            'student_id' => $student->id, 'attempt_number' => 1, 'status' => 'in_progress',
            'started_at' => '2026-09-17 12:00:00', 'submitted_at' => null, 'finalized_at' => null,
            'finalization_reason' => null, 'locked_at' => null, 'official_score_eligible' => true,
            'earned_points' => null, 'possible_points' => '5.000000', 'normalized_score' => null, 'scoring_completed_at' => null,
        ]);
        foreach (['started_at', 'deadline_at'] as $field) {
            $this->assertSame('000000', $attempt->{$field}->format('u'));
            $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $response->json('data.'.$field));
        }
        foreach (['is_correct', 'correct_value', 'accepted_answers', 'checking_mode', 'correct_position',
            'institution_id', 'teacher_id', 'student_id', 'assessment_student_id', 'earned_points', 'score'] as $hidden) {
            $this->assertStringNotContainsString('"'.$hidden.'"', $response->getContent());
        }
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertDatabaseCount('files', 0);
    }

    #[DataProvider('synchronizedBoundaries')]
    public function test_synchronized_start_normalizes_clock_before_exact_common_end_comparison(string $rawNow, bool $success): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, 'synchronized');
        $this->travelTo(Carbon::parse($rawNow));
        $response = $this->startStudentBlitz($student, $assessment);
        if ($success) {
            $response->assertCreated()->assertJsonPath('data.started_at', '2026-09-17T12:04:59Z')
                ->assertJsonPath('data.deadline_at', '2026-09-17T12:05:00Z')->assertJsonPath('data.timing.remaining_seconds', 1);
        } else {
            $response->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
            $this->assertDatabaseCount('assessment_attempts', 0);
            $this->assertDatabaseCount('idempotency_records', 0);
        }
    }

    public static function synchronizedBoundaries(): array
    {
        return [['2026-09-17T12:04:59.999999Z', true], ['2026-09-17T12:05:00Z', false],
            ['2026-09-17T12:05:00.000001Z', false], ['2026-09-17T12:06:00Z', false]];
    }

    #[DataProvider('timerModes')]
    public function test_start_and_explicit_resume_return_same_attempt_without_touching_timers_or_other_state(string $mode): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $attemptId = $this->startStudentBlitz($student, $assessment)->assertCreated()->json('data.id');
        $attempt = AssessmentAttempt::query()->findOrFail($attemptId);
        $before = $attempt->getAttributes();
        $blitzBefore = $assessment->blitzTask->getAttributes();
        $this->travelTo(Carbon::parse('2026-09-17T12:01:00.500000Z'));
        foreach ([['start_normal', null], ['resume', strtoupper($attemptId)]] as [$intent, $target]) {
            $this->startStudentBlitz($student, $assessment, intent: $intent, attemptId: $target)->assertOk()
                ->assertJsonPath('message', 'Blitz attempt resumed successfully.')->assertJsonPath('data.id', $attemptId)
                ->assertJsonPath('data.started_at', '2026-09-17T12:00:00Z')
                ->assertJsonPath('data.timing.server_now', '2026-09-17T12:01:00Z')
                ->assertJsonPath('data.timing.remaining_seconds', $mode === 'synchronized' ? 240 : 540);
        }
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertSame($blitzBefore, $assessment->blitzTask->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->travelTo($attempt->deadline_at);
        foreach (['start_normal', 'resume'] as $intent) {
            $this->startStudentBlitz($student, $assessment, intent: $intent, attemptId: $intent === 'resume' ? $attemptId : null)
                ->assertConflict()->assertJsonPath('code', 'blitz_time_expired');
        }
        $this->assertSame(AssessmentAttemptStatus::TimedOutFinalized, $attempt->fresh()->status);
        $this->assertTrue($attempt->deadline_at->equalTo($attempt->fresh()->finalized_at));
        $transitionFields = array_flip(['status', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at']);
        $this->assertSame(array_diff_key($before, $transitionFields), array_diff_key($attempt->fresh()->getAttributes(), $transitionFields));
        $this->assertDatabaseCount('idempotency_records', 3);
    }

    #[DataProvider('timerModes')]
    public function test_start_and_resume_return_saved_typed_and_file_answers_in_question_order_without_exposing_secrets(string $mode): void
    {
        Storage::fake('local');
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        [$choice, $fileQuestion] = $this->studentBlitzQuestions($assessment);
        $textQuestion = $this->answerQuestion($assessment->blitzTask, 'short_written', 3);
        $unanswered = $this->answerQuestion($assessment->blitzTask, 'open_written', 4);
        $started = $this->startStudentBlitz($student, $assessment)->assertCreated()->assertJsonPath('data.answers', []);
        $attempt = AssessmentAttempt::query()->findOrFail($started->json('data.id'));
        $before = $attempt->getAttributes();
        $this->travelTo(now()->addSeconds(30));
        $exactText = "  DNS\u{00A0}\nExact text  ";
        $textState = $this->answerRequest($student, $attempt, $textQuestion,
            ['type' => 'short_written', 'text' => $exactText])->assertOk()->assertJsonPath('data.answer.text', $exactText)->json('data');
        $fileState = $this->fileAnswerRequest($student, $attempt, $fileQuestion, $this->fileAnswerUpload('Мой ответ.PDF'))
            ->assertOk()->assertJsonPath('data.answer.file.original_name', 'Мой ответ.PDF')->json('data');
        $optionId = $choice->choiceOptions()->orderBy('position')->firstOrFail()->id;
        $choiceState = $this->answerRequest($student, $attempt, $choice,
            ['type' => 'single_choice', 'selected_option_ids' => [$optionId]])->assertOk()->json('data');
        $savedSnapshot = $this->fileAnswerSnapshot();
        $this->travelTo(now()->addSeconds(30));

        foreach ([['start_normal', null], ['resume', $attempt->id]] as [$intent, $target]) {
            $response = $this->startStudentBlitz($student, $assessment, intent: $intent, attemptId: $target)->assertOk()
                ->assertJsonPath('data.id', $attempt->id)
                ->assertJsonPath('data.deadline_at', $started->json('data.deadline_at'))
                ->assertJsonPath('data.answers', [$choiceState, $fileState, $textState])
                ->assertJsonPath('data.questions.0.answer_ui.options.0.text', 'Secret option seven')
                ->assertJsonPath('data.questions.3.id', $unanswered->id);
            $this->assertNoAnswerSecrets($response->json('data'));
            $this->assertNoFileAnswerSecrets($response->json('data'));
            $this->assertSame(['id', 'original_name', 'extension', 'size_bytes'], array_keys($response->json('data.answers.1.answer.file')));
            $this->assertSame($savedSnapshot, $this->fileAnswerSnapshot());
            $this->assertSame($before, $attempt->fresh()->getAttributes());
        }
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('attempt_answers', 3);
    }

    public function test_resume_rejects_a_persisted_answer_outside_the_authorized_question_set(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $question = $this->answerQuestion($assessment->blitzTask, 'short_written');
        $attemptId = $this->startStudentBlitz($student, $assessment)->assertCreated()->json('data.id');
        $attempt = AssessmentAttempt::query()->findOrFail($attemptId);
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'DNS'])->assertOk();
        $otherAssessment = $this->studentBlitz($student);
        $otherQuestion = $this->answerQuestion($otherAssessment->blitzTask, 'short_written');
        AttemptAnswer::query()->where('attempt_id', $attempt->id)->update(['question_id' => $otherQuestion->id]);
        $snapshot = $this->answerSnapshot();
        $this->withoutExceptionHandling();

        try {
            $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id);
            $this->fail('Resume must reject answers outside the authorized Question set.');
        } catch (LogicException $exception) {
            $this->assertSame('Persisted Student answer does not belong to the authorized Question set.', $exception->getMessage());
            $this->assertSame($snapshot, $this->answerSnapshot());
            $this->assertDatabaseCount('idempotency_records', 1);
        }
    }

    public function test_resume_rejects_a_saved_file_with_corrupted_uploader_ownership(): void
    {
        Storage::fake('local');
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        [, $question] = $this->studentBlitzQuestions($assessment);
        $attemptId = $this->startStudentBlitz($student, $assessment)->assertCreated()->json('data.id');
        $attempt = AssessmentAttempt::query()->findOrFail($attemptId);
        [, , $file] = $this->savedFileAnswer($attempt, $question);
        $file->update(['uploaded_by_user_id' => $this->studentBlitzActor($student->institution)->id]);
        $snapshot = $this->fileAnswerSnapshot();
        $this->withoutExceptionHandling();

        try {
            $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id);
            $this->fail('Resume must validate saved File ownership before serialization.');
        } catch (LogicException $exception) {
            $this->assertSame('Persisted Student answer integrity failed.', $exception->getMessage());
            $this->assertSame($snapshot, $this->fileAnswerSnapshot());
            $this->assertDatabaseCount('idempotency_records', 1);
        }
    }

    #[DataProvider('timerModes')]
    public function test_stale_resume_of_terminal_exact_attempt_never_creates_or_switches_to_another_attempt(string $mode): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, $mode);
        $attempt = $this->studentBlitzAttempt($assessment, $student);
        $this->studentBlitzRequest($student, 'GET', '/api/v1/student/blitz/'.$assessment->id)->assertOk()
            ->assertJsonPath('data.attempts.in_progress_attempt_id', $attempt->id);
        $this->terminateStudentBlitzAttempt($attempt);
        $before = $attempt->fresh()->getAttributes();
        $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $attempt->id)->assertConflict()
            ->assertJsonPath('code', 'attempt_not_editable')->assertJsonPath('message', 'This Blitz attempt is no longer editable.');
        $this->startStudentBlitz($student, $assessment)->assertConflict()
            ->assertJsonPath('code', 'attempts_exhausted')->assertJsonPath('message', 'No Blitz attempts remain.');
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_resume_target_is_scoped_to_exact_student_blitz_and_recipient_and_never_creates_attempts(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $otherStudent = $this->studentBlitzActor($student->institution);
        $otherStudentAttempt = $this->studentBlitzAttempt($assessment, $otherStudent);
        $otherBlitzAttempt = $this->studentBlitzAttempt($this->studentBlitz($student), $student);
        $foreign = $this->studentBlitzActor();
        $foreignAttempt = $this->studentBlitzAttempt($this->studentBlitz($foreign), $foreign);
        foreach ([$otherStudentAttempt->id, $otherBlitzAttempt->id, $foreignAttempt->id, (string) Str::uuid()] as $target) {
            $this->startStudentBlitz($student, $assessment, intent: 'resume', attemptId: $target)->assertNotFound()
                ->assertJsonPath('code', 'resource_not_found');
        }
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $assessment->id, 'student_id' => $student->id]);
        $this->assertDatabaseCount('assessment_attempts', 3);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_start_requires_assigned_active_blitz_and_active_topic_with_no_failed_claims(): void
    {
        $student = $this->studentBlitzActor();
        foreach (BlitzStatus::cases() as $status) {
            if ($status !== BlitzStatus::Active) {
                $this->startStudentBlitz($student, $this->studentBlitz($student, status: $status))->assertConflict()->assertJsonPath('code', 'blitz_not_active');
            }
        }
        foreach ([$this->studentBlitz($student, assigned: false), $this->studentBlitz($this->studentBlitzActor($student->institution)),
            $this->studentBlitz($this->studentBlitzActor())] as $private) {
            $this->startStudentBlitz($student, $private)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }
        $assessment = $this->studentBlitz($student);
        $assessment->topic->update(['status' => 'closed', 'closed_at' => now()]);
        $this->startStudentBlitz($student, $assessment)->assertConflict()->assertJsonPath('code', 'blitz_not_active');
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_individual_start_ignores_activation_age_and_arbitrary_device_date_headers(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student, blitzAttributes: ['activated_at' => now()->subDays(3)]);
        try {
            $this->call('POST', '/api/v1/student/blitz/'.$assessment->id.'/attempts', [], [], [], [
                'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('client-clock-test')->plainTextToken,
                'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(), 'HTTP_DATE' => 'Thu, 01 Jan 2099 00:00:00 GMT',
                'HTTP_X_CLIENT_TIME' => '2000-01-01T00:00:00Z', 'HTTP_X_CLIENT_TIMEZONE' => 'Pacific/Honolulu',
            ], '{"intent":"start_normal"}')->assertCreated()
                ->assertJsonPath('data.started_at', '2026-09-17T12:00:00Z')
                ->assertJsonPath('data.deadline_at', '2026-09-17T12:10:00Z')
                ->assertJsonPath('data.timing.remaining_seconds', 600);
        } finally {
            $this->app['auth']->forgetGuards();
        }
        $this->assertNull(BlitzTask::query()->findOrFail($assessment->id)->synchronized_ends_at);
    }

    public function test_malformed_start_route_has_private_not_found_outcome(): void
    {
        $student = $this->studentBlitzActor();
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/blitz/malformed/attempts', '{"intent":"start_normal"}')
            ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_invalid_file_setting_rolls_back_start_attempt_and_claim(): void
    {
        $student = $this->studentBlitzActor();
        $assessment = $this->studentBlitz($student);
        $this->studentBlitzQuestions($assessment);
        InstitutionSetting::query()->whereKey($student->institution_id)->delete();
        $this->withoutExceptionHandling();
        try {
            $this->startStudentBlitz($student, $assessment);
            $this->fail('Missing file setting cannot invent a submission limit.');
        } catch (LogicException) {
            $this->assertDatabaseCount('assessment_attempts', 0);
            $this->assertDatabaseCount('idempotency_records', 0);
        }
    }

    public static function timerModes(): array
    {
        return [['synchronized'], ['individual']];
    }
}
