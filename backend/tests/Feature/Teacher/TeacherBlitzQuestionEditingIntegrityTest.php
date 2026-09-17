<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAttemptStatus;
use App\Enums\AssessmentType;
use App\Enums\BlitzStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\GroupTeacherMembership;
use App\Models\Question;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\Feature\Teacher\Concerns\BuildsTeacherQuestionMutationContext;
use Tests\TestCase;

class TeacherBlitzQuestionEditingIntegrityTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use BuildsTeacherQuestionMutationContext;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(now()->setDate(2026, 9, 16)->setTime(8, 0));
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        parent::tearDown();
    }

    #[DataProvider('editableStates')]
    public function test_all_mutations_allow_draft_and_scheduled_blitz_in_editable_topics(
        TopicStatus $topicStatus,
        BlitzStatus $blitzStatus,
    ): void {
        [$institution, $teacher, , , $topic] = $this->blitzContext($topicStatus);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $blitzStatus);

        $this->assertAllMutationsSucceed($teacher, $assessment);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    /** @return iterable<string, array{TopicStatus, BlitzStatus}> */
    public static function editableStates(): iterable
    {
        foreach ([TopicStatus::Draft, TopicStatus::Active] as $topicStatus) {
            foreach ([BlitzStatus::Draft, BlitzStatus::Scheduled] as $blitzStatus) {
                yield "{$topicStatus->value} topic, {$blitzStatus->value} Blitz" => [$topicStatus, $blitzStatus];
            }
        }
    }

    #[DataProvider('preactivationStates')]
    public function test_historically_locked_official_pair_allows_every_mutation_and_remains_exactly_unchanged(
        BlitzStatus $status,
    ): void {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
        $pair = $this->officialBlitzPair($assessment, $teacher, locked: true);
        $pair->forceFill([
            'designated_at' => now()->subHours(3),
            'cohort_snapshotted_at' => now()->subHours(2),
            'locked_at' => now()->subHour(),
        ])->save();

        $this->assertAllMutationsSucceed($teacher, $assessment, $pair);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('assessment_attempts', 0);
    }

    /** @return iterable<string, array{BlitzStatus}> */
    public static function preactivationStates(): iterable
    {
        yield 'draft' => [BlitzStatus::Draft];
        yield 'scheduled' => [BlitzStatus::Scheduled];
    }

    #[DataProvider('blockedStates')]
    public function test_lifecycle_conflicts_block_every_mutation_and_precede_historical_pair_and_attempt_checks(
        TopicStatus $topicStatus,
        BlitzStatus $blitzStatus,
        string $code,
        bool $hasAttempt,
    ): void {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext($topicStatus);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $blitzStatus);
        [$first, $second] = $this->integrityQuestions($assessment);
        $this->officialBlitzPair($assessment, $teacher, locked: true);
        if ($hasAttempt) {
            $student = $this->eligibleBlitzStudent($institution, $admin, $group);
            $this->blitzAttempt($assessment, $student, $teacher, ['possible_points' => '2.000000']);
        }
        $snapshot = $this->questionDomainSnapshot($assessment);
        $this->travel(5)->minutes();

        foreach ($this->mutationRoutes($assessment->id, $first->id, $second->id) as [$method, $uri, $payload]) {
            $this->mutationResponse($teacher, $method, $uri, $payload)
                ->assertConflict()->assertJsonPath('code', $code);
            $this->assertSame($snapshot, $this->questionDomainSnapshot($assessment));
        }
    }

    /** @return iterable<string, array{TopicStatus, BlitzStatus, string, bool}> */
    public static function blockedStates(): iterable
    {
        yield 'active without Attempts' => [TopicStatus::Active, BlitzStatus::Active, 'business_conflict', false];
        yield 'closed without Attempts' => [TopicStatus::Draft, BlitzStatus::Closed, 'task_closed', false];
        yield 'archived without Attempts' => [TopicStatus::Draft, BlitzStatus::Archived, 'task_archived', false];
        yield 'closed Topic' => [TopicStatus::Closed, BlitzStatus::Draft, 'topic_not_editable', false];
        yield 'archived Topic' => [TopicStatus::Archived, BlitzStatus::Scheduled, 'topic_not_editable', false];
        yield 'closed Topic precedes active Blitz and Attempt' => [TopicStatus::Closed, BlitzStatus::Active, 'topic_not_editable', true];
        yield 'archived Topic precedes closed Blitz and Attempt' => [TopicStatus::Archived, BlitzStatus::Closed, 'topic_not_editable', true];
        yield 'closed Blitz precedes Attempt' => [TopicStatus::Active, BlitzStatus::Closed, 'task_closed', true];
        yield 'archived Blitz precedes Attempt' => [TopicStatus::Active, BlitzStatus::Archived, 'task_archived', true];
    }

    #[DataProvider('attemptLockedStates')]
    public function test_any_attempt_status_blocks_every_preactivation_mutation_without_domain_writes(
        BlitzStatus $blitzStatus,
        AssessmentAttemptStatus $attemptStatus,
    ): void {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $blitzStatus);
        [$first, $second] = $this->integrityQuestions($assessment);
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $this->blitzAttempt($assessment, $student, $teacher, [
            'status' => $attemptStatus,
            'possible_points' => '2.000000',
        ]);
        $this->officialBlitzPair($assessment, $teacher, locked: true);
        $snapshot = $this->questionDomainSnapshot($assessment);
        $this->travel(5)->minutes();

        foreach ($this->mutationRoutes($assessment->id, $first->id, $second->id) as [$method, $uri, $payload]) {
            $this->mutationResponse($teacher, $method, $uri, $payload)
                ->assertConflict()->assertJsonPath('code', 'business_conflict');
            $this->assertSame($snapshot, $this->questionDomainSnapshot($assessment));
        }
    }

    /** @return iterable<string, array{BlitzStatus, AssessmentAttemptStatus}> */
    public static function attemptLockedStates(): iterable
    {
        foreach ([BlitzStatus::Draft, BlitzStatus::Scheduled] as $blitzStatus) {
            foreach (AssessmentAttemptStatus::cases() as $attemptStatus) {
                yield "{$blitzStatus->value}, {$attemptStatus->value}" => [$blitzStatus, $attemptStatus];
            }
        }
    }

    public function test_all_four_routes_require_authentication_and_teacher_role_without_writes(): void
    {
        [$institution, $teacher, $admin, , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        [$first, $second] = $this->integrityQuestions($assessment);
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $snapshot = $this->questionDomainSnapshot($assessment);

        foreach ($this->mutationRoutes($assessment->id, $first->id, $second->id) as [$method, $uri, $payload]) {
            $this->json($method, $uri, $payload ?? [])
                ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
            foreach ([$admin, $student] as $nonTeacher) {
                $this->mutationResponse($nonTeacher, $method, $uri, $payload)
                    ->assertForbidden()->assertJsonPath('code', 'forbidden');
            }
            $this->assertSame($snapshot, $this->questionDomainSnapshot($assessment));
        }
    }

    public function test_foreign_other_teacher_and_inaccessible_topic_identifiers_are_private_on_every_route(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->blitzContext();
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $otherTeacherAssessment = $this->persistedBlitz($institution, $otherTeacher, $topic);
        $otherTeacherTopic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $otherTeacher->id,
        ]);
        $inaccessibleTopicAssessment = $this->persistedBlitz($institution, $teacher, $otherTeacherTopic);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->blitzContext();
        $foreignAssessment = $this->persistedBlitz($foreignInstitution, $foreignTeacher, $foreignTopic);
        $expectedError = null;

        foreach ([$otherTeacherAssessment, $inaccessibleTopicAssessment, $foreignAssessment] as $assessment) {
            [$first, $second] = $this->integrityQuestions($assessment);
            $snapshot = $this->questionDomainSnapshot($assessment);
            foreach ($this->mutationRoutes($assessment->id, $first->id, $second->id) as [$method, $uri, $payload]) {
                $response = $this->mutationResponse($teacher, $method, $uri, $payload)
                    ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
                $expectedError ??= $response->json();
                $this->assertSame($expectedError, $response->json());
                $this->assertSame($snapshot, $this->questionDomainSnapshot($assessment));
            }
        }
    }

    public function test_ended_teacher_membership_removes_all_four_mutation_routes_without_writes(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        [$first, $second] = $this->integrityQuestions($assessment);
        GroupTeacherMembership::query()->where('teacher_id', $teacher->id)->where('group_id', $group->id)
            ->update(['ended_at' => now()]);
        $snapshot = $this->questionDomainSnapshot($assessment);

        foreach ($this->mutationRoutes($assessment->id, $first->id, $second->id) as [$method, $uri, $payload]) {
            $this->mutationResponse($teacher, $method, $uri, $payload)
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertSame($snapshot, $this->questionDomainSnapshot($assessment));
        }
    }

    public function test_malformed_missing_and_wrong_resource_uuid_probes_share_private_not_found_responses(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        [$first, $second] = $this->integrityQuestions($assessment);
        $snapshot = $this->questionDomainSnapshot($assessment);
        $expectedError = null;

        foreach ([
            ['not-a-uuid', 'not-a-uuid'],
            ['00000000-0000-0000-0000-000000000099', '00000000-0000-0000-0000-000000000098'],
            [$first->id, $assessment->id],
        ] as [$assessmentId, $questionId]) {
            foreach ($this->mutationRoutes($assessmentId, $questionId, $second->id) as [$method, $uri, $payload]) {
                // Reorder body UUIDs stay valid so this specifically tests private route resolution.
                if (str_ends_with($uri, '/reorder')) {
                    $payload = ['question_ids' => [$second->id, $first->id]];
                }
                $response = $this->mutationResponse($teacher, $method, $uri, $payload)
                    ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
                $expectedError ??= $response->json();
                $this->assertSame($expectedError, $response->json());
                $this->assertSame($snapshot, $this->questionDomainSnapshot($assessment));
            }
        }
    }

    #[DataProvider('assessmentTypes')]
    public function test_required_type_specific_detail_row_must_exist_for_every_shared_route(AssessmentType $type): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = Assessment::factory()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
            'type' => $type,
        ]);
        [$first, $second] = $this->integrityQuestions($assessment);
        $snapshot = $this->questionDomainSnapshot($assessment);

        foreach ($this->mutationRoutes($assessment->id, $first->id, $second->id) as [$method, $uri, $payload]) {
            $this->mutationResponse($teacher, $method, $uri, $payload)
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
            $this->assertSame($snapshot, $this->questionDomainSnapshot($assessment));
        }
    }

    /** @return iterable<string, array{AssessmentType}> */
    public static function assessmentTypes(): iterable
    {
        yield 'Homework' => [AssessmentType::Homework];
        yield 'Blitz' => [AssessmentType::Blitz];
    }

    public function test_shared_routes_preserve_type_specific_parent_projection_with_both_types_in_one_topic(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $blitz = $this->persistedBlitz($institution, $teacher, $topic);

        $this->assertAllMutationsSucceed($teacher, $homework);
        $homeworkSnapshot = $homework->fresh()->getRawOriginal();
        $homeworkQuestions = $homework->questions()->orderBy('position')->get()->toArray();
        $this->assertAllMutationsSucceed($teacher, $blitz);

        $this->assertSame($homeworkSnapshot, $homework->fresh()->getRawOriginal());
        $this->assertSame($homeworkQuestions, $homework->questions()->orderBy('position')->get()->toArray());
    }

    /** @return array{Question, Question} */
    private function integrityQuestions(Assessment $assessment): array
    {
        $first = $this->persistedQuestion($assessment, [
            'type' => 'fill_in_blank',
            'prompt' => 'Name {{host}}.',
            'configuration' => ['blanks' => [
                ['key' => 'host', 'position' => 1, 'accepted_answers' => ['DNS', 'Domain Name System']],
            ]],
        ]);
        $second = $this->persistedQuestion($assessment, ['position' => 2]);
        $this->synchronizeQuestionTotal($assessment);

        return [$first, $second];
    }

    /** @return list<array{string, string, ?array<string, mixed>}> */
    private function mutationRoutes(string $assessmentId, string $questionId, string $secondQuestionId): array
    {
        return [
            ['POST', "/api/v1/teacher/assessments/{$assessmentId}/questions", $this->questionPayload(['position' => 2])],
            ['PATCH', "/api/v1/teacher/questions/{$questionId}", [
                'prompt' => 'Updated {{host}}.',
                'points' => 2,
                'configuration' => ['blanks' => [
                    ['key' => 'host', 'position' => 1, 'accepted_answers' => ['Updated answer']],
                ]],
            ]],
            ['DELETE', "/api/v1/teacher/questions/{$questionId}", null],
            ['POST', "/api/v1/teacher/assessments/{$assessmentId}/questions/reorder", ['question_ids' => [$secondQuestionId, $questionId]]],
        ];
    }

    private function mutationResponse(User $actor, string $method, string $uri, ?array $payload): TestResponse
    {
        return $payload === null
            ? $this->blitzRaw($actor, $method, $uri)
            : $this->blitzJson($actor, $method, $uri, $payload);
    }

    private function assertAllMutationsSucceed(User $teacher, Assessment $assessment, ?TopicResultPair $pair = null): void
    {
        [$first, $second] = $this->integrityQuestions($assessment);
        $isBlitz = $assessment->type === AssessmentType::Blitz;
        $task = $isBlitz ? $assessment->blitzTask : $assessment->homeworkAssignment;
        $taskSnapshot = $task->getRawOriginal();
        $pairSnapshot = $pair?->fresh()->getRawOriginal();
        $this->travel(5)->minutes();

        foreach (['add', 'update', 'reorder', 'delete'] as $operation) {
            $response = match ($operation) {
                'add' => $this->blitzJson($teacher, 'POST', "/api/v1/teacher/assessments/{$assessment->id}/questions", $this->questionPayload(['position' => 3])),
                'update' => $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$first->id}", [
                    'prompt' => 'Updated {{host}}.',
                    'points' => 2,
                    'configuration' => ['blanks' => [
                        ['key' => 'host', 'position' => 1, 'accepted_answers' => ['Updated answer']],
                    ]],
                ]),
                'reorder' => $this->blitzJson($teacher, 'POST', "/api/v1/teacher/assessments/{$assessment->id}/questions/reorder", [
                    'question_ids' => $assessment->questions()->orderByDesc('position')->pluck('id')->all(),
                ]),
                'delete' => $this->blitzRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$second->id}"),
            };
            $response->assertStatus($operation === 'add' ? 201 : 200)
                ->assertJsonPath('data.id', $assessment->id)
                ->assertJsonPath('data.status', $task->status->value)
                ->assertJsonPath('data.attempt_policy.normal_attempts', $isBlitz ? 1 : 3);
            $this->assertArrayHasKey($isBlitz ? 'duration_seconds' : 'deadline_at', $response->json('data'));
            $this->assertArrayNotHasKey($isBlitz ? 'deadline_at' : 'duration_seconds', $response->json('data'));
            $this->assertSame($taskSnapshot, $task->fresh()->getRawOriginal());
            if ($pair !== null) {
                $this->assertSame($pairSnapshot, $pair->fresh()->getRawOriginal());
            }
        }
    }

    /** @return array<string, mixed> */
    private function questionDomainSnapshot(Assessment $assessment): array
    {
        $snapshot = ['assessment' => $assessment->fresh()->getRawOriginal()];
        foreach ([
            'questions',
            'question_choice_options',
            'question_true_false_answers',
            'question_short_accepted_answers',
            'question_matching_items',
            'question_ordering_items',
            'question_fill_blanks',
            'question_fill_blank_accepted_answers',
            'homework_assignments',
            'blitz_tasks',
            'topic_result_pairs',
            'assessment_students',
            'assessment_attempts',
        ] as $table) {
            $key = match ($table) {
                'question_true_false_answers' => 'question_id',
                'homework_assignments', 'blitz_tasks' => 'assessment_id',
                default => 'id',
            };
            $snapshot[$table] = DB::table($table)->where('institution_id', $assessment->institution_id)
                ->orderBy($key)->get()->map(fn (object $row): array => (array) $row)->all();
        }

        return $snapshot;
    }
}
