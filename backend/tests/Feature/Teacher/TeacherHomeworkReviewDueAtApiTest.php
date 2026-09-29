<?php

namespace Tests\Feature\Teacher;

use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class TeacherHomeworkReviewDueAtApiTest extends TestCase
{
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    private const LOCAL = '2026-10-02T18:00:00+05:00';

    private const UTC = '2026-10-02T13:00:00Z';

    public function test_the_review_deadline_route_is_registered_once_with_teacher_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->filter(fn ($route): bool => $route->uri() === 'api/v1/teacher/homework/{homework}/review-due-at')
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'middleware' => $route->middleware(),
            ])
            ->values()
            ->all();

        $this->assertSame([[
            'methods' => ['PUT'],
            'middleware' => ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'],
        ]], $routes);
    }

    public function test_create_stores_the_review_deadline_as_utc_and_returns_it(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();

        $response = $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload([
            'review_due_at' => self::LOCAL,
        ]));

        $response->assertCreated()->assertJsonPath('data.review_due_at', self::UTC);
        $this->assertReviewDueAt(Assessment::query()->findOrFail($response->json('data.id')), self::UTC);
    }

    public function test_create_without_or_with_a_null_review_deadline_stores_none(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();
        $uri = "/api/v1/teacher/topics/{$topic->id}/homework";

        $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload())
            ->assertCreated()->assertJsonPath('data.review_due_at', null);
        $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload(['review_due_at' => null]))
            ->assertCreated()->assertJsonPath('data.review_due_at', null);
    }

    /** @return array<string, array{mixed}> */
    public static function invalidReviewDeadlines(): array
    {
        return [
            'another offset than the institution' => ['2026-10-02T18:00:00+04:00'],
            'no offset' => ['2026-10-02T18:00:00'],
            'zulu instead of the institution offset' => ['2026-10-02T13:00:00Z'],
            'not a date' => ['tomorrow'],
            'a number' => [1_789_000_000],
        ];
    }

    #[DataProvider('invalidReviewDeadlines')]
    public function test_create_rejects_an_invalid_review_deadline(mixed $value): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();

        $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload([
            'review_due_at' => $value,
        ]))->assertUnprocessable()->assertJsonValidationErrors(['review_due_at']);
        $this->assertDatabaseCount('homework_assignments', 0);
    }

    public function test_a_past_review_deadline_before_the_deadline_is_allowed(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();

        $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload([
            'deadline_at' => '2030-01-10T18:00:00+05:00',
            'review_due_at' => '2020-01-01T09:00:00+05:00',
        ]))->assertCreated()->assertJsonPath('data.review_due_at', '2020-01-01T04:00:00Z');
    }

    #[DataProvider('editableStatuses')]
    public function test_update_sets_and_clears_the_review_deadline_even_with_attempts(HomeworkStatus $status): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
        $assessment = $this->persistedHomework($institution, $teacher, $topic, status: $status);
        $this->attemptFor($assessment);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", ['review_due_at' => self::LOCAL])
            ->assertOk()->assertJsonPath('data.review_due_at', self::UTC);
        $this->assertReviewDueAt($assessment, self::UTC);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", ['review_due_at' => null])
            ->assertOk()->assertJsonPath('data.review_due_at', null);
        $this->assertReviewDueAt($assessment, null);
    }

    /** @return array<string, array{HomeworkStatus}> */
    public static function editableStatuses(): array
    {
        return ['draft' => [HomeworkStatus::Draft], 'active' => [HomeworkStatus::Active]];
    }

    public function test_update_with_the_same_instant_writes_nothing(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $stored = CarbonImmutable::parse(self::UTC);
        $original = CarbonImmutable::parse('2026-09-01 08:00:00', 'UTC');
        $assessment = $this->persistedHomework($institution, $teacher, $topic, homeworkAttributes: [
            'review_due_at' => $stored,
            'updated_at' => $original,
        ]);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", ['review_due_at' => self::LOCAL])
            ->assertOk()->assertJsonPath('data.review_due_at', self::UTC);
        $this->assertSame(
            $original->toIso8601String(),
            HomeworkAssignment::query()->whereKey($assessment->id)->firstOrFail()->updated_at?->toIso8601String(),
        );
    }

    /** @return array<string, array{HomeworkStatus, TopicStatus, string}> */
    public static function updateConflicts(): array
    {
        return [
            'closed homework' => [HomeworkStatus::Closed, TopicStatus::Active, 'task_closed'],
            'archived homework' => [HomeworkStatus::Archived, TopicStatus::Active, 'task_archived'],
            'closed topic' => [HomeworkStatus::Draft, TopicStatus::Closed, 'topic_not_editable'],
        ];
    }

    #[DataProvider('updateConflicts')]
    public function test_update_keeps_the_existing_editability(HomeworkStatus $status, TopicStatus $topicStatus, string $code): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext($topicStatus);
        $assessment = $this->persistedHomework($institution, $teacher, $topic, status: $status);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/homework/{$assessment->id}", ['review_due_at' => self::LOCAL])
            ->assertConflict()->assertJsonPath('code', $code);
        $this->assertReviewDueAt($assessment, null);
    }

    /** @return array<string, array{HomeworkStatus}> */
    public static function settableStatuses(): array
    {
        return [
            'draft' => [HomeworkStatus::Draft],
            'active' => [HomeworkStatus::Active],
            'closed' => [HomeworkStatus::Closed],
        ];
    }

    #[DataProvider('settableStatuses')]
    public function test_the_endpoint_sets_and_clears_the_review_deadline(HomeworkStatus $status): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
        $assessment = $this->persistedHomework($institution, $teacher, $topic, status: $status);
        $this->attemptFor($assessment);

        $response = $this->putReviewDueAt($teacher, $assessment, ['review_due_at' => self::LOCAL]);

        $response->assertOk()
            ->assertJsonPath('data.id', $assessment->id)
            ->assertJsonPath('data.status', $status->value)
            ->assertJsonPath('data.review_due_at', self::UTC);
        $this->assertSame([
            'id', 'topic_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'deadline_at', 'review_due_at', 'institution_timezone', 'status',
            'attempt_policy', 'activated_at', 'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $this->assertReviewDueAt($assessment, self::UTC);

        $this->putReviewDueAt($teacher, $assessment, ['review_due_at' => null])
            ->assertOk()->assertJsonPath('data.review_due_at', null);
        $this->assertReviewDueAt($assessment, null);
    }

    /** @return array<string, array{HomeworkStatus, TopicStatus, string}> */
    public static function endpointConflicts(): array
    {
        return [
            'archived homework' => [HomeworkStatus::Archived, TopicStatus::Active, 'task_archived'],
            'archived homework in an archived topic' => [HomeworkStatus::Archived, TopicStatus::Archived, 'task_archived'],
            'closed topic' => [HomeworkStatus::Closed, TopicStatus::Closed, 'topic_not_editable'],
            'archived topic' => [HomeworkStatus::Closed, TopicStatus::Archived, 'topic_not_editable'],
        ];
    }

    #[DataProvider('endpointConflicts')]
    public function test_the_endpoint_rejects_archived_homework_and_closed_topics(
        HomeworkStatus $status,
        TopicStatus $topicStatus,
        string $code,
    ): void {
        [$institution, $teacher, , , $topic] = $this->homeworkContext($topicStatus);
        $assessment = $this->persistedHomework($institution, $teacher, $topic, status: $status);

        $this->putReviewDueAt($teacher, $assessment, ['review_due_at' => self::LOCAL])
            ->assertConflict()->assertJsonPath('code', $code);
        $this->assertReviewDueAt($assessment, null);
    }

    /** @return array<string, array{string, array<string, mixed>}> */
    public static function invalidBodies(): array
    {
        return [
            'missing key' => ['{}', []],
            'extra key' => ['{"review_due_at":null,"deadline_at":null}', []],
            'a number' => ['{"review_due_at":1}', []],
            'an array' => ['{"review_due_at":[]}', []],
            'a wrong offset' => ['{"review_due_at":"2026-10-02T18:00:00+04:00"}', []],
            'a list body' => ['[]', []],
            'not json' => ['review_due_at=null', []],
            'a query parameter' => ['{"review_due_at":null}', ['review_due_at' => 'x']],
        ];
    }

    /** @param array<string, mixed> $query */
    #[DataProvider('invalidBodies')]
    public function test_the_endpoint_requires_a_strict_body(string $body, array $query): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $assessment = $this->persistedHomework($institution, $teacher, $topic);

        $this->homeworkRaw($teacher, 'PUT', $this->uri($assessment), $body, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertReviewDueAt($assessment, null);
    }

    public function test_homework_the_teacher_cannot_see_is_not_found(): void
    {
        [$institution, $teacher, $admin, $group] = $this->homeworkContext();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $otherTopic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $otherTeacher->id,
        ]);
        $otherTeachersHomework = $this->persistedHomework($institution, $otherTeacher, $otherTopic);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->homeworkContext();
        $foreignHomework = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);

        foreach ([$otherTeachersHomework->id, $foreignHomework->id, '00000000-0000-4000-8000-000000000001'] as $homeworkId) {
            $this->homeworkJson($teacher, 'PUT', "/api/v1/teacher/homework/{$homeworkId}/review-due-at", ['review_due_at' => self::LOCAL])
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertReviewDueAt($otherTeachersHomework, null);
        $this->assertReviewDueAt($foreignHomework, null);
        $this->assertNotNull($admin);
    }

    public function test_a_student_cannot_set_a_review_deadline(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $assessment = $this->persistedHomework($institution, $teacher, $topic);
        $student = $this->eligibleStudent($institution, $admin, $group, ['must_change_password' => false]);

        $this->homeworkJson($student, 'PUT', $this->uri($assessment), ['review_due_at' => self::LOCAL])
            ->assertForbidden();
        $this->assertReviewDueAt($assessment, null);
    }

    /** @param array<string, mixed> $payload */
    private function putReviewDueAt(User $teacher, Assessment $assessment, array $payload): TestResponse
    {
        return $this->homeworkJson($teacher, 'PUT', $this->uri($assessment), $payload);
    }

    private function uri(Assessment $assessment): string
    {
        return "/api/v1/teacher/homework/{$assessment->id}/review-due-at";
    }

    private function attemptFor(Assessment $assessment): void
    {
        AssessmentAttempt::factory()->create([
            'assessment_student_id' => AssessmentStudent::factory()->create([
                'assessment_id' => $assessment->id,
                'institution_id' => $assessment->institution_id,
                'assigned_by_user_id' => $assessment->teacher_id,
            ])->id,
        ]);
    }

    private function assertReviewDueAt(Assessment $assessment, ?string $expected): void
    {
        $stored = HomeworkAssignment::query()->whereKey($assessment->id)->firstOrFail()->review_due_at;

        $this->assertSame($expected, $stored?->utc()->format('Y-m-d\TH:i:s\Z'));
    }
}
