<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\UserRole;
use App\Models\AssessmentStudent;
use App\Models\AttemptAnswer;
use App\Models\BlitzTask;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkFileAnswerContext;
use Tests\TestCase;

class StudentBlitzAttemptSubmitApiTest extends TestCase
{
    use BuildsStudentBlitzAnswerContext, BuildsStudentHomeworkFileAnswerContext, RefreshDatabase {
        BuildsStudentBlitzAnswerContext::answerContext insteadof BuildsStudentHomeworkFileAnswerContext;
        BuildsStudentHomeworkFileAnswerContext::answerContext as homeworkAnswerContext;
    }

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
        Storage::fake('local');
    }

    public function test_canonical_submit_route_is_registered_once_with_all_student_middleware_gates(): void
    {
        $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/student/attempts/{attempt}/submit');
        $this->assertCount(1, $routes);
        $this->assertSame(['POST'], $routes->sole()->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'], $routes->sole()->middleware());
        $this->assertCount(0, collect(Route::getRoutes())->filter(fn ($route): bool => str_contains($route->uri(), '/blitz/') && str_ends_with($route->uri(), '/submit')));
        [$student, , $attempt] = $this->answerContext();
        $before = $attempt->getAttributes();
        $uri = '/api/v1/student/attempts/'.$attempt->id.'/submit';
        $this->studentBlitzRequest(null, 'POST', $uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
        $actors = [
            [$this->studentBlitzActor($student->institution, ['is_active' => false]), 'user_inactive'],
            [$this->studentBlitzActor($student->institution, ['must_change_password' => true]), 'password_change_required'],
            [$this->studentBlitzActor(Institution::factory()->inactive()->create()), 'institution_inactive'],
        ];
        foreach ([UserRole::Teacher, UserRole::InstitutionAdmin, UserRole::Parent, UserRole::PlatformOwner] as $role) {
            $actors[] = [$role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($student->institution)->create(['role' => $role, 'must_change_password' => false]), 'forbidden'];
        }
        foreach ($actors as [$actor, $code]) {
            $this->studentBlitzRequest($actor, 'POST', $uri)->assertForbidden()->assertJsonPath('code', $code);
        }
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    #[DataProvider('invalidRequests')]
    public function test_strict_header_body_and_query_validation_prevents_any_claim_or_mutation(?string $key, string $body, string $contentType, string $query): void
    {
        [$student, , $attempt] = $this->answerContext();
        $before = $attempt->getAttributes();
        $response = $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit'.$query, $body, $key, $contentType)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        if ($key === null || $key === 'invalid-uuid') {
            $response->assertJsonValidationErrors('idempotency_key');
        }
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
        $this->assertDatabaseCount('attempt_answers', 0);
    }

    public static function invalidRequests(): array
    {
        $key = 'de89bd49-ff15-4300-9813-3581a424fc13';

        return [
            'missing key' => [null, '', 'application/json', ''],
            'malformed key' => ['invalid-uuid', '', 'application/json', ''],
            'client time' => [$key, '{"submitted_at":"2026-09-17T11:59:00Z"}', 'application/json', ''],
            'historical flag' => [$key, '{"historical":true}', 'application/json', ''],
            'empty array' => [$key, '[]', 'application/json', ''],
            'array' => [$key, '[1]', 'application/json', ''],
            'null' => [$key, 'null', 'application/json', ''],
            'string' => [$key, '"answer"', 'application/json', ''],
            'number' => [$key, '1', 'application/json', ''],
            'boolean' => [$key, 'false', 'application/json', ''],
            'malformed JSON' => [$key, '{', 'application/json', ''],
            'form body' => [$key, 'submitted_at=now', 'application/x-www-form-urlencoded', ''],
            'non JSON object' => [$key, '{}', 'text/plain', ''],
            'query' => [$key, '', 'application/json', '?historical=1'],
        ];
    }

    #[DataProvider('timerModes')]
    public function test_pre_deadline_submit_freezes_saved_answers_and_file_without_mutating_related_domain_state(string $mode): void
    {
        $student = $this->studentBlitzActor();
        [$assessment, $pair] = $this->officialStudentBlitz($student);
        $blitz = BlitzTask::query()->findOrFail($assessment->id);
        if ($mode === 'synchronized') {
            $blitz->update(['timer_start_mode_snapshot' => $mode, 'synchronized_ends_at' => $blitz->activated_at->copy()->addSeconds($blitz->duration_seconds)]);
        }
        $attempt = $this->studentBlitzAttempt($assessment, $student);
        $expectedAnswers = [];
        foreach (['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'matching', 'ordering', 'fill_in_blank'] as $index => $type) {
            $question = $this->answerQuestion($blitz, $type, $index + 1);
            $expectedAnswers[] = $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk()->json('data');
        }
        [, , $file] = $this->savedFileAnswer($attempt, $this->answerQuestion($blitz, 'file_based', 9));
        $unanswered = [$this->answerQuestion($blitz, 'short_written', 10), $this->answerQuestion($blitz, 'file_based', 11)];
        $answersBefore = $this->fileAnswerSnapshot();
        $bytesBefore = Storage::disk('local')->get($file->storage_key);
        $attemptBefore = $attempt->getAttributes();
        $parentsBefore = [$assessment->fresh()->getAttributes(), $assessment->topic->fresh()->getAttributes(), $blitz->fresh()->getAttributes(),
            $pair->fresh()->getAttributes(), AssessmentStudent::query()->where('assessment_id', $assessment->id)->sole()->getAttributes()];
        $this->travel(1)->minutes();

        $response = $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', '{}')->assertOk()
            ->assertJsonPath('message', 'Blitz attempt submitted successfully.')
            ->assertJsonPath('data.id', $attempt->id)->assertJsonPath('data.assessment_id', $assessment->id)
            ->assertJsonPath('data.attempt_number', 1)->assertJsonPath('data.status', 'submitted')
            ->assertJsonPath('data.submitted_at', '2026-09-17T12:01:00Z')->assertJsonPath('data.finalized_at', '2026-09-17T12:01:00Z')
            ->assertJsonPath('data.finalization_reason', 'student_submit')->assertJsonPath('data.timing.mode', $mode)
            ->assertJsonPath('data.timing.remaining_seconds', 0)->assertJsonCount(11, 'data.questions')->assertJsonCount(9, 'data.answers');

        $this->assertSame(['data', 'message'], array_keys($response->json()));
        $this->assertSame(['id', 'assessment_id', 'attempt_number', 'status', 'started_at', 'deadline_at', 'submitted_at', 'finalized_at',
            'finalization_reason', 'timing', 'questions', 'answers'], array_keys($response->json('data')));
        $this->assertSame($expectedAnswers, array_slice($response->json('data.answers'), 0, 8));
        $response->assertJsonPath('data.answers.8.answer.file.id', $file->id);
        $this->assertNoAnswerSecrets($response->json());
        $this->assertNoFileAnswerSecrets($response->json());
        foreach (['earned_points', 'normalized_score', 'scoring_completed_at', 'checking_mode', 'private-short-answer-6187', 'private-fill-answer-8126'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
        $fresh = $attempt->fresh();
        $this->assertSame(AssessmentAttemptStatus::Submitted, $fresh->status);
        $this->assertSame(AssessmentAttemptFinalizationReason::StudentSubmit, $fresh->finalization_reason);
        foreach (['submitted_at', 'finalized_at', 'locked_at', 'updated_at'] as $field) {
            $this->assertTrue($fresh->getAttribute($field)->equalTo(now()));
        }
        $transition = array_flip(['status', 'submitted_at', 'finalized_at', 'locked_at', 'finalization_reason', 'updated_at']);
        $this->assertSame(array_diff_key($attemptBefore, $transition), array_diff_key($fresh->getAttributes(), $transition));
        foreach (['earned_points', 'normalized_score', 'scoring_completed_at'] as $field) {
            $this->assertNull($fresh->getAttribute($field));
        }
        foreach (AttemptAnswer::query()->get() as $answer) {
            $this->assertSame('pending', $answer->getRawOriginal('checking_status'));
            foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
                $this->assertNull($answer->getAttribute($field));
            }
        }
        foreach ($unanswered as $question) {
            $this->assertDatabaseMissing('attempt_answers', ['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        }
        $this->assertSame($answersBefore, $this->fileAnswerSnapshot());
        $this->assertSame($bytesBefore, Storage::disk('local')->get($file->storage_key));
        $this->assertSame($parentsBefore, [$assessment->fresh()->getAttributes(), $assessment->topic->fresh()->getAttributes(), $blitz->fresh()->getAttributes(),
            $pair->fresh()->getAttributes(), AssessmentStudent::query()->where('assessment_id', $assessment->id)->sole()->getAttributes()]);
        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
    }

    public static function timerModes(): array
    {
        return [['individual'], ['synchronized']];
    }

    #[DataProvider('emptyBodies')]
    public function test_empty_body_forms_allow_no_answer_submit_without_creating_missing_rows(string $body): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        foreach (['single_choice', 'open_written', 'file_based'] as $index => $type) {
            $this->answerQuestion($blitz, $type, $index + 1);
        }
        $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit', $body)
            ->assertOk()->assertJsonPath('data.status', 'submitted')->assertJsonCount(3, 'data.questions')->assertJsonPath('data.answers', []);
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertDatabaseCount('files', 0);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public static function emptyBodies(): array
    {
        return [[''], ['{}']];
    }

    #[DataProvider('inaccessibleAttempts')]
    public function test_inaccessible_or_corrupt_attempt_identity_is_private_before_idempotency_access(string $target): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $attemptId = $attempt->id;
        if ($target === 'other Student') {
            $student = $this->studentBlitzActor($student->institution);
        } elseif ($target === 'foreign Tenant') {
            $student = $this->studentBlitzActor();
        } elseif ($target === 'malformed UUID') {
            $attemptId = 'malformed';
        } elseif ($target === 'unknown UUID') {
            $attemptId = (string) Str::uuid();
        } elseif ($target === 'broken recipient') {
            $other = $this->studentBlitzActor($student->institution);
            $recipient = $this->blitzRecipient($blitz->assessment, $other, $blitz->assessment->teacher);
            $attempt->update(['assessment_student_id' => $recipient->id]);
        } else {
            $blitz->assessment->update(['type' => 'homework']);
        }
        $before = $attempt->fresh()->getAttributes();
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $response = $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attemptId.'/submit')
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            foreach (DB::getQueryLog() as $query) {
                $this->assertStringNotContainsString('idempotency_records', $query['query']);
            }
        } finally {
            DB::disableQueryLog();
        }
        $this->assertStringNotContainsString($attempt->id, $response->getContent());
        $this->assertSame($before, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function inaccessibleAttempts(): array
    {
        return array_map(fn (string $target): array => [$target], ['other Student', 'foreign Tenant', 'malformed UUID', 'unknown UUID', 'broken recipient', 'corrupt Assessment type']);
    }

    public function test_shared_route_dispatches_homework_to_its_existing_resource_and_message(): void
    {
        [$student, , $attempt] = $this->homeworkAnswerContext();
        $response = $this->studentBlitzRequest($student, 'POST', '/api/v1/student/attempts/'.$attempt->id.'/submit')->assertOk()
            ->assertJsonPath('message', 'Homework submitted successfully.')->assertJsonPath('data.id', $attempt->id)
            ->assertJsonPath('data.status', 'submitted')->assertJsonPath('data.finalization_reason', 'student_submit');
        $this->assertArrayNotHasKey('timing', $response->json('data'));
        $this->assertDatabaseHas('idempotency_records', ['operation' => 'student.homework.attempt.submit', 'result_resource_id' => $attempt->id]);
    }
}
