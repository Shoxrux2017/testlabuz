<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\UserRole;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\Institution;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentHomeworkAttemptSubmitApiTest extends TestCase
{
    use BuildsStudentHomeworkFileAnswerContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
        Storage::fake('local');
    }

    public function test_exact_post_route_is_registered_once_and_enforces_all_student_middleware_gates(): void
    {
        $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/student/attempts/{attempt}/submit');
        $this->assertCount(1, $routes);
        $this->assertSame(['POST'], $routes->sole()->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'], $routes->sole()->middleware());
        [$student, , $attempt] = $this->answerContext();
        $before = $attempt->getAttributes();
        $actors = [
            [User::factory()->student($student->institution)->create(['is_active' => false, 'must_change_password' => false]), 'user_inactive'],
            [User::factory()->student($student->institution)->create(['must_change_password' => true]), 'password_change_required'],
            [User::factory()->student(Institution::factory()->inactive()->create())->create(['must_change_password' => false]), 'institution_inactive'],
        ];
        foreach ([UserRole::Teacher, UserRole::InstitutionAdmin, UserRole::Parent, UserRole::PlatformOwner] as $role) {
            $actors[] = [$role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($student->institution)->create(['role' => $role, 'must_change_password' => false]), 'forbidden'];
        }

        $this->submitRequest(null, $attempt, (string) Str::uuid())->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        foreach ($actors as [$actor, $code]) {
            $this->submitRequest($actor, $attempt, (string) Str::uuid())->assertForbidden()->assertJsonPath('code', $code);
        }
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('invalidSubmitRequests')]
    public function test_submit_rejects_invalid_header_body_and_query_without_any_claim_or_attempt_mutation(?string $key, string $body, string $contentType, string $query): void
    {
        [$student, , $attempt] = $this->answerContext();
        $before = $attempt->getAttributes();

        $response = $this->submitRequest($student, $attempt, $key, $body, $contentType, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        if ($key === null || $key === 'invalid-uuid') {
            $response->assertJsonValidationErrors('idempotency_key');
        }
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
        $this->assertDatabaseCount('attempt_answers', 0);
    }

    public static function invalidSubmitRequests(): array
    {
        $key = '89114819-43c0-4808-9166-3bcdca872eef';

        return [
            'missing key' => [null, '', 'application/json', ''],
            'malformed key' => ['invalid-uuid', '', 'application/json', ''],
            'non-empty object' => [$key, '{"submitted_at":"2026-09-09T11:00:00Z"}', 'application/json', ''],
            'empty array' => [$key, '[]', 'application/json', ''],
            'non-empty array' => [$key, '[1]', 'application/json', ''],
            'null' => [$key, 'null', 'application/json', ''],
            'string scalar' => [$key, '"answer"', 'application/json', ''],
            'number scalar' => [$key, '1', 'application/json', ''],
            'boolean scalar' => [$key, 'false', 'application/json', ''],
            'malformed JSON' => [$key, '{', 'application/json', ''],
            'form body' => [$key, 'submitted_at=now', 'application/x-www-form-urlencoded', ''],
            'empty object with non-JSON content type' => [$key, '{}', 'text/plain', ''],
            'query parameter' => [$key, '', 'application/json', '?unexpected=1'],
        ];
    }

    public function test_submit_freezes_every_saved_answer_family_and_file_without_checking_scoring_or_result_mutation(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $pair = TopicResultPair::factory()->create([
            'homework_assessment_id' => $homework->assessment_id,
            'designated_at' => now()->subMinutes(3), 'cohort_snapshotted_at' => now()->subMinutes(2), 'locked_at' => now()->subMinute(),
        ]);
        $expectedAnswers = [];
        foreach (['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'matching', 'ordering', 'fill_in_blank'] as $index => $type) {
            $question = $this->answerQuestion($homework, $type, $index + 1);
            $expectedAnswers[] = $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk()->json('data');
        }
        $fileQuestion = $this->answerQuestion($homework, 'file_based', 9);
        [, , $file] = $this->savedFileAnswer($attempt, $fileQuestion);
        $answersBefore = $this->fileAnswerSnapshot();
        $contentsBefore = Storage::disk('local')->get($file->storage_key);
        $attemptBefore = $attempt->fresh()->getAttributes();
        $pairBefore = $pair->fresh()->getAttributes();
        $this->travel(10)->minutes();

        $response = $this->submitRequest($student, $attempt, (string) Str::uuid(), '{}')->assertOk()
            ->assertJsonPath('message', 'Homework submitted successfully.')
            ->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.submitted_at', '2026-09-09T12:10:00Z')
            ->assertJsonPath('data.finalized_at', '2026-09-09T12:10:00Z')
            ->assertJsonPath('data.finalization_reason', 'student_submit')
            ->assertJsonCount(9, 'data.questions')->assertJsonCount(9, 'data.answers');

        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame(['id', 'assessment_id', 'attempt_number', 'status', 'started_at', 'submitted_at', 'finalized_at',
            'finalization_reason', 'deadline_at', 'questions', 'answers'], array_keys($response->json('data')));
        $this->assertSame($expectedAnswers, array_slice($response->json('data.answers'), 0, 8));
        $response->assertJsonPath('data.answers.8.answer.file.id', $file->id);
        $this->assertNoAnswerSecrets($response->json());
        $this->assertNoFileAnswerSecrets($response->json());
        foreach (['checking', 'requires_teacher_review', 'score', 'normalized_score', 'official_attempt'] as $field) {
            $this->assertArrayNotHasKey($field, $response->json('data'));
        }
        foreach (['private-short-answer-6187', 'private-fill-answer-8126', '%PDF'] as $secret) {
            $this->assertStringNotContainsString($secret, $response->getContent());
        }
        $this->assertExplicitTransition($attempt, $attemptBefore);
        $this->assertSame($answersBefore, $this->fileAnswerSnapshot());
        $this->assertSame($contentsBefore, Storage::disk('local')->get($file->storage_key));
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 1);
        foreach (AttemptAnswer::query()->get() as $answer) {
            $this->assertSame('pending', $answer->getRawOriginal('checking_status'));
            foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
                $this->assertNull($answer->getAttribute($field));
            }
        }
    }

    public function test_partial_answer_coverage_submits_and_preserves_saved_rows_without_fabricating_unanswered_rows(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $written = $this->answerQuestion($homework, 'open_written', 1);
        $this->answerRequest($student, $attempt, $written, $this->answerPayload($written))->assertOk();
        $savedFileQuestion = $this->answerQuestion($homework, 'file_based', 2);
        [, , $file] = $this->savedFileAnswer($attempt, $savedFileQuestion);
        $unanswered = [$this->answerQuestion($homework, 'single_choice', 3), $this->answerQuestion($homework, 'file_based', 4)];
        $before = $this->fileAnswerSnapshot();
        $contentsBefore = Storage::disk('local')->get($file->storage_key);
        $attemptBefore = $attempt->fresh()->getAttributes();
        $this->travel(1)->minutes();

        $response = $this->submitRequest($student, $attempt, (string) Str::uuid())->assertOk()
            ->assertJsonCount(4, 'data.questions')->assertJsonCount(2, 'data.answers');

        $this->assertSame([$written->id, $savedFileQuestion->id], array_column($response->json('data.answers'), 'question_id'));
        foreach ($unanswered as $question) {
            $this->assertDatabaseMissing('attempt_answers', ['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        }
        $this->assertExplicitTransition($attempt, $attemptBefore);
        $this->assertSame($before, $this->fileAnswerSnapshot());
        $this->assertSame($contentsBefore, Storage::disk('local')->get($file->storage_key));
    }

    #[DataProvider('acceptedEmptyRequests')]
    public function test_zero_saved_answers_accepts_empty_request_forms_without_creating_answers(string $body, bool $hasDeadline): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        if (! $hasDeadline) {
            $homework->update(['deadline_at' => null]);
        }
        foreach (['single_choice', 'open_written', 'file_based'] as $index => $type) {
            $this->answerQuestion($homework, $type, $index + 1);
        }
        $before = $attempt->getAttributes();

        $this->submitRequest($student, $attempt, (string) Str::uuid(), $body)->assertOk()
            ->assertJsonPath('data.status', 'submitted')->assertJsonCount(3, 'data.questions')->assertJsonPath('data.answers', [])
            ->assertJsonPath('data.deadline_at', $hasDeadline ? '2026-09-10T12:00:00Z' : null);

        $this->assertExplicitTransition($attempt, $before);
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertDatabaseCount('files', 0);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public static function acceptedEmptyRequests(): array
    {
        return ['no body and no deadline' => ['', false], 'empty JSON object and future deadline' => ['{}', true]];
    }

    #[DataProvider('savedAnswerFamilies')]
    public function test_corrupt_saved_answer_fails_safely_before_submit_or_idempotency_commit(string $family): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $written = $this->answerQuestion($homework, 'open_written');
        $this->answerRequest($student, $attempt, $written, $this->answerPayload($written))->assertOk();
        [, , $file] = $this->savedFileAnswer($attempt, $this->answerQuestion($homework, 'file_based', 2));
        if ($family === 'non-file') {
            DB::table('attempt_answers')->where('question_id', $written->id)->update(['feedback' => 'invalid persisted feedback']);
        } else {
            DB::table('files')->where('id', $file->id)->update(['checksum_sha256' => null]);
        }
        $attemptBefore = $attempt->fresh()->getAttributes();
        $answersBefore = $this->fileAnswerSnapshot();
        $contentsBefore = Storage::disk('local')->get($file->storage_key);

        $response = $this->submitRequest($student, $attempt, (string) Str::uuid())->assertStatus(500)->assertJsonPath('code', 'server_error');

        foreach (['LogicException', 'SQLSTATE', 'feedback', 'checksum_sha256', $file->storage_key, $attempt->id] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
        $this->assertSame(AssessmentAttemptStatus::InProgress, $attempt->fresh()->status);
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->assertSame($answersBefore, $this->fileAnswerSnapshot());
        $this->assertSame($contentsBefore, Storage::disk('local')->get($file->storage_key));
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function savedAnswerFamilies(): array
    {
        return ['non-file answer' => ['non-file'], 'file answer' => ['file']];
    }

    public function test_submit_creates_no_next_attempt_and_a_later_start_can_create_attempt_two(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $this->submitRequest($student, $attempt, (string) Str::uuid())->assertOk();
        $before = $attempt->fresh()->getAttributes();
        $this->assertDatabaseCount('assessment_attempts', 1);

        $this->answerHttp($student, 'POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts', headers: [
            'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
        ])->assertCreated()->assertJsonPath('data.attempt_number', 2)->assertJsonPath('data.status', 'in_progress');

        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('assessment_attempts', 2);
        $this->assertDatabaseCount('attempt_answers', 0);
    }

    private function assertExplicitTransition(AssessmentAttempt $attempt, array $before): void
    {
        $fresh = $attempt->fresh();
        $this->assertSame(AssessmentAttemptStatus::Submitted, $fresh->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::StudentSubmit, $fresh->finalization_reason);
        foreach (['submitted_at', 'finalized_at', 'locked_at', 'updated_at'] as $field) {
            $this->assertTrue($fresh->getAttribute($field)->equalTo(now()));
        }
        foreach (['started_at', 'deadline_at', 'attempt_number', 'assessment_student_id', 'official_score_eligible', 'possible_points'] as $field) {
            $this->assertSame($before[$field], $fresh->getAttributes()[$field]);
        }
        foreach (['earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertNull($fresh->getAttribute($field));
        }
    }

    private function submitRequest(?User $student, AssessmentAttempt $attempt, ?string $key, string $body = '', string $contentType = 'application/json', string $query = ''): TestResponse
    {
        $server = ['CONTENT_TYPE' => $contentType, 'HTTP_ACCEPT' => 'application/json'];
        if ($student !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$student->createToken('homework-submit-api-test')->plainTextToken;
        }
        if ($key !== null) {
            $server['HTTP_IDEMPOTENCY_KEY'] = $key;
        }
        try {
            return $this->call('POST', '/api/v1/student/attempts/'.$attempt->id.'/submit'.$query, [], [], [], $server, $body);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }
}
