<?php

namespace Tests\Feature\Student;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAttemptFinalizationReason;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\UserRole;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\GroupStudentMembership;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\User;
use App\Support\Student\StudentHomeworkAccess;
use App\Support\Student\StudentHomeworkAttemptSummary;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class StudentHomeworkReadApiTest extends TestCase
{
    use RefreshDatabase;

    private const URI = '/api/v1/student/homework';

    protected function setUp(): void
    {
        parent::setUp();

        $this->travelTo(Carbon::parse('2026-09-09 09:00:00 UTC'));
    }

    public function test_exact_read_routes_use_existing_student_middleware_and_authentication_gates(): void
    {
        $routes = collect(Route::getRoutes())
            ->filter(fn ($route): bool => str_contains($route->uri(), 'student/homework'))
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])->values()->all();
        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'];
        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/student/homework', 'middleware' => $middleware],
            ['methods' => ['GET'], 'uri' => 'api/v1/student/homework/{homework}', 'middleware' => $middleware],
        ], $routes);

        $institution = $this->institution();
        $inactiveInstitution = Institution::factory()->inactive()->create();
        $gatedActors = [
            [$this->student($institution, ['is_active' => false]), 'user_inactive'],
            [$this->student($institution, ['must_change_password' => true]), 'password_change_required'],
            [$this->student($inactiveInstitution), 'institution_inactive'],
        ];
        foreach ([UserRole::Teacher, UserRole::InstitutionAdmin, UserRole::Parent, UserRole::PlatformOwner] as $role) {
            $actor = $role === UserRole::PlatformOwner
                ? User::factory()->platformOwner()->create()
                : User::factory()->for($institution)->create(['role' => $role, 'must_change_password' => false]);
            $gatedActors[] = [$actor, 'forbidden'];
        }

        foreach ([self::URI, self::URI.'/'.Str::uuid()] as $uri) {
            $this->getJson($uri)->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
            foreach ($gatedActors as [$actor, $code]) {
                $this->requestAs($actor, $uri)->assertForbidden()->assertJsonPath('code', $code);
            }
        }
    }

    public function test_list_defaults_and_exact_summary_envelope_exclude_private_fields_and_scores(): void
    {
        $student = $this->student($this->institution());
        $homework = $this->homework($student, assessment: ['title' => 'Homework 1'], attributes: [
            'deadline_at' => now()->addDay(),
        ]);
        $response = $this->requestAs($student, self::URI)->assertOk();

        $this->assertSame(['data', 'meta'], array_keys($response->json()));
        $this->assertSame(['pagination'], array_keys($response->json('meta')));
        $this->assertSame(['page' => 1, 'per_page' => 20, 'total' => 1, 'last_page' => 1], $response->json('meta.pagination'));
        $this->assertSame([
            'id' => $homework->assessment_id,
            'topic' => ['id' => $homework->assessment->topic_id, 'title' => $homework->assessment->topic->title],
            'title' => 'Homework 1',
            'status' => 'active',
            'deadline_at' => '2026-09-10T09:00:00Z',
            'attempts' => ['allowed' => 3, 'used' => 0, 'remaining' => 3, 'official_score_policy' => 'highest_valid_completed'],
            'my_status' => 'not_started',
            'score_visible' => false,
        ], $response->json('data.0'));
    }

    public function test_persisted_assignment_survives_membership_end_and_only_readable_homework_is_visible(): void
    {
        $institution = $this->institution();
        $student = $this->student($institution);
        $otherStudent = $this->student($institution);
        $active = $this->homework($student);
        $closed = $this->homework($student, 'closed');
        $archived = $this->homework($student, 'archivedAfterClose');
        $membership = GroupStudentMembership::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $active->assessment->topic->group_id,
            'student_id' => $student->id,
            'started_at' => now()->subDay(),
        ]);
        $membership->update(['ended_at' => now()]);
        $draft = $this->homework($student, 'draft', ['assignment_mode' => AssessmentAssignmentMode::SelectedStudents]);
        $other = $this->homework($otherStudent);
        $foreign = $this->homework($this->student($this->institution()));
        $blitz = $this->homework($student, assessment: ['type' => AssessmentType::Blitz]);
        $missingAssignment = Assessment::factory()->homework()->create(['institution_id' => $institution->id]);
        $this->recipient($missingAssignment, $student);

        $response = $this->requestAs($student, self::URI)->assertOk();
        $this->assertEqualsCanonicalizing([$active->assessment_id, $closed->assessment_id, $archived->assessment_id], $this->ids($response));
        foreach ([$active, $closed, $archived] as $readable) {
            $this->requestAs($student, self::URI.'/'.$readable->assessment_id)->assertOk()->assertJsonPath('data.id', $readable->assessment_id);
            $this->assertSame([$readable->assessment_id], $this->ids($this->requestAs($student, self::URI, ['status' => $readable->status->value])));
        }
        foreach ([$draft->assessment_id, $other->assessment_id, $foreign->assessment_id, $blitz->assessment_id, $missingAssignment->id, 'not-a-uuid', (string) Str::uuid()] as $hiddenId) {
            $this->requestAs($student, self::URI.'/'.$hiddenId)->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertStringNotContainsString($hiddenId, $response->getContent());
        }

        $this->assertSame([$active->assessment_id], $this->ids($this->requestAs($student, self::URI, ['topic_id' => $active->assessment->topic_id])));
        foreach ([$other->assessment->topic_id, $foreign->assessment->topic_id, (string) Str::uuid()] as $topicId) {
            $empty = $this->requestAs($student, self::URI, ['topic_id' => $topicId])->assertOk();
            $this->assertSame([], $empty->json('data'));
            $this->assertSame(0, $empty->json('meta.pagination.total'));
        }
    }

    #[DataProvider('invalidListQueries')]
    public function test_list_rejects_invalid_or_unknown_query_fields(array $query): void
    {
        $student = $this->student($this->institution());

        $this->requestAs($student, self::URI, $query)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
    }

    public static function invalidListQueries(): array
    {
        return [
            'unknown key' => [['unknown' => 'x']],
            'malformed topic' => [['topic_id' => 'not-a-uuid']],
            'array topic' => [['topic_id' => ['uuid']]],
            'draft status' => [['status' => 'draft']],
            'unknown status' => [['status' => 'published']],
            'unknown sort' => [['sort' => 'teacher_id']],
            'unknown direction' => [['direction' => 'descending']],
            'page zero' => [['page' => 0]],
            'negative page' => [['page' => -1]],
            'fractional page' => [['page' => 1.5]],
            'non-numeric page' => [['page' => 'one']],
            'page size zero' => [['per_page' => 0]],
            'negative page size' => [['per_page' => -1]],
            'oversized page' => [['per_page' => 101]],
            'fractional page size' => [['per_page' => 1.5]],
        ];
    }

    public function test_list_accepts_all_query_fields_and_page_boundaries_and_detail_rejects_any_input(): void
    {
        $student = $this->student($this->institution());
        $homework = $this->homework($student);
        foreach ([1, 100] as $perPage) {
            $this->requestAs($student, self::URI, [
                'topic_id' => $homework->assessment->topic_id,
                'status' => 'active',
                'page' => 1,
                'per_page' => $perPage,
                'sort' => 'title',
                'direction' => 'asc',
            ])->assertOk()->assertJsonPath('meta.pagination.per_page', $perPage)->assertJsonPath('data.0.id', $homework->assessment_id);
        }
        $this->requestAs($student, self::URI, ['page' => 2])->assertOk()->assertJsonCount(0, 'data')->assertJsonPath('meta.pagination.total', 1);
        $this->requestAs($student, self::URI.'/'.$homework->assessment_id, ['topic_id' => $homework->assessment->topic_id])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        foreach ([self::URI, self::URI.'/'.$homework->assessment_id] as $uri) {
            foreach (['{}', '[]', 'null', ' ', '{"page":1}'] as $body) {
                $this->requestAs($student, $uri, content: $body)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            }
        }
    }

    #[DataProvider('sortOrders')]
    public function test_sorting_is_applied_in_sql_before_pagination_with_deterministic_ties(string $sort, string $direction, array $expectedNumbers): void
    {
        $student = $this->student($this->institution());
        $fixtures = [
            ['zebra', 'active', 2, 1],
            ['ALPHA', 'closed', 1, 2],
            ['alpha', 'archivedAfterClose', 1, 2],
            ['beta', 'active', null, 3],
        ];
        $ids = [];
        foreach ($fixtures as $index => [$title, $state, $deadlineOffset, $createdOffset]) {
            $ids[$index + 1] = sprintf('00000000-0000-4000-8000-%012d', $index + 1);
            $this->homework($student, $state, [
                'id' => $ids[$index + 1],
                'title' => $title,
                'created_at' => now()->subHours($createdOffset),
            ], ['deadline_at' => $deadlineOffset === null ? null : now()->addDays($deadlineOffset)]);
        }
        $expected = array_map(fn (int $number): string => $ids[$number], $expectedNumbers);
        [$page, $queries] = $this->recordListQueries($student, ['sort' => $sort, 'direction' => $direction, 'per_page' => 2, 'page' => 2]);
        $this->assertSame(array_slice($expected, 2), $this->ids($page));
        $this->assertSame(['page' => 2, 'per_page' => 2, 'total' => 4, 'last_page' => 2], $page->json('meta.pagination'));
        $this->assertSame($expected, $this->ids($this->requestAs($student, self::URI, ['sort' => $sort, 'direction' => $direction])));

        $paginatedQueries = array_values(array_filter($queries, fn (array $query): bool => str_contains($query['query'], 'from "assessments"') && str_contains(strtolower($query['query']), 'offset 2')));
        $this->assertCount(1, $paginatedQueries);
        $sql = strtolower(str_replace('"', '', $paginatedQueries[0]['query']));
        $this->assertStringContainsString('limit 2 offset 2', $sql);
        $this->assertStringContainsString('assessments.id '.$direction, $sql);
        $expression = match ($sort) {
            'created_at' => 'assessments.created_at',
            'title' => 'lower(assessments.title)',
            'deadline_at' => 'homework_assignments.deadline_at',
            'status' => 'homework_assignments.status',
        };
        $this->assertStringContainsString($expression.' '.$direction.($sort === 'deadline_at' ? ' nulls last' : ''), $sql);
    }

    public static function sortOrders(): array
    {
        return [
            'created ascending' => ['created_at', 'asc', [4, 2, 3, 1]],
            'created descending' => ['created_at', 'desc', [1, 3, 2, 4]],
            'case-insensitive title ascending' => ['title', 'asc', [2, 3, 4, 1]],
            'case-insensitive title descending' => ['title', 'desc', [1, 4, 3, 2]],
            'deadline ascending nulls last' => ['deadline_at', 'asc', [2, 3, 1, 4]],
            'deadline descending nulls last' => ['deadline_at', 'desc', [1, 3, 2, 4]],
            'status ascending' => ['status', 'asc', [1, 4, 3, 2]],
            'status descending' => ['status', 'desc', [2, 3, 4, 1]],
        ];
    }

    public function test_attempt_usage_counts_only_student_history_and_detail_exposes_exact_resume_identity(): void
    {
        $student = $this->student($this->institution());
        $homework = $this->homework($student, assessment: [
            'description' => 'Read each question.',
            'student_instructions' => 'Complete independently.',
            'total_possible_points' => '10.000000',
        ]);
        $this->attempt($homework, $student, 1, AssessmentAttemptStatus::Submitted);
        $current = $this->attempt($homework, $student, 2);
        $otherStudent = $this->student($student->institution);
        $otherRecipient = $this->recipient($homework->assessment, $otherStudent);
        AssessmentAttempt::factory()->create([
            'assessment_student_id' => $otherRecipient,
            'status' => AssessmentAttemptStatus::TimedOutFinalized,
            'finalization_reason' => AssessmentAttemptFinalizationReason::TimeoutAutoSubmit,
        ]);

        $list = $this->requestAs($student, self::URI)->assertOk();
        $list->assertJsonPath('data.0.attempts.used', 2)->assertJsonPath('data.0.attempts.remaining', 1)->assertJsonPath('data.0.my_status', 'in_progress');
        $this->assertArrayNotHasKey('in_progress_attempt', $list->json('data.0.attempts'));
        $detail = $this->requestAs($student, self::URI.'/'.$homework->assessment_id)->assertOk();
        $this->assertSame(['data'], array_keys($detail->json()));
        $this->assertSame([
            'id', 'topic', 'title', 'description', 'student_instructions', 'status', 'deadline_at',
            'total_possible_points', 'attempts', 'my_status', 'score_visible', 'questions',
        ], array_keys($detail->json('data')));
        $this->assertSame([
            'allowed' => 3, 'used' => 2, 'remaining' => 1, 'official_score_policy' => 'highest_valid_completed',
            'in_progress_attempt' => ['id' => $current->id, 'attempt_number' => 2, 'started_at' => '2026-09-09T09:00:00Z'],
        ], $detail->json('data.attempts'));
        $detail->assertJsonPath('data.score_visible', false)->assertJsonPath('data.my_status', 'in_progress');
        foreach (['score', 'official_score', 'earned_points', 'normalized_score', 'answers', 'institution_id', 'teacher_id', 'assignment_mode', 'assessment_student_id'] as $hidden) {
            $this->assertArrayNotHasKey($hidden, $detail->json('data'));
        }
    }

    #[DataProvider('completedAttemptStatuses')]
    public function test_highest_attempt_number_controls_history_status_and_all_three_attempts_use_capacity(AssessmentAttemptStatus $latestStatus): void
    {
        $student = $this->student($this->institution());
        $homework = $this->homework($student);
        $this->attempt($homework, $student, 3, $latestStatus);
        $this->attempt($homework, $student, 1, AssessmentAttemptStatus::Checked);
        $this->attempt($homework, $student, 2, AssessmentAttemptStatus::Submitted);

        $this->requestAs($student, self::URI)->assertOk()->assertJsonPath('data.0.attempts.used', 3)
            ->assertJsonPath('data.0.attempts.remaining', 0)->assertJsonPath('data.0.my_status', $latestStatus->value);
        $this->requestAs($student, self::URI.'/'.$homework->assessment_id)->assertOk()
            ->assertJsonPath('data.attempts.used', 3)->assertJsonPath('data.attempts.remaining', 0)
            ->assertJsonPath('data.attempts.in_progress_attempt', null)->assertJsonPath('data.my_status', $latestStatus->value);
    }

    public static function completedAttemptStatuses(): array
    {
        return [
            'submitted' => [AssessmentAttemptStatus::Submitted],
            'waiting for review' => [AssessmentAttemptStatus::WaitingForTeacherReview],
            'checked' => [AssessmentAttemptStatus::Checked],
        ];
    }

    public function test_closed_archived_and_expired_homework_have_no_remaining_capacity_without_fabricated_attempts(): void
    {
        $student = $this->student($this->institution());
        $homework = [
            $this->homework($student, 'closed'),
            $this->homework($student, 'archivedAfterClose'),
            $this->homework($student, attributes: ['deadline_at' => now()]),
        ];
        foreach ($homework as $assignment) {
            $this->requestAs($student, self::URI.'/'.$assignment->assessment_id)->assertOk()
                ->assertJsonPath('data.attempts.used', 0)->assertJsonPath('data.attempts.remaining', 0)
                ->assertJsonPath('data.attempts.in_progress_attempt', null)->assertJsonPath('data.my_status', 'not_started');
        }
        foreach ($this->requestAs($student, self::URI)->assertOk()->json('data') as $summary) {
            $this->assertSame(0, $summary['attempts']['remaining']);
            $this->assertSame(0, $summary['attempts']['used']);
        }
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    public function test_mismatched_persisted_recipient_fails_both_reads_without_exposing_or_repairing_attempt_history(): void
    {
        $student = $this->student($this->institution());
        $homework = $this->homework($student);
        $otherHomework = $this->homework($student);
        $attempt = $this->attempt($homework, $student);
        $wrongRecipient = AssessmentStudent::query()->where('assessment_id', $otherHomework->assessment_id)->where('student_id', $student->id)->sole();
        DB::table('assessment_attempts')->where('id', $attempt->id)->update(['assessment_student_id' => $wrongRecipient->id]);
        $before = $attempt->fresh()->getAttributes();

        foreach ([self::URI, self::URI.'/'.$homework->assessment_id] as $uri) {
            $this->assertInvariantFailure($student, $uri);
            $this->assertSame($before, $attempt->fresh()->getAttributes());
        }
    }

    public function test_loaded_multiple_in_progress_attempts_fail_instead_of_selecting_an_arbitrary_resume_identity(): void
    {
        $student = $this->student($this->institution());
        $homework = $this->homework($student);
        $this->attempt($homework, $student);
        $readAt = now();
        $assessment = app(StudentHomeworkAccess::class)->readQuery($student)->whereKey($homework->assessment_id)->sole();
        $duplicate = $assessment->attempts->sole()->replicate();
        $duplicate->id = (string) Str::uuid();
        $duplicate->attempt_number = 2;
        $assessment->attempts->push($duplicate);

        $this->assertDatabaseCount('assessment_attempts', 1);
        $this->expectException(LogicException::class);

        app(StudentHomeworkAttemptSummary::class)($student, $assessment, $readAt);
    }

    #[DataProvider('invalidHomeworkAttemptStates')]
    public function test_homework_rejects_blitz_only_and_inconsistent_attempt_states(AssessmentAttemptStatus $status, ?AssessmentAttemptFinalizationReason $reason): void
    {
        $student = $this->student($this->institution());
        $homework = $this->homework($student);
        $attempt = $this->attempt($homework, $student);
        $attempt->update(['status' => $status, 'finalization_reason' => $reason]);

        foreach ([self::URI, self::URI.'/'.$homework->assessment_id] as $uri) {
            $this->assertInvariantFailure($student, $uri);
        }
    }

    public static function invalidHomeworkAttemptStates(): array
    {
        return [
            'Blitz-only status' => [AssessmentAttemptStatus::TimedOutFinalized, AssessmentAttemptFinalizationReason::StudentSubmit],
            'submitted with Blitz timeout' => [AssessmentAttemptStatus::Submitted, AssessmentAttemptFinalizationReason::TimeoutAutoSubmit],
            'review with Blitz timeout' => [AssessmentAttemptStatus::WaitingForTeacherReview, AssessmentAttemptFinalizationReason::TimeoutAutoSubmit],
            'checked with Blitz timeout' => [AssessmentAttemptStatus::Checked, AssessmentAttemptFinalizationReason::TimeoutAutoSubmit],
            'in progress with a reason' => [AssessmentAttemptStatus::InProgress, AssessmentAttemptFinalizationReason::StudentSubmit],
            'submitted without a reason' => [AssessmentAttemptStatus::Submitted, null],
        ];
    }

    public function test_list_query_count_remains_bounded_when_returned_homework_and_student_attempt_counts_grow(): void
    {
        $student = $this->student($this->institution());
        $first = $this->homework($student);
        $this->attempt($first, $student);
        [$small, $smallQueries] = $this->recordListQueries($student, ['per_page' => 100]);
        $small->assertOk()->assertJsonCount(1, 'data');
        for ($index = 0; $index < 11; $index++) {
            $assignment = $this->homework($student);
            $this->attempt($assignment, $student, 1, AssessmentAttemptStatus::Submitted);
            $this->attempt($assignment, $student, 2, AssessmentAttemptStatus::Submitted);
            $this->attempt($assignment, $student, 3);
        }
        [$large, $largeQueries] = $this->recordListQueries($student, ['per_page' => 100]);
        $large->assertOk()->assertJsonCount(12, 'data');

        $this->assertLessThanOrEqual(count($smallQueries) + 2, count($largeQueries));
        $attemptQueries = array_filter($largeQueries, fn (array $query): bool => str_starts_with($query['query'], 'select') && str_contains($query['query'], 'from "assessment_attempts"'));
        $this->assertNotEmpty($attemptQueries);
        foreach ($attemptQueries as $query) {
            $this->assertStringContainsString('student_id', $query['query']);
            $this->assertContains($student->id, $query['bindings']);
        }
    }

    private function institution(): Institution
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create(['institution_id' => $institution]);

        return $institution;
    }

    private function student(Institution $institution, array $attributes = []): User
    {
        return User::factory()->student($institution)->create(array_merge(['must_change_password' => false], $attributes));
    }

    private function homework(User $student, string $state = 'active', array $assessment = [], array $attributes = []): HomeworkAssignment
    {
        $homeworkAssessment = Assessment::factory()->homework()->create(array_merge(['institution_id' => $student->institution_id], $assessment));
        $homework = HomeworkAssignment::factory()->{$state}()->create(array_merge(['assessment_id' => $homeworkAssessment], $attributes));
        $this->recipient($homeworkAssessment, $student);

        return $homework;
    }

    private function recipient(Assessment $assessment, User $student): AssessmentStudent
    {
        return AssessmentStudent::factory()->create([
            'institution_id' => $student->institution_id,
            'assessment_id' => $assessment->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $assessment->teacher_id,
        ]);
    }

    private function attempt(HomeworkAssignment $homework, User $student, int $number = 1, AssessmentAttemptStatus $status = AssessmentAttemptStatus::InProgress): AssessmentAttempt
    {
        $recipient = AssessmentStudent::query()->where('assessment_id', $homework->assessment_id)->where('student_id', $student->id)->sole();
        $completed = $status !== AssessmentAttemptStatus::InProgress;

        return AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient,
            'attempt_number' => $number,
            'status' => $status,
            'submitted_at' => $completed ? now() : null,
            'finalized_at' => $completed ? now() : null,
            'locked_at' => $completed ? now() : null,
            'finalization_reason' => $completed ? AssessmentAttemptFinalizationReason::StudentSubmit : null,
        ]);
    }

    private function requestAs(User $actor, string $uri, array $query = [], string $content = ''): TestResponse
    {
        $requestUri = $uri.($query === [] ? '' : '?'.http_build_query($query));
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$actor->createToken('student-homework-read-test')->plainTextToken,
        ];

        try {
            return $this->call('GET', $requestUri, [], [], [], $server, $content);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }

    private function assertInvariantFailure(User $student, string $uri): void
    {
        $this->withoutExceptionHandling();
        try {
            $this->requestAs($student, $uri);
            $this->fail('Corrupted Homework Attempt persistence must fail as an internal invariant.');
        } catch (LogicException) {
            $this->assertTrue(true);
        } finally {
            $this->withExceptionHandling();
        }

        $response = $this->requestAs($student, $uri)->assertStatus(500);
        foreach (['timed_out_finalized', 'timeout_auto_submit', 'in_progress_attempt', 'my_status', '"used"'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    private function recordListQueries(User $student, array $query): array
    {
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $response = $this->requestAs($student, self::URI, $query);

            return [$response, DB::getQueryLog()];
        } finally {
            DB::disableQueryLog();
        }
    }

    private function ids(TestResponse $response): array
    {
        $response->assertOk();

        return collect($response->json('data'))->pluck('id')->all();
    }
}
