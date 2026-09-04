<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentType;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Tests\Feature\Teacher\Concerns\BuildsTeacherTopicResultPairContext;
use Tests\TestCase;

class TeacherTopicResultPairApiTest extends TestCase
{
    use BuildsTeacherTopicResultPairContext;
    use RefreshDatabase;

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    public function test_exact_result_pair_routes_are_registered_once_with_teacher_middleware(): void
    {
        $routes = collect(Route::getRoutes())
            ->map(fn ($route): array => [
                'methods' => array_values(array_diff($route->methods(), ['HEAD'])),
                'uri' => $route->uri(),
                'middleware' => $route->middleware(),
            ])
            ->filter(fn (array $route): bool => $route['uri'] === 'api/v1/teacher/topics/{topic}/result-pair')
            ->values()
            ->all();
        $middleware = ['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:teacher'];

        $this->assertSame([
            ['methods' => ['GET'], 'uri' => 'api/v1/teacher/topics/{topic}/result-pair', 'middleware' => $middleware],
            ['methods' => ['PUT'], 'uri' => 'api/v1/teacher/topics/{topic}/result-pair', 'middleware' => $middleware],
        ], $routes);
    }

    public function test_get_returns_null_or_the_exact_future_compatible_pair_resource_without_writes(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $uri = "/api/v1/teacher/topics/{$topic->id}/result-pair";

        $this->homeworkRaw($teacher, 'GET', $uri, '')
            ->assertOk()
            ->assertExactJson(['data' => null]);

        $homework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $blitz = Assessment::factory()->blitz()->groupAssignment()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);
        $designatedAt = CarbonImmutable::parse('2026-09-03 09:00:00 UTC');
        $cohortAt = $designatedAt->addMinute();
        $lockedAt = $cohortAt->addMinute();
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
            'blitz_assessment_id' => $blitz->id,
            'designated_at' => $designatedAt,
            'cohort_snapshotted_at' => $cohortAt,
            'locked_at' => $lockedAt,
            'created_at' => $designatedAt,
            'updated_at' => $lockedAt,
        ]);
        $timestamps = [$pair->created_at->toJSON(), $pair->updated_at->toJSON()];

        $response = $this->homeworkRaw($teacher, 'GET', $uri, '');

        $response->assertOk()->assertExactJson(['data' => [
            'id' => $pair->id,
            'topic_id' => $topic->id,
            'homework_assessment_id' => $homework->id,
            'blitz_assessment_id' => $blitz->id,
            'cohort_snapshotted_at' => '2026-09-03T09:01:00Z',
            'locked_at' => '2026-09-03T09:02:00Z',
            'designated_at' => '2026-09-03T09:00:00Z',
            'created_at' => '2026-09-03T09:00:00Z',
            'updated_at' => '2026-09-03T09:02:00Z',
        ]]);
        $this->assertSame($timestamps, [
            $pair->fresh()?->created_at->toJSON(),
            $pair->fresh()?->updated_at->toJSON(),
        ]);
        $response->assertJsonMissingPath('data.institution_id')
            ->assertJsonMissingPath('data.designated_by_user_id');
    }

    public function test_put_designates_a_draft_group_homework_as_one_partial_pair_without_side_effects(): void
    {
        CarbonImmutable::setTestNow('2026-09-03 10:00:00 UTC');
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);

        $response = $this->putPair($teacher, $topic, $homework);

        $response->assertOk()
            ->assertJsonPath('message', 'Topic result pair updated successfully.')
            ->assertJsonPath('data.topic_id', $topic->id)
            ->assertJsonPath('data.homework_assessment_id', $homework->id)
            ->assertJsonPath('data.blitz_assessment_id', null)
            ->assertJsonPath('data.cohort_snapshotted_at', null)
            ->assertJsonPath('data.locked_at', null)
            ->assertJsonPath('data.designated_at', '2026-09-03T10:00:00Z')
            ->assertJsonPath('data.created_at', '2026-09-03T10:00:00Z')
            ->assertJsonPath('data.updated_at', '2026-09-03T10:00:00Z');
        $this->assertDatabaseHas('topic_result_pairs', [
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'homework_assessment_id' => $homework->id,
            'blitz_assessment_id' => null,
            'designated_by_user_id' => $teacher->id,
            'cohort_snapshotted_at' => null,
            'locked_at' => null,
        ]);
        $this->assertDatabaseCount('topic_result_pairs', 1);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertSame(0, Assessment::query()->where('type', AssessmentType::Blitz->value)->count());
        $this->assertSame(HomeworkStatus::Draft, $homework->homeworkAssignment()->firstOrFail()->status);
    }

    public function test_get_returns_draft_active_and_locked_partial_pair_resources(): void
    {
        CarbonImmutable::setTestNow('2026-09-03 10:30:00 UTC');
        [$draftInstitution, $draftTeacher, , , $draftTopic] = $this->homeworkContext();
        $draftHomework = $this->persistedHomework($draftInstitution, $draftTeacher, $draftTopic);
        $draftPair = $this->resultPair($draftInstitution, $draftTeacher, $draftTopic, $draftHomework);

        $this->homeworkRaw(
            $draftTeacher,
            'GET',
            "/api/v1/teacher/topics/{$draftTopic->id}/result-pair",
            '',
        )->assertOk()
            ->assertJsonPath('data.id', $draftPair->id)
            ->assertJsonPath('data.homework_assessment_id', $draftHomework->id)
            ->assertJsonPath('data.blitz_assessment_id', null)
            ->assertJsonPath('data.cohort_snapshotted_at', null)
            ->assertJsonPath('data.locked_at', null);

        [$activeInstitution, $activeTeacher, , , $activeTopic] = $this->homeworkContext(TopicStatus::Active);
        $activeHomework = $this->persistedHomework(
            $activeInstitution,
            $activeTeacher,
            $activeTopic,
            status: HomeworkStatus::Active,
        );
        $cohortAt = CarbonImmutable::parse('2026-09-03 10:35:00 UTC');
        $activePair = $this->resultPair($activeInstitution, $activeTeacher, $activeTopic, $activeHomework, [
            'cohort_snapshotted_at' => $cohortAt,
        ]);

        $this->homeworkRaw(
            $activeTeacher,
            'GET',
            "/api/v1/teacher/topics/{$activeTopic->id}/result-pair",
            '',
        )->assertOk()
            ->assertJsonPath('data.id', $activePair->id)
            ->assertJsonPath('data.homework_assessment_id', $activeHomework->id)
            ->assertJsonPath('data.blitz_assessment_id', null)
            ->assertJsonPath('data.cohort_snapshotted_at', '2026-09-03T10:35:00Z')
            ->assertJsonPath('data.locked_at', null);

        [$lockedInstitution, $lockedTeacher, , , $lockedTopic] = $this->homeworkContext(TopicStatus::Active);
        $lockedHomework = $this->persistedHomework(
            $lockedInstitution,
            $lockedTeacher,
            $lockedTopic,
            status: HomeworkStatus::Active,
        );
        $lockedAt = CarbonImmutable::parse('2026-09-03 10:40:00 UTC');
        $lockedPair = $this->resultPair($lockedInstitution, $lockedTeacher, $lockedTopic, $lockedHomework, [
            'cohort_snapshotted_at' => $cohortAt,
            'locked_at' => $lockedAt,
        ]);

        $this->homeworkRaw(
            $lockedTeacher,
            'GET',
            "/api/v1/teacher/topics/{$lockedTopic->id}/result-pair",
            '',
        )->assertOk()
            ->assertJsonPath('data.id', $lockedPair->id)
            ->assertJsonPath('data.homework_assessment_id', $lockedHomework->id)
            ->assertJsonPath('data.blitz_assessment_id', null)
            ->assertJsonPath('data.cohort_snapshotted_at', '2026-09-03T10:35:00Z')
            ->assertJsonPath('data.locked_at', '2026-09-03T10:40:00Z');
    }

    public function test_put_adopts_an_active_homework_persisted_group_snapshot_without_resnapshotting_membership(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $snapshottedStudent = $this->eligibleStudent($institution, $admin, $group);
        $homework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $assignedAt = CarbonImmutable::parse('2026-09-03 08:00:00 UTC');
        $recipient = $this->groupRecipient($institution, $teacher, $homework, $snapshottedStudent, $assignedAt);
        $laterMember = $this->eligibleStudent($institution, $admin, $group);
        $before = [$recipient->id, $recipient->assigned_at->toJSON(), $recipient->updated_at->toJSON()];

        CarbonImmutable::setTestNow('2026-09-03 11:00:00 UTC');
        $this->putPair($teacher, $topic, $homework)
            ->assertOk()
            ->assertJsonPath('data.cohort_snapshotted_at', '2026-09-03T11:00:00Z');

        $recipients = AssessmentStudent::query()->where('assessment_id', $homework->id)->get();
        $this->assertCount(1, $recipients);
        $this->assertSame($snapshottedStudent->id, $recipients->sole()->student_id);
        $this->assertNotSame($laterMember->id, $recipients->sole()->student_id);
        $this->assertSame($before, [
            $recipients->sole()->id,
            $recipients->sole()->assigned_at->toJSON(),
            $recipients->sole()->updated_at->toJSON(),
        ]);
    }

    public function test_active_and_draft_candidates_require_structurally_valid_persisted_recipient_state(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $missing = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $this->putPair($teacher, $topic, $missing)
            ->assertConflict()->assertJsonPath('code', 'business_conflict');

        $direct = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $student = $this->eligibleStudent($institution, $admin, $group);
        AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $direct->id,
            'student_id' => $student->id,
            'assignment_source' => AssessmentAssignmentSource::Direct,
            'assigned_by_user_id' => $teacher->id,
        ]);
        $this->putPair($teacher, $topic, $direct)
            ->assertConflict()->assertJsonPath('code', 'business_conflict');

        $draft = $this->persistedHomework($institution, $teacher, $topic);
        $this->groupRecipient($institution, $teacher, $draft, $student);
        $this->putPair($teacher, $topic, $draft)
            ->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    public function test_put_enforces_whole_group_lifecycle_activity_and_candidate_scope_rules(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $selected = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            mode: AssessmentAssignmentMode::SelectedStudents,
        );
        $this->putPair($teacher, $topic, $selected)
            ->assertConflict()
            ->assertJsonPath('code', 'official_task_requires_group_assignment')
            ->assertJsonPath('message', 'The official task requires whole-group assignment.');

        foreach ([HomeworkStatus::Closed, HomeworkStatus::Archived] as $status) {
            $ineligible = $this->persistedHomework($institution, $teacher, $topic, status: $status);
            $this->putPair($teacher, $topic, $ineligible)
                ->assertConflict()->assertJsonPath('code', 'business_conflict');
        }

        $used = $this->persistedHomework($institution, $teacher, $topic);
        $student = $this->eligibleStudent($institution, $admin, $group);
        $this->attemptFor($this->groupRecipient($institution, $teacher, $used, $student));
        $this->putPair($teacher, $topic, $used)
            ->assertConflict()->assertJsonPath('code', 'result_pair_locked');

        $otherTopic = Topic::factory()->create([
            'institution_id' => $institution->id,
            'group_id' => $group->id,
            'teacher_id' => $teacher->id,
        ]);
        $otherTopicHomework = $this->persistedHomework($institution, $teacher, $otherTopic);
        $otherTeacher = User::factory()->teacher($institution)->create(['must_change_password' => false]);
        $otherTeacherHomework = $this->persistedHomework($institution, $otherTeacher, $topic);
        $blitz = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);
        [$foreignInstitution, $foreignTeacher, , , $foreignTopic] = $this->homeworkContext();
        $foreignHomework = $this->persistedHomework($foreignInstitution, $foreignTeacher, $foreignTopic);

        foreach ([$otherTopicHomework, $otherTeacherHomework, $blitz, $foreignHomework] as $inaccessible) {
            $this->putPair($teacher, $topic, $inaccessible)
                ->assertNotFound()->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    public function test_replacement_adopts_or_clears_cohort_and_preserves_old_recipient_history(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
        $studentA = $this->eligibleStudent($institution, $admin, $group);
        $studentB = $this->eligibleStudent($institution, $admin, $group);
        $activeA = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $oldRecipient = $this->groupRecipient($institution, $teacher, $activeA, $studentA);
        $draft = $this->persistedHomework($institution, $teacher, $topic);
        $activeB = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
        $newRecipient = $this->groupRecipient($institution, $teacher, $activeB, $studentB);

        CarbonImmutable::setTestNow('2026-09-03 12:00:00 UTC');
        $this->putPair($teacher, $topic, $activeA)->assertOk();
        $pair = TopicResultPair::query()->where('topic_id', $topic->id)->firstOrFail();
        $pairId = $pair->id;
        $createdAt = $pair->created_at->toJSON();

        CarbonImmutable::setTestNow('2026-09-03 12:05:00 UTC');
        $this->putPair($teacher, $topic, $draft)
            ->assertOk()
            ->assertJsonPath('data.homework_assessment_id', $draft->id)
            ->assertJsonPath('data.cohort_snapshotted_at', null)
            ->assertJsonPath('data.designated_at', '2026-09-03T12:05:00Z');

        CarbonImmutable::setTestNow('2026-09-03 12:10:00 UTC');
        $this->putPair($teacher, $topic, $activeB)
            ->assertOk()
            ->assertJsonPath('data.id', $pairId)
            ->assertJsonPath('data.cohort_snapshotted_at', '2026-09-03T12:10:00Z')
            ->assertJsonPath('data.updated_at', '2026-09-03T12:10:00Z');

        $pair->refresh();
        $this->assertSame($createdAt, $pair->created_at->toJSON());
        $this->assertSame($teacher->id, $pair->designated_by_user_id);
        $this->assertDatabaseHas('assessment_students', ['id' => $oldRecipient->id, 'assessment_id' => $activeA->id]);
        $this->assertDatabaseHas('assessment_students', ['id' => $newRecipient->id, 'assessment_id' => $activeB->id]);
        $this->assertDatabaseCount('topic_result_pairs', 1);
    }

    public function test_replacement_is_blocked_by_pair_state_or_activity_on_either_homework(): void
    {
        foreach (['locked', 'blitz', 'current_attempt', 'candidate_attempt'] as $scenario) {
            [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext(TopicStatus::Active);
            $student = $this->eligibleStudent($institution, $admin, $group);
            $current = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Active);
            $candidate = $this->persistedHomework($institution, $teacher, $topic);
            $currentRecipient = $this->groupRecipient($institution, $teacher, $current, $student);
            $pairAttributes = [
                'designated_at' => now()->subMinutes(2),
                'cohort_snapshotted_at' => now()->subMinute(),
            ];

            if ($scenario === 'locked') {
                $pairAttributes['locked_at'] = now();
            }

            if ($scenario === 'blitz') {
                $pairAttributes['blitz_assessment_id'] = Assessment::factory()->blitz()->create([
                    'institution_id' => $institution->id,
                    'teacher_id' => $teacher->id,
                    'topic_id' => $topic->id,
                ])->id;
            }

            if ($scenario === 'current_attempt') {
                $this->attemptFor($currentRecipient);
            }

            if ($scenario === 'candidate_attempt') {
                $this->attemptFor($this->groupRecipient($institution, $teacher, $candidate, $student));
            }

            $pair = $this->resultPair($institution, $teacher, $topic, $current, $pairAttributes);
            $before = $this->pairState($pair);

            $this->putPair($teacher, $topic, $candidate)
                ->assertConflict()->assertJsonPath('code', 'result_pair_locked');
            $this->assertSame($before, $this->pairState($pair->fresh()));
        }
    }

    public function test_same_target_put_is_a_true_no_op_after_close_archive_lock_and_future_blitz_completion(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
        $homework = $this->persistedHomework($institution, $teacher, $topic, status: HomeworkStatus::Archived);
        $blitz = Assessment::factory()->blitz()->create([
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
        ]);
        $pair = $this->resultPair($institution, $teacher, $topic, $homework, [
            'blitz_assessment_id' => $blitz->id,
            'designated_at' => now()->subMinutes(3),
            'cohort_snapshotted_at' => now()->subMinutes(2),
            'locked_at' => now()->subMinute(),
        ]);
        $before = $this->pairState($pair);

        CarbonImmutable::setTestNow(now()->addHour());
        $this->putPair($teacher, $topic, $homework)
            ->assertOk()
            ->assertJsonPath('data.homework_assessment_id', $homework->id)
            ->assertJsonPath('data.blitz_assessment_id', $blitz->id);

        $this->assertSame($before, $this->pairState($pair->fresh()));

        [$closedInstitution, $closedTeacher, , , $closedTopic] = $this->homeworkContext(TopicStatus::Active);
        $closedHomework = $this->persistedHomework(
            $closedInstitution,
            $closedTeacher,
            $closedTopic,
            status: HomeworkStatus::Closed,
        );
        $closedPair = $this->resultPair($closedInstitution, $closedTeacher, $closedTopic, $closedHomework, [
            'designated_at' => now()->subMinutes(2),
            'cohort_snapshotted_at' => now()->subMinute(),
        ]);
        $closedBefore = $this->pairState($closedPair);

        CarbonImmutable::setTestNow(now()->addHour());
        $this->putPair($closedTeacher, $closedTopic, $closedHomework)
            ->assertOk()
            ->assertJsonPath('data.homework_assessment_id', $closedHomework->id)
            ->assertJsonPath('data.blitz_assessment_id', null);

        $this->assertSame($closedBefore, $this->pairState($closedPair->fresh()));
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('topic_result_pairs', 2);
    }

    public function test_get_and_put_reject_all_disallowed_request_shapes(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $uri = "/api/v1/teacher/topics/{$topic->id}/result-pair";

        $this->homeworkRaw($teacher, 'GET', $uri, '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkRaw($teacher, 'GET', $uri, '', ['unexpected' => '1'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        foreach ([
            '',
            'null',
            '[]',
            '"scalar"',
            '{',
            '{}',
            '{"homework_assessment_id":null}',
            '{"homework_assessment_id":"not-a-uuid"}',
            json_encode(['homework_assessment_id' => $homework->id, 'blitz_assessment_id' => null], JSON_THROW_ON_ERROR),
            json_encode(['homework_assessment_id' => $homework->id, 'institution_id' => $institution->id], JSON_THROW_ON_ERROR),
        ] as $content) {
            $this->homeworkRaw($teacher, 'PUT', $uri, $content)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->homeworkRaw(
            $teacher,
            'PUT',
            $uri,
            json_encode(['homework_assessment_id' => $homework->id], JSON_THROW_ON_ERROR),
            ['unexpected' => '1'],
        )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $nonJsonResponse = $this->call('PUT', $uri, [], [], [], [
            'CONTENT_TYPE' => 'text/plain',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('teacher-result-pair-api-test')->plainTextToken,
        ], json_encode(['homework_assessment_id' => $homework->id], JSON_THROW_ON_ERROR));
        $this->app['auth']->forgetGuards();
        $nonJsonResponse->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $this->homeworkRaw(
            $teacher,
            'PUT',
            $uri,
            json_encode([
                'homework_assessment_id' => $homework->id,
                'arbitrary_unknown_field' => true,
            ], JSON_THROW_ON_ERROR),
        )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseCount('topic_result_pairs', 0);
    }

    private function putPair(User $teacher, Topic $topic, Assessment $homework): TestResponse
    {
        return $this->homeworkJson(
            $teacher,
            'PUT',
            "/api/v1/teacher/topics/{$topic->id}/result-pair",
            ['homework_assessment_id' => $homework->id],
        );
    }

    /** @return array<string, mixed> */
    private function pairState(?TopicResultPair $pair): array
    {
        $this->assertInstanceOf(TopicResultPair::class, $pair);

        return [
            'id' => $pair->id,
            'institution_id' => $pair->institution_id,
            'topic_id' => $pair->topic_id,
            'homework_assessment_id' => $pair->homework_assessment_id,
            'blitz_assessment_id' => $pair->blitz_assessment_id,
            'designated_by_user_id' => $pair->designated_by_user_id,
            'designated_at' => $pair->designated_at->toJSON(),
            'cohort_snapshotted_at' => $pair->cohort_snapshotted_at?->toJSON(),
            'locked_at' => $pair->locked_at?->toJSON(),
            'created_at' => $pair->created_at->toJSON(),
            'updated_at' => $pair->updated_at->toJSON(),
        ];
    }
}
