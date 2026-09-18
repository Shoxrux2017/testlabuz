<?php

namespace Tests\Feature\Teacher;

use App\Enums\BlitzStatus;
use App\Models\BlitzAttemptException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsBlitzExceptionContext;
use Tests\TestCase;

class TeacherBlitzAttemptExceptionApiTest extends TestCase
{
    use BuildsBlitzExceptionContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    #[DataProvider('reasons')]
    public function test_grant_preserves_history_pair_cohort_and_class_policy_without_creating_an_attempt(string $type): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext();
        $pair = $this->officialBlitzPair($assessment, $teacher, true);
        $pairBefore = $pair->fresh()->getAttributes();
        $blitzBefore = $assessment->blitzTask->getAttributes();
        $recipientBefore = $assessment->recipients()->get()->map->getAttributes()->all();
        $before = $normal->getAttributes();
        $response = $this->grantException($teacher, $assessment, $student, body: ['reason_type' => $type, 'reason' => "  Device interruption.\n"])->assertCreated();
        $exception = BlitzAttemptException::query()->sole();
        $response->assertExactJson(['data' => [
            'id' => $exception->id, 'blitz_id' => $assessment->id, 'student_id' => $student->id,
            'invalidated_attempt_id' => $normal->id, 'replacement_attempt_id' => null,
            'reason_type' => $type, 'reason' => 'Device interruption.', 'granted_at' => '2026-09-17T12:00:00Z',
            'replacement_attempt_available' => true,
        ], 'message' => 'One additional Blitz attempt has been granted.']);
        $this->assertSame($teacher->id, $exception->granted_by_user_id);
        $this->assertSame($normal->assessment_student_id, $exception->assessment_student_id);
        $this->assertSame(array_replace($before, ['official_score_eligible' => false]), $normal->fresh()->getAttributes());
        $this->assertSame($pairBefore, $pair->fresh()->getAttributes());
        $this->assertSame($blitzBefore, $assessment->blitzTask->fresh()->getAttributes());
        $this->assertSame($recipientBefore, $assessment->recipients()->get()->map->getAttributes()->all());
        $this->assertDatabaseCount('assessment_attempts', 1);
        $routes = collect(Route::getRoutes())->filter(fn ($route) => $route->uri() === 'api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception');
        $this->assertCount(1, $routes);
        $this->assertSame(['POST'], $routes->sole()->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'], $routes->sole()->middleware());
    }

    public static function reasons(): array
    {
        return [['technical'], ['other_valid']];
    }

    #[DataProvider('invalidBodies')]
    public function test_strict_json_reason_validation_rejects_invalid_input(string $body, ?string $key, string $query, string $contentType): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $this->studentBlitzRequest($teacher, 'POST', '/api/v1/teacher/blitz/'.$assessment->id.'/students/'.$student->id.'/attempt-exception'.$query,
            $body, $key, $contentType)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function invalidBodies(): array
    {
        $cases = [];
        foreach (['', '[]', 'null', '{}', '{', '{"reason_type":"technical","reason":"  "}',
            '{"reason_type":"unknown","reason":"x"}', '{"reason_type":1,"reason":"x"}',
            '{"reason_type":"technical","reason":3}', '{"reason_type":"technical","reason":"x","student_id":"x"}',
            json_encode(['reason_type' => 'technical', 'reason' => str_repeat('🙂', 4001)])] as $body) {
            $cases[] = [$body, '', '', 'application/json'];
        }
        $body = '{"reason_type":"technical","reason":"x"}';

        return [...$cases, [$body, null, '', 'application/json'], [$body, 'invalid', '', 'application/json'],
            [$body, '', '?extra=1', 'application/json'], [$body, '', '', 'text/plain']];
    }

    public function test_unicode_limit_is_in_characters_and_trim_precedes_length_validation(): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $this->grantException($teacher, $assessment, $student, body: ['reason_type' => 'technical', 'reason' => ' '.str_repeat('🙂', 4000).' '])
            ->assertCreated()->assertJsonPath('data.reason', str_repeat('🙂', 4000));
    }

    #[DataProvider('grantStates')]
    public function test_lifecycle_and_normal_attempt_requirements(string $state, string $code): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext();
        if ($state === 'missing') {
            $normal->delete();
        } elseif ($state === 'live') {
            $normal->update(['status' => 'in_progress', 'submitted_at' => null, 'finalized_at' => null, 'locked_at' => null, 'finalization_reason' => null]);
        } else {
            $assessment = $this->persistedBlitz($student->institution, $teacher, $assessment->topic, status: BlitzStatus::from($state));
            $this->blitzRecipient($assessment, $student, $teacher);
        }
        $this->grantException($teacher, $assessment, $student)->assertConflict()->assertJsonPath('code', $code);
        $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public static function grantStates(): array
    {
        return [['missing', 'blitz_normal_attempt_required'], ...array_map(fn ($state) => [$state, 'blitz_attempt_exception_not_allowed'],
            ['live', 'draft', 'scheduled', 'closed', 'archived'])];
    }

    #[DataProvider('dueOffsets')]
    public function test_due_normal_attempt_is_finalized_at_exact_deadline_before_grant(int $offset): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext('synchronized', false);
        $this->travelTo($normal->deadline_at->copy()->addSeconds($offset));
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        $fresh = $normal->fresh();
        $this->assertSame('timed_out_finalized', $fresh->status->value);
        $this->assertSame('timeout_auto_submit', $fresh->finalization_reason->value);
        $this->assertNull($fresh->submitted_at);
        $this->assertTrue($fresh->finalized_at->equalTo($normal->deadline_at));
        $this->assertTrue($fresh->locked_at->equalTo($normal->deadline_at));
        $this->assertFalse($fresh->official_score_eligible);
        $this->assertDatabaseCount('assessment_attempts', 1);
    }

    public static function dueOffsets(): array
    {
        return [[0], [60]];
    }

    public function test_second_key_is_rejected_and_another_student_can_receive_an_independent_grant(): void
    {
        [$student, $assessment, , $teacher] = $this->exceptionContext();
        $this->grantException($teacher, $assessment, $student)->assertCreated();
        $this->grantException($teacher, $assessment, $student)->assertConflict()->assertJsonPath('code', 'blitz_attempt_exception_already_granted');
        $other = $this->studentBlitzActor($student->institution);
        $this->terminateStudentBlitzAttempt($this->studentBlitzAttempt($assessment, $other));
        $this->grantException($teacher, $assessment, $other)->assertCreated();
        $this->assertDatabaseCount('blitz_attempt_exceptions', 2);
        $this->assertDatabaseCount('idempotency_records', 2);
    }

    public function test_ineligible_normal_without_exception_is_not_silently_repaired(): void
    {
        [$student, $assessment, $normal, $teacher] = $this->exceptionContext();
        $normal->update(['official_score_eligible' => false]);
        $this->withoutExceptionHandling();
        try {
            $this->grantException($teacher, $assessment, $student);
            $this->fail('Unknown invalidation must fail.');
        } catch (LogicException) {
            $this->assertDatabaseCount('blitz_attempt_exceptions', 0);
            $this->assertDatabaseCount('idempotency_records', 0);
        }
    }
}
