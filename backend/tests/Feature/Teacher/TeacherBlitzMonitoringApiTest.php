<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\ShowTeacherBlitzMonitoring;
use App\Enums\BlitzStatus;
use App\Http\Resources\Teacher\TeacherBlitzMonitoringResource;
use App\Models\AssessmentStudent;
use App\Models\GroupStudentMembership;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\UsesBlitzReadSnapshot;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzMonitoringContext;
use Tests\TestCase;

class TeacherBlitzMonitoringApiTest extends TestCase
{
    use BuildsTeacherBlitzMonitoringContext, UsesBlitzReadSnapshot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_exact_route_and_teacher_middleware_are_registered_once(): void
    {
        $routes = collect(Route::getRoutes()->getRoutes())->filter(fn ($route) => str_contains($route->uri(), 'blitz')
            && str_contains($route->getActionName(), '@monitoring'))->values();
        $this->assertCount(1, $routes);
        $this->assertSame('api/v1/teacher/blitz/{blitz}/monitoring', $routes[0]->uri());
        $this->assertSame(['GET', 'HEAD'], $routes[0]->methods());
        foreach (['auth:sanctum', 'active.account', 'password.changed', 'role:teacher'] as $middleware) {
            $this->assertContains($middleware, $routes[0]->gatherMiddleware());
        }
    }

    #[DataProvider('invalidInputs')]
    public function test_body_and_any_query_key_are_rejected(string $body, string $query): void
    {
        [, $assessment, $teacher] = $this->monitoringContext();
        $this->studentBlitzRequest($teacher, 'GET', '/api/v1/teacher/blitz/'.$assessment->id.'/monitoring'.$query, $body)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public static function invalidInputs(): array
    {
        return [['{}', ''], ['{"student_id":null}', ''], ['', '?page=1'], ['', '?unknown='], ['', '?sort[name]=asc']];
    }

    #[DataProvider('timerModes')]
    public function test_exact_materialized_response_and_query_free_resource(string $mode): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext($mode);
        $expected = [
            'blitz' => ['id' => $assessment->id, 'status' => 'active', 'duration_seconds' => 600,
                'activated_at' => '2026-09-17T11:55:00Z', 'timing' => ['mode' => $mode,
                    'synchronized_ends_at' => $mode === 'synchronized' ? '2026-09-17T12:05:00Z' : null,
                    'server_now' => '2026-09-17T12:00:00Z']],
            'summary' => ['assigned' => 1, 'not_started' => 1, 'in_progress' => 0, 'finalized' => 0,
                'waiting_for_teacher_review' => 0, 'attempt_exceptions_granted' => 0],
            'students' => [['student' => ['id' => $student->id, 'full_name' => $student->full_name],
                'status' => 'not_started', 'attempt_number' => null, 'started_at' => null, 'deadline_at' => null,
                'remaining_seconds' => $mode === 'synchronized' ? 300 : null, 'finalization_reason' => null,
                'score' => null, 'attempt_exception' => null]],
        ];
        $this->monitor($teacher, $assessment)->assertOk()->assertExactJson(['data' => $expected]);
        $projection = app(ShowTeacherBlitzMonitoring::class)($teacher, $assessment->id);
        DB::enableQueryLog();
        DB::flushQueryLog();
        try {
            $this->assertSame($expected, (new TeacherBlitzMonitoringResource($projection))->resolve());
            $this->assertSame([], DB::getQueryLog());
        } finally {
            DB::disableQueryLog();
        }
    }

    public static function timerModes(): array
    {
        return [['synchronized'], ['individual']];
    }

    #[DataProvider('lifecycles')]
    public function test_only_active_lifecycle_is_monitorable(BlitzStatus $status, string $code): void
    {
        [, $assessment, $teacher] = $this->monitoringContext(status: $status);
        $this->monitor($teacher, $assessment)->assertConflict()->assertJsonPath('code', $code);
    }

    public static function lifecycles(): array
    {
        return [[BlitzStatus::Draft, 'task_not_active'], [BlitzStatus::Scheduled, 'task_not_active'],
            [BlitzStatus::Closed, 'task_closed'], [BlitzStatus::Archived, 'task_archived']];
    }

    public function test_common_end_does_not_close_task_or_create_never_started_attempts_or_churn_timestamps(): void
    {
        [, $assessment, $teacher] = $this->monitoringContext('synchronized');
        $this->travelTo(Carbon::parse('2026-09-17 12:10:00 UTC'));
        $parentBefore = $assessment->fresh()->getAttributes();
        $taskBefore = $assessment->blitzTask->getAttributes();
        $recipientsBefore = AssessmentStudent::query()->get()->map->getAttributes()->all();
        for ($i = 0; $i < 2; $i++) {
            $this->monitor($teacher, $assessment)->assertOk()->assertJsonPath('data.blitz.status', 'active')
                ->assertJsonPath('data.students.0.status', 'not_started')->assertJsonPath('data.students.0.remaining_seconds', 0);
        }
        $this->assertSame($parentBefore, $assessment->fresh()->getAttributes());
        $this->assertSame($taskBefore, $assessment->blitzTask->fresh()->getAttributes());
        $this->assertSame($recipientsBefore, AssessmentStudent::query()->get()->map->getAttributes()->all());
        $this->assertDatabaseCount('assessment_attempts', 0);
        $this->assertDatabaseCount('idempotency_records', 0);
    }

    public function test_persisted_roster_retains_departed_inactive_students_and_orders_case_insensitive_names_then_ids(): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        $student->update(['full_name' => 'zeta', 'is_active' => false]);
        GroupStudentMembership::factory()->ended()->create([
            'institution_id' => $student->institution_id, 'group_id' => $assessment->topic->group_id,
            'student_id' => $student->id, 'assigned_by_user_id' => $teacher->id,
        ]);
        $second = $this->studentBlitzActor($student->institution, ['full_name' => 'alpha', 'id' => '00000000-0000-4000-8000-000000000002']);
        $first = $this->studentBlitzActor($student->institution, ['full_name' => 'ALPHA', 'id' => '00000000-0000-4000-8000-000000000001']);
        $this->blitzRecipient($assessment, $second, $teacher);
        $this->blitzRecipient($assessment, $first, $teacher);
        $this->eligibleBlitzStudent($student->institution, $teacher, $assessment->topic->group);
        $response = $this->monitor($teacher, $assessment)->assertOk()->assertJsonCount(3, 'data.students');
        $this->assertSame([$first->id, $second->id, $student->id], array_column(array_column($response->json('data.students'), 'student'), 'id'));
        $this->assertMonitoringPartition($response);
    }

    public function test_official_and_direct_recipients_use_the_same_operational_projection(): void
    {
        [, $assessment, $teacher] = $this->monitoringContext();
        $assessment->update(['assignment_mode' => 'group']);
        AssessmentStudent::query()->where('assessment_id', $assessment->id)->update(['assignment_source' => 'group']);
        $this->officialBlitzPair($assessment, $teacher, true);
        $this->monitor($teacher, $assessment)->assertOk()->assertJsonPath('data.summary.assigned', 1)
            ->assertJsonPath('data.students.0.status', 'not_started');
    }

    public function test_final_query_families_are_bounded_and_never_read_private_content_or_scores(): void
    {
        [$student, $assessment, $teacher] = $this->monitoringContext();
        $this->studentBlitzQuestions($assessment);
        $this->studentBlitzAttempt($assessment, $student);
        $capture = function () use ($teacher, $assessment): array {
            $queries = [];
            $inSnapshot = false;
            $dispatcher = DB::connection()->getEventDispatcher();
            DB::connection()->setEventDispatcher(clone $dispatcher);
            DB::listen(function (QueryExecuted $query) use (&$queries, &$inSnapshot): void {
                if (str_contains($query->sql, 'AS snapshot_at')) {
                    $inSnapshot = true;
                }
                if ($inSnapshot) {
                    $queries[] = $query->sql;
                }
            });
            try {
                $response = $this->monitor($teacher, $assessment)->assertOk();
                $this->assertMonitoringPartition($response);
                foreach (['questions', 'answers', 'checking_status', 'awarded_points', 'feedback', 'files', 'earned_points', 'normalized_score'] as $private) {
                    $this->assertStringNotContainsString($private, implode(' ', $queries));
                    $this->assertStringNotContainsString($private, $response->getContent());
                }

                return $queries;
            } finally {
                DB::connection()->setEventDispatcher($dispatcher);
            }
        };
        $small = $capture();
        for ($i = 0; $i < 20; $i++) {
            $extra = $this->studentBlitzActor($student->institution);
            $attempt = $this->studentBlitzAttempt($assessment, $extra);
            if ($i % 2 === 0) {
                $this->terminateStudentBlitzAttempt($attempt);
                $this->grantException($teacher, $assessment, $extra)->assertCreated();
            }
        }
        $large = $capture();
        $this->assertLessThanOrEqual(count($small) + 1, count($large));
        foreach (['users', 'assessment_attempts', 'blitz_attempt_exceptions'] as $table) {
            $this->assertCount(1, array_filter($large, fn ($sql) => str_contains($sql, 'from "'.$table.'"')));
        }
    }
}
