<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\BlitzStatus;
use App\Models\AssessmentStudent;
use App\Models\BlitzTask;
use App\Models\Group;
use App\Models\GroupTeacherMembership;
use App\Models\Question;
use App\Models\Topic;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use stdClass;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\TestCase;

class TeacherBlitzAuthoringApiTest extends TestCase
{
    use BuildsTeacherBlitzContext;
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

    public function test_group_create_returns_the_exact_server_owned_draft_resource_without_recipients(): void
    {
        [$institution, $teacher, , $group, $topic] = $this->blitzContext();
        $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload([
            'title' => '  Blitz 1  ',
            'student_instructions' => '  Answer independently.  ',
            'duration_seconds' => 9001,
        ]));

        $response->assertCreated()
            ->assertJsonPath('message', 'Blitz task created successfully.')
            ->assertJsonPath('data.title', 'Blitz 1')
            ->assertJsonPath('data.student_instructions', 'Answer independently.')
            ->assertJsonPath('data.topic_id', $topic->id)
            ->assertJsonPath('data.group_id', $group->id)
            ->assertJsonPath('data.description', null)
            ->assertJsonPath('data.assignment_mode', 'group')
            ->assertJsonPath('data.student_ids', [])
            ->assertJsonPath('data.questions', [])
            ->assertJsonPath('data.total_possible_points', 0)
            ->assertJsonPath('data.duration_seconds', 9001)
            ->assertJsonPath('data.scheduled_at', null)
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.institution_timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.attempt_policy', ['normal_attempts' => 1, 'max_additional_exception_attempts' => 1]);
        $this->assertSame([
            'id', 'topic_id', 'group_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'duration_seconds', 'scheduled_at', 'institution_timezone',
            'status', 'timer_start_mode_snapshot', 'attempt_policy', 'activated_at', 'synchronized_ends_at',
            'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $this->assertDatabaseHas('assessments', [
            'id' => $response->json('data.id'), 'institution_id' => $institution->id,
            'teacher_id' => $teacher->id, 'topic_id' => $topic->id, 'type' => 'blitz',
            'total_possible_points' => '0.000000',
        ]);
        $this->assertDatabaseHas('blitz_tasks', [
            'assessment_id' => $response->json('data.id'), 'institution_id' => $institution->id,
            'status' => 'draft', 'duration_seconds' => 9001, 'scheduled_at' => null,
            'timer_start_mode_snapshot' => null, 'activated_at' => null, 'synchronized_ends_at' => null,
            'closed_at' => null, 'archived_at' => null, 'activated_by_user_id' => null,
        ]);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('assessment_attempts', 0);
        foreach (['institution_id', 'teacher_id', 'activated_by_user_id', 'assigned_by_user_id'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz/'.$response->json('data.id'))
            ->assertOk()->assertJsonPath('data', $response->json('data'));
    }

    public function test_create_can_prepare_a_future_schedule_without_scheduling_or_snapshotting_timer_mode(): void
    {
        [, $teacher, , , $topic] = $this->blitzContext();
        $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload([
            'scheduled_at' => '2026-09-17T14:00:00+05:00',
        ]))->assertCreated()
            ->assertJsonPath('data.scheduled_at', '2026-09-17T09:00:00Z')
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.timer_start_mode_snapshot', null);

        foreach (['2026-09-16T13:00:00+05:00', '2026-09-16T12:59:59+05:00', '2026-09-17T14:00:00+04:00', 'invalid', 123] as $invalid) {
            $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload([
                'scheduled_at' => $invalid,
            ]))->assertUnprocessable()->assertJsonPath('code', 'validation_failed')->assertJsonStructure(['errors' => ['scheduled_at']]);
        }
        $this->assertDatabaseCount('assessments', 1);
    }

    #[DataProvider('preparedScheduleInstants')]
    public function test_prepared_schedule_persists_the_exact_instant_and_uses_canonical_utc_in_create_detail_and_list(
        string $scheduledAt,
        string $expectedUtc,
    ): void {
        [, $teacher, , , $topic] = $this->blitzContext();
        $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload([
            'scheduled_at' => $scheduledAt,
        ]))->assertCreated()
            ->assertJsonPath('data.scheduled_at', $expectedUtc)
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.timer_start_mode_snapshot', null);
        $blitzId = $response->json('data.id');
        $reloadedBlitz = BlitzTask::query()->whereKey($blitzId)->firstOrFail();

        $this->assertTrue($reloadedBlitz->scheduled_at->equalTo(CarbonImmutable::parse($scheduledAt)));
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz/'.$blitzId)
            ->assertOk()->assertJsonPath('data.scheduled_at', $expectedUtc);
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz')
            ->assertOk()->assertJsonPath('data.0.id', $blitzId)->assertJsonPath('data.0.scheduled_at', $expectedUtc);
    }

    public static function preparedScheduleInstants(): array
    {
        return [
            'whole second' => ['2026-09-17T10:00:00+05:00', '2026-09-17T05:00:00Z'],
            'explicit zero microseconds' => ['2026-09-17T10:00:00.000000+05:00', '2026-09-17T05:00:00Z'],
            'one fractional digit' => ['2026-09-17T10:00:00.2+05:00', '2026-09-17T05:00:00.200000Z'],
            'two fractional digits' => ['2026-09-17T10:00:00.25+05:00', '2026-09-17T05:00:00.250000Z'],
            'three fractional digits' => ['2026-09-17T10:00:00.251+05:00', '2026-09-17T05:00:00.251000Z'],
            'four fractional digits' => ['2026-09-17T10:00:00.2512+05:00', '2026-09-17T05:00:00.251200Z'],
            'five fractional digits' => ['2026-09-17T10:00:00.25123+05:00', '2026-09-17T05:00:00.251230Z'],
            'six fractional digits' => ['2026-09-17T10:00:00.251234+05:00', '2026-09-17T05:00:00.251234Z'],
            'one microsecond' => ['2026-09-17T10:00:00.000001+05:00', '2026-09-17T05:00:00.000001Z'],
        ];
    }

    public function test_selected_create_persists_exact_direct_recipients_and_detail_sorts_student_ids(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $first = $this->eligibleBlitzStudent($institution, $admin, $group);
        $second = $this->eligibleBlitzStudent($institution, $admin, $group);
        $ids = [$first->id, $second->id];
        sort($ids, SORT_STRING);
        $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload([
            'assignment_mode' => 'selected_students', 'student_ids' => array_reverse($ids),
        ]))->assertCreated()->assertJsonPath('data.student_ids', $ids);
        foreach ($ids as $id) {
            $this->assertDatabaseHas('assessment_students', [
                'assessment_id' => $response->json('data.id'), 'institution_id' => $institution->id,
                'student_id' => $id, 'assignment_source' => 'direct', 'assigned_by_user_id' => $teacher->id,
            ]);
        }
        $this->assertDatabaseCount('assessment_students', 2);
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz/'.$response->json('data.id'))
            ->assertOk()->assertJsonPath('data.student_ids', $ids);
    }

    public function test_group_detail_does_not_expose_future_group_recipient_snapshot_as_selected_students(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Active);
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        AssessmentStudent::factory()->create([
            'institution_id' => $institution->id, 'assessment_id' => $assessment->id,
            'student_id' => $student->id, 'assignment_source' => 'group', 'assigned_by_user_id' => $teacher->id,
        ]);
        $this->blitzRaw($teacher, 'GET', "/api/v1/teacher/blitz/{$assessment->id}")
            ->assertOk()->assertJsonPath('data.student_ids', [])->assertJsonMissing(['student_id' => $student->id]);
    }

    public function test_nested_create_reuses_all_nine_question_configurations_and_derives_points(): void
    {
        [, $teacher, , , $topic] = $this->blitzContext();
        $questions = $this->allBlitzQuestions();
        $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload([
            'questions' => $questions,
        ]))->assertCreated()->assertJsonPath('data.total_possible_points', 0.9)->assertJsonCount(9, 'data.questions');
        $this->assertSame(array_column($questions, 'type'), array_column($response->json('data.questions'), 'type'));
        $this->assertSame(['pdf', 'docx', 'ppt', 'pptx'], $response->json('data.questions.5.configuration.allowed_extensions'));
        $this->assertTrue($response->json('data.questions.2.configuration.correct_value'));
        foreach ($response->json('data.questions') as $question) {
            $this->assertArrayNotHasKey('client_key', $question);
        }
        $this->assertDatabaseCount('questions', 9);
        $this->assertDatabaseCount('question_choice_options', 4);
        $this->assertDatabaseCount('question_true_false_answers', 1);
        $this->assertDatabaseCount('question_short_accepted_answers', 1);
        $this->assertDatabaseCount('question_matching_items', 2);
        $this->assertDatabaseCount('question_ordering_items', 2);
        $this->assertDatabaseCount('question_fill_blanks', 1);
        $this->assertDatabaseCount('question_fill_blank_accepted_answers', 1);
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz/'.$response->json('data.id'))
            ->assertOk()->assertJsonPath('data.questions', $response->json('data.questions'));
    }

    public function test_nested_question_failure_rolls_back_assessment_blitz_recipients_and_earlier_configuration(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $dispatcher = Question::getEventDispatcher();
        Question::setEventDispatcher(clone $dispatcher);
        Question::creating(function (Question $question): void {
            if ($question->position === 2) {
                throw new RuntimeException('Injected second Question persistence failure.');
            }
        });
        $this->withoutExceptionHandling();
        try {
            try {
                $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload([
                    'assignment_mode' => 'selected_students', 'student_ids' => [$student->id],
                    'questions' => array_slice($this->allBlitzQuestions(), 0, 2),
                ]));
                $this->fail('The injected persistence failure must escape.');
            } catch (RuntimeException $exception) {
                $this->assertSame('Injected second Question persistence failure.', $exception->getMessage());
            }
        } finally {
            Question::setEventDispatcher($dispatcher);
            $this->withExceptionHandling();
        }
        foreach (['assessments', 'blitz_tasks', 'assessment_students', 'questions', 'question_choice_options'] as $table) {
            $this->assertDatabaseCount($table, 0);
        }
    }

    public function test_create_rejects_invalid_required_values_and_assignment_shapes_without_a_duration_default(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $student = $this->eligibleBlitzStudent($institution, $admin, $group);
        $uri = "/api/v1/teacher/topics/{$topic->id}/blitz";
        foreach (array_keys($this->validBlitzPayload()) as $required) {
            $payload = $this->validBlitzPayload();
            unset($payload[$required]);
            $this->blitzJson($teacher, 'POST', $uri, $payload)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        foreach ([0, -1, 1.5, '600', true, null, 2147483648] as $duration) {
            $this->blitzJson($teacher, 'POST', $uri, $this->validBlitzPayload(['duration_seconds' => $duration]))
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        foreach ([
            ['title' => '  '], ['title' => str_repeat('a', 256)], ['description' => str_repeat('a', 10001)],
            ['student_instructions' => '  '], ['student_instructions' => str_repeat('a', 10001)],
            ['assignment_mode' => 'all'], ['assignment_mode' => 'selected_students'],
            ['student_ids' => [$student->id]], ['student_ids' => new stdClass],
            ['assignment_mode' => 'selected_students', 'student_ids' => [$student->id, strtoupper($student->id)]],
            ['assignment_mode' => 'selected_students', 'student_ids' => ['bad-id']],
        ] as $overrides) {
            $this->blitzJson($teacher, 'POST', $uri, $this->validBlitzPayload($overrides))
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->assertDatabaseCount('assessments', 0);
        foreach ([1, 2147483647] as $duration) {
            $this->blitzJson($teacher, 'POST', $uri, $this->validBlitzPayload(['duration_seconds' => $duration]))
                ->assertCreated()->assertJsonPath('data.duration_seconds', $duration);
        }
    }

    public function test_create_and_patch_enforce_json_objects_and_prohibit_queries_unknown_and_protected_fields(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        foreach ([['POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload()],
            ['PATCH', "/api/v1/teacher/blitz/{$assessment->id}", ['title' => 'Changed']]] as [$method, $uri, $valid]) {
            foreach (['', '{', '42', '[]', 'null', '{}'] as $body) {
                $this->blitzRaw($teacher, $method, $uri, $body)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            }
            $this->blitzRaw($teacher, $method, $uri, json_encode($valid), contentType: 'text/plain')
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            $this->blitzJson($teacher, $method, $uri, $valid, ['unknown' => 'x'])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            foreach ([
                'id', 'institution_id', 'teacher_id', 'topic_id', 'type', 'status', 'total_possible_points',
                'attempt_limit', 'normal_attempts', 'timer_start_mode', 'timer_start_mode_snapshot',
                'activated_at', 'synchronized_ends_at', 'closed_at', 'archived_at', 'activated_by_user_id',
                'created_at', 'updated_at', 'is_official', 'official_blitz_id', 'unexpected',
            ] as $field) {
                $this->blitzJson($teacher, $method, $uri, [...$valid, $field => 'forbidden'])
                    ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            }
        }
        foreach (['questions' => [], 'scheduled_at' => '2026-09-17T14:00:00+05:00'] as $field => $value) {
            $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/blitz/{$assessment->id}", [$field => $value])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->assertDatabaseCount('assessments', 1);
    }

    public function test_invalid_nested_questions_fail_atomically_including_unsupported_timer_and_position_or_key_collisions(): void
    {
        [, $teacher, , , $topic] = $this->blitzContext();
        $question = $this->allBlitzQuestions()[0];
        $invalidSets = [new stdClass, [[...$question, 'time_limit_seconds' => 30]],
            [[...$question, 'type' => 'unsupported']], [[...$question, 'checking_mode' => 'manual']],
            [[...$question, 'configuration' => ['options' => []]]], [[...$question, 'points' => -1]],
            [[...$question, 'position' => 2]], [$question, [...$question, 'position' => 2]],
            [$question, [...$question, 'client_key' => 'q2', 'position' => 3]],
        ];
        foreach ($invalidSets as $questions) {
            $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload(['questions' => $questions]))
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->assertDatabaseCount('assessments', 0);
        $this->assertDatabaseCount('questions', 0);
    }

    public function test_list_filters_paginates_and_orders_by_created_at_then_id_without_loading_question_configuration(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $old = $this->persistedBlitz($institution, $teacher, $topic, assessmentAttributes: ['created_at' => now()->subDay()]);
        $first = $this->persistedBlitz($institution, $teacher, $topic);
        $second = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Scheduled);
        Question::factory()->openWritten()->create(['institution_id' => $institution->id, 'assessment_id' => $second->id, 'position' => 1]);
        $ids = [$first->id, $second->id];
        rsort($ids, SORT_STRING);
        $response = $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz')->assertOk();
        $this->assertSame([...$ids, $old->id], array_column($response->json('data'), 'id'));
        $this->assertSame(['page' => 1, 'per_page' => 20, 'total' => 3, 'last_page' => 1], $response->json('meta.pagination'));
        $this->assertSame([
            'id', 'topic_id', 'group_id', 'title', 'assignment_mode', 'total_possible_points', 'question_count',
            'duration_seconds', 'scheduled_at', 'institution_timezone', 'status', 'created_at', 'updated_at',
        ], array_keys($response->json('data.0')));
        foreach ([['topic_id' => $topic->id], ['group_id' => $group->id], ['topic_id' => $topic->id, 'group_id' => $group->id]] as $query) {
            $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: $query)->assertOk()->assertJsonCount(3, 'data');
        }
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: ['status' => 'scheduled'])
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $second->id)->assertJsonPath('data.0.question_count', 1);
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: ['page' => 2, 'per_page' => 1])
            ->assertOk()->assertJsonPath('data.0.id', $ids[1])->assertJsonPath('meta.pagination', ['page' => 2, 'per_page' => 1, 'total' => 3, 'last_page' => 3]);
        $otherGroup = Group::factory()->create(['institution_id' => $institution->id, 'created_by_user_id' => $admin->id]);
        GroupTeacherMembership::factory()->create(['institution_id' => $institution->id, 'group_id' => $otherGroup->id, 'teacher_id' => $teacher->id, 'assigned_by_user_id' => $admin->id]);
        $otherTopic = Topic::factory()->create(['institution_id' => $institution->id, 'group_id' => $otherGroup->id, 'teacher_id' => $teacher->id]);
        $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: ['topic_id' => $otherTopic->id, 'group_id' => $group->id])
            ->assertOk()->assertJsonPath('data', [])->assertJsonPath('meta.pagination.total', 0);
    }

    public function test_list_and_detail_reject_unapproved_queries_and_any_request_body(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        foreach (['/api/v1/teacher/blitz', "/api/v1/teacher/blitz/{$assessment->id}"] as $uri) {
            foreach (['{}', '[]', 'null', '{"ignored":true}'] as $body) {
                $this->blitzRaw($teacher, 'GET', $uri, $body)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            }
            $this->blitzRaw($teacher, 'GET', $uri, query: ['unknown' => 'x'])->assertUnprocessable();
        }
        foreach ([['sort' => 'title'], ['assignment_mode' => 'group'], ['status' => 'invalid'], ['page' => 0], ['per_page' => 0], ['per_page' => 101]] as $query) {
            $this->blitzRaw($teacher, 'GET', '/api/v1/teacher/blitz', query: $query)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }
        $this->blitzRaw($teacher, 'GET', "/api/v1/teacher/blitz/{$assessment->id}", query: ['topic_id' => $topic->id])->assertUnprocessable();
    }

    public function test_draft_and_scheduled_metadata_duration_updates_preserve_questions_points_and_schedule(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        foreach ([BlitzStatus::Draft, BlitzStatus::Scheduled] as $status) {
            $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status, assessmentAttributes: ['total_possible_points' => '3.000000']);
            $question = Question::factory()->openWritten()->create(['institution_id' => $institution->id, 'assessment_id' => $assessment->id, 'position' => 1, 'points' => 3]);
            $beforeSchedule = $assessment->blitzTask->scheduled_at?->toJSON();
            $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/blitz/{$assessment->id}", [
                'title' => '  Revised title  ', 'description' => 'New description',
                'student_instructions' => '  Work independently.  ', 'duration_seconds' => 12000,
            ])->assertOk()->assertJsonPath('data.title', 'Revised title')->assertJsonPath('data.description', 'New description')
                ->assertJsonPath('data.student_instructions', 'Work independently.')->assertJsonPath('data.duration_seconds', 12000)
                ->assertJsonPath('data.status', $status->value)->assertJsonPath('data.total_possible_points', 3)
                ->assertJsonPath('data.questions.0.id', $question->id);
            $this->assertSame($beforeSchedule, $assessment->blitzTask->fresh()->scheduled_at?->toJSON());
        }
    }

    public function test_partial_assignment_updates_replace_the_exact_set_then_clear_it_for_group_mode(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $first = $this->eligibleBlitzStudent($institution, $admin, $group);
        $second = $this->eligibleBlitzStudent($institution, $admin, $group);
        $third = $this->eligibleBlitzStudent($institution, $admin, $group);
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $uri = "/api/v1/teacher/blitz/{$assessment->id}";
        foreach ([['assignment_mode' => 'selected_students'], ['student_ids' => [$first->id]]] as $invalid) {
            $this->blitzJson($teacher, 'PATCH', $uri, $invalid)->assertUnprocessable();
        }
        $this->blitzJson($teacher, 'PATCH', $uri, ['assignment_mode' => 'selected_students', 'student_ids' => [$first->id, $second->id]])->assertOk();
        $retained = AssessmentStudent::query()->where('assessment_id', $assessment->id)->where('student_id', $second->id)->firstOrFail();
        $this->blitzJson($teacher, 'PATCH', $uri, ['assignment_mode' => 'group'])->assertUnprocessable();
        $this->blitzJson($teacher, 'PATCH', $uri, ['student_ids' => []])->assertUnprocessable();
        $this->blitzJson($teacher, 'PATCH', $uri, ['student_ids' => [$second->id, $third->id]])->assertOk();
        $this->assertDatabaseMissing('assessment_students', ['assessment_id' => $assessment->id, 'student_id' => $first->id]);
        $this->assertDatabaseHas('assessment_students', ['id' => $retained->id, 'student_id' => $second->id, 'assignment_source' => 'direct']);
        $this->assertDatabaseHas('assessment_students', ['assessment_id' => $assessment->id, 'student_id' => $third->id, 'assignment_source' => 'direct']);
        $this->blitzJson($teacher, 'PATCH', $uri, ['assignment_mode' => 'group', 'student_ids' => []])->assertOk()->assertJsonPath('data.student_ids', []);
        $this->assertDatabaseMissing('assessment_students', ['assessment_id' => $assessment->id]);
    }

    public function test_semantic_no_op_preserves_parent_and_recipient_timestamps_and_rows(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        $students = [$this->eligibleBlitzStudent($institution, $admin, $group), $this->eligibleBlitzStudent($institution, $admin, $group)];
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, mode: AssessmentAssignmentMode::SelectedStudents);
        foreach ($students as $student) {
            $this->blitzRecipient($assessment, $student, $teacher);
        }
        $before = $assessment->fresh()->toArray();
        $blitzBefore = $assessment->blitzTask->fresh()->toArray();
        $recipientsBefore = AssessmentStudent::query()->where('assessment_id', $assessment->id)->orderBy('student_id')->get()->toArray();
        $this->travel(1)->hour();
        $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/blitz/{$assessment->id}", [
            'title' => '  '.$assessment->title.'  ', 'description' => $assessment->description,
            'student_instructions' => $assessment->student_instructions, 'duration_seconds' => $assessment->blitzTask->duration_seconds,
            'assignment_mode' => 'selected_students', 'student_ids' => array_reverse(array_column($recipientsBefore, 'student_id')),
        ])->assertOk();
        $this->assertSame($before, $assessment->fresh()->toArray());
        $this->assertSame($blitzBefore, $assessment->blitzTask->fresh()->toArray());
        $this->assertSame($recipientsBefore, AssessmentStudent::query()->where('assessment_id', $assessment->id)->orderBy('student_id')->get()->toArray());
    }

    public function test_update_rejects_incompatible_lifecycle_and_unexpected_attempts_without_reinterpreting_history(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
        foreach ([[BlitzStatus::Active, 'business_conflict'], [BlitzStatus::Closed, 'task_closed'], [BlitzStatus::Archived, 'task_archived']] as [$status, $code]) {
            $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
            $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/blitz/{$assessment->id}", ['title' => 'Forbidden'])
                ->assertConflict()->assertJsonPath('code', $code);
        }
        foreach ([BlitzStatus::Draft, BlitzStatus::Scheduled] as $status) {
            $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
            $student = $this->eligibleBlitzStudent($institution, $admin, $group);
            $attempt = $this->blitzAttempt($assessment, $student, $teacher);
            $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/blitz/{$assessment->id}", ['title' => 'Forbidden'])
                ->assertConflict()->assertJsonPath('code', 'business_conflict');
            $this->assertDatabaseHas('assessment_attempts', ['id' => $attempt->id, 'status' => 'in_progress']);
        }
    }

    public function test_official_blitz_remains_group_assigned_even_when_pair_locked_but_safe_metadata_stays_editable(): void
    {
        foreach ([false, true] as $locked) {
            [$institution, $teacher, $admin, $group, $topic] = $this->blitzContext();
            $student = $this->eligibleBlitzStudent($institution, $admin, $group);
            $assessment = $this->persistedBlitz($institution, $teacher, $topic);
            $pair = $this->officialBlitzPair($assessment, $teacher, $locked);
            $pairBefore = $pair->fresh()->toArray();
            $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/blitz/{$assessment->id}", [
                'assignment_mode' => 'selected_students', 'student_ids' => [$student->id],
            ])->assertConflict()->assertJsonPath('code', 'official_task_requires_group_assignment');
            $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/blitz/{$assessment->id}", ['title' => 'Safe edit', 'duration_seconds' => 720])
                ->assertOk()->assertJsonPath('data.title', 'Safe edit')->assertJsonPath('data.assignment_mode', 'group');
            $this->assertSame($pairBefore, $pair->fresh()->toArray());
        }
    }

    public function test_list_and_detail_query_counts_do_not_grow_per_row_or_question(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload(['questions' => $this->allBlitzQuestions()]));
        $response->assertCreated();
        $id = $response->json('data.id');
        $oneList = $this->readQueryCount($teacher, '/api/v1/teacher/blitz');
        $oneDetail = $this->readQueryCount($teacher, "/api/v1/teacher/blitz/{$id}");
        $questions = [...$this->allBlitzQuestions(), ...array_map(fn (array $question): array => [
            ...$question, 'client_key' => $question['client_key'].'-second', 'position' => $question['position'] + 9,
        ], $this->allBlitzQuestions())];
        $more = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/blitz", $this->validBlitzPayload(['questions' => $questions]))->assertCreated();
        $this->persistedBlitz($institution, $teacher, $topic);
        $this->assertSame($oneList, $this->readQueryCount($teacher, '/api/v1/teacher/blitz'));
        $this->assertSame($oneDetail, $this->readQueryCount($teacher, '/api/v1/teacher/blitz/'.$more->json('data.id')));
    }

    private function readQueryCount(User $teacher, string $uri): int
    {
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $this->blitzRaw($teacher, 'GET', $uri)->assertOk();

            return count(array_filter(DB::getQueryLog(), fn (array $query): bool => str_starts_with(strtolower($query['query']), 'select')));
        } finally {
            DB::disableQueryLog();
            DB::flushQueryLog();
        }
    }

    /** @return list<array<string, mixed>> */
    private function allBlitzQuestions(): array
    {
        $definitions = [
            ['single_choice', 'Choose.', 'automatic', ['options' => [['text' => 'A', 'is_correct' => true, 'position' => 1], ['text' => 'B', 'is_correct' => false, 'position' => 2]]]],
            ['multiple_choice', 'Choose all.', 'automatic', ['options' => [['text' => 'A', 'is_correct' => true, 'position' => 1], ['text' => 'B', 'is_correct' => true, 'position' => 2]]]],
            ['true_false', 'True?', 'automatic', ['correct_value' => true]],
            ['short_written', 'Name it.', 'automatic', ['accepted_answers' => ['DNS']]],
            ['open_written', 'Explain.', 'manual', new stdClass],
            ['file_based', 'Upload.', 'manual', ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx']]],
            ['matching', 'Match.', 'automatic', ['pairs' => [['client_key' => 'pair', 'left' => 'DNS', 'right' => 'Domain Name System']]]],
            ['ordering', 'Order.', 'automatic', ['items' => [['text' => 'First', 'correct_position' => 1], ['text' => 'Second', 'correct_position' => 2]]]],
            ['fill_in_blank', 'DNS maps {{host}}.', 'automatic', ['blanks' => [['key' => 'host', 'position' => 1, 'accepted_answers' => ['domain name']]]]],
        ];

        return array_map(fn (array $definition, int $index): array => [
            'client_key' => 'q'.($index + 1), 'type' => $definition[0], 'prompt' => $definition[1],
            'points' => 0.1, 'position' => $index + 1, 'checking_mode' => $definition[2], 'configuration' => $definition[3],
        ], $definitions, array_keys($definitions));
    }
}
