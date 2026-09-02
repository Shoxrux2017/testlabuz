<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentMode;
use App\Enums\HomeworkStatus;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use stdClass;
use Tests\Feature\Teacher\Concerns\BuildsTeacherHomeworkContext;
use Tests\TestCase;

class TeacherHomeworkAuthoringApiTest extends TestCase
{
    use BuildsTeacherHomeworkContext;
    use RefreshDatabase;

    public function test_teacher_creates_minimal_server_owned_draft_with_utc_deadline_and_exact_resource(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();

        $response = $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload([
            'title' => '  Homework 1  ',
            'student_instructions' => '  Answer all questions.  ',
            'deadline_at' => '2026-08-01T18:00:00+05:00',
        ]));

        $response->assertCreated()
            ->assertJsonPath('message', 'Homework created successfully.')
            ->assertJsonPath('data.title', 'Homework 1')
            ->assertJsonPath('data.student_instructions', 'Answer all questions.')
            ->assertJsonPath('data.assignment_mode', 'group')
            ->assertJsonPath('data.student_ids', [])
            ->assertJsonPath('data.total_possible_points', 0)
            ->assertJsonPath('data.deadline_at', '2026-08-01T13:00:00Z')
            ->assertJsonPath('data.institution_timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.attempt_policy.normal_attempts', 3)
            ->assertJsonPath('data.attempt_policy.official_score_policy', 'highest_valid_completed')
            ->assertJsonCount(0, 'data.questions');

        $this->assertSame([
            'id', 'topic_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'deadline_at', 'institution_timezone', 'status',
            'attempt_policy', 'activated_at', 'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $this->assertDatabaseHas('assessments', [
            'id' => $response->json('data.id'),
            'institution_id' => $institution->id,
            'teacher_id' => $teacher->id,
            'topic_id' => $topic->id,
            'type' => 'homework',
            'total_possible_points' => '0.000000',
        ]);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseHas('homework_assignments', [
            'assessment_id' => $response->json('data.id'),
            'status' => 'draft',
            'activated_at' => null,
            'closed_at' => null,
            'archived_at' => null,
        ]);

        foreach (['institution_id', 'teacher_id', 'attempt_limit', 'assigned_by_user_id'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $response->getContent());
        }
    }

    public function test_create_rejects_a_syntactically_valid_deadline_with_an_offset_mismatched_to_the_institution_timezone(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();

        $response = $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload([
            'deadline_at' => '2026-09-10T18:00:00+04:00',
        ]));

        $response->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonPath(
                'errors.deadline_at.0',
                'The deadline_at must be a valid date-time for the institution timezone with an explicit numeric offset.',
            );
        $this->assertDatabaseCount('assessments', 0);
        $this->assertDatabaseCount('homework_assignments', 0);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('questions', 0);
    }

    public function test_nested_create_persists_and_reconstructs_all_nine_question_types_with_exact_total(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();
        $questions = $this->allQuestionTypes();
        unset($questions[4]['instructions']);

        $response = $this->homeworkJson($teacher, 'POST', "/api/v1/teacher/topics/{$topic->id}/homework", $this->validHomeworkPayload([
            'questions' => $questions,
        ]));

        $response->assertCreated()
            ->assertJsonPath('data.total_possible_points', 0.9)
            ->assertJsonCount(9, 'data.questions');
        $this->assertSame(
            array_column($questions, 'type'),
            array_column($response->json('data.questions'), 'type'),
        );
        $this->assertSame(['pdf', 'docx', 'ppt', 'pptx'], $response->json('data.questions.5.configuration.allowed_extensions'));
        $this->assertNotSame('pair-input', $response->json('data.questions.6.configuration.pairs.0.client_key'));
        $this->assertMatchesRegularExpression(
            '/\A[0-9a-f-]{36}\z/',
            $response->json('data.questions.6.configuration.pairs.0.client_key'),
        );
        $this->assertStringContainsString('"configuration":{}', $response->getContent());

        $this->assertDatabaseCount('questions', 9);
        $this->assertDatabaseCount('question_choice_options', 4);
        $this->assertDatabaseCount('question_true_false_answers', 1);
        $this->assertDatabaseCount('question_short_accepted_answers', 1);
        $this->assertDatabaseCount('question_matching_items', 2);
        $this->assertDatabaseCount('question_ordering_items', 2);
        $this->assertDatabaseCount('question_fill_blanks', 1);
        $this->assertDatabaseCount('question_fill_blank_accepted_answers', 1);
    }

    public function test_invalid_nested_question_and_strict_json_distinctions_roll_back_the_entire_create(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();
        $uri = "/api/v1/teacher/topics/{$topic->id}/homework";
        $validQuestion = $this->allQuestionTypes()[0];

        foreach ([
            [...$validQuestion, 'points' => '1.0'],
            [...$validQuestion, 'type' => 1],
            [...$validQuestion, 'checking_mode' => null],
            [...$validQuestion, 'configuration' => []],
            [...$validQuestion, 'points' => 0.0000001],
            [...$validQuestion, 'unexpected' => true],
        ] as $invalidQuestion) {
            $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload([
                'questions' => [$invalidQuestion],
            ]))->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $duplicateKey = [$validQuestion, [...$validQuestion, 'position' => 2]];
        $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload(['questions' => $duplicateKey]))
            ->assertUnprocessable();
        $badPositions = [$validQuestion, [...$validQuestion, 'client_key' => 'q2', 'position' => 3]];
        $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload(['questions' => $badPositions]))
            ->assertUnprocessable();

        $this->assertDatabaseCount('assessments', 0);
        $this->assertDatabaseCount('homework_assignments', 0);
        $this->assertDatabaseCount('questions', 0);
    }

    public function test_create_strictly_rejects_invalid_bodies_queries_and_protected_fields(): void
    {
        [, $teacher, , , $topic] = $this->homeworkContext();
        $uri = "/api/v1/teacher/topics/{$topic->id}/homework";

        foreach (['', '{', '42', '[]', 'null'] as $content) {
            $this->homeworkRaw($teacher, 'POST', $uri, $content)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach (['student_ids' => new stdClass, 'questions' => new stdClass] as $field => $object) {
            $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload([$field => $object]))
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach ([
            'institution_id', 'teacher_id', 'topic_id', 'status', 'activated_at', 'closed_at',
            'archived_at', 'total_possible_points', 'attempt_limit', 'normal_attempts',
            'official_score_policy', 'created_at', 'updated_at', 'is_official', 'unexpected',
        ] as $protected) {
            $this->homeworkJson($teacher, 'POST', $uri, [
                ...$this->validHomeworkPayload(),
                $protected => 'forbidden',
            ])->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload(), ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkJson($teacher, 'POST', $uri, $this->validHomeworkPayload(['student_ids' => ['id']]))
            ->assertUnprocessable();
        $this->assertDatabaseCount('assessments', 0);
    }

    public function test_create_and_update_require_application_json_without_writing(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $existing = $this->persistedHomework($institution, $teacher, $topic, assessmentAttributes: [
            'title' => 'Original title',
        ]);
        $assessmentUpdatedAt = $existing->updated_at->toJSON();
        $homeworkUpdatedAt = $existing->homeworkAssignment->updated_at->toJSON();

        $this->homeworkWithContentType(
            $teacher,
            'POST',
            "/api/v1/teacher/topics/{$topic->id}/homework",
            $this->validHomeworkPayload(['title' => 'Must not be created']),
            'text/plain',
        )->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonPath('errors.body.0', 'The request body must be an application/json object.');

        $this->homeworkWithContentType(
            $teacher,
            'PATCH',
            "/api/v1/teacher/homework/{$existing->id}",
            ['title' => 'Must not be updated'],
            'text/plain',
        )->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonPath('errors.body.0', 'The request body must be an application/json object.');

        $existing->refresh();
        $this->assertSame('Original title', $existing->title);
        $this->assertSame($assessmentUpdatedAt, $existing->updated_at->toJSON());
        $this->assertSame($homeworkUpdatedAt, $existing->homeworkAssignment->fresh()?->updated_at->toJSON());
        $this->assertDatabaseCount('assessments', 1);
        $this->assertDatabaseCount('homework_assignments', 1);
        $this->assertDatabaseCount('assessment_students', 0);
        $this->assertDatabaseCount('questions', 0);
    }

    public function test_list_is_topic_scoped_filterable_searchable_deterministic_and_null_deadlines_sort_last(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $alpha = $this->persistedHomework($institution, $teacher, $topic, AssessmentAssignmentMode::Group, HomeworkStatus::Draft, [
            'title' => 'Alpha literal % work',
        ], ['deadline_at' => null]);
        $beta = $this->persistedHomework($institution, $teacher, $topic, AssessmentAssignmentMode::SelectedStudents, HomeworkStatus::Active, [
            'title' => 'Beta',
        ], ['deadline_at' => '2026-09-10 13:00:00+00']);
        Question::factory()->openWritten()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $beta->id,
            'position' => 1,
        ]);

        $response = $this->homeworkRaw(
            $teacher,
            'GET',
            "/api/v1/teacher/topics/{$topic->id}/homework",
            '',
            ['sort' => 'deadline_at', 'direction' => 'asc'],
        );
        $response->assertOk()->assertJsonPath('data.0.id', $beta->id)->assertJsonPath('data.1.id', $alpha->id);
        $this->assertSame(1, $response->json('data.0.question_count'));

        $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/topics/{$topic->id}/homework", '', [
            'status' => 'draft',
            'assignment_mode' => 'group',
            'search' => '%',
        ])->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $alpha->id);

        $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/topics/{$topic->id}/homework", '', ['unknown' => 1])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $page = $this->homeworkRaw($teacher, 'GET', "/api/v1/teacher/topics/{$topic->id}/homework", '', [
            'sort' => 'title',
            'direction' => 'asc',
            'page' => 2,
            'per_page' => 1,
        ]);
        $page->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $beta->id);
        $this->assertSame([
            'page' => 2,
            'per_page' => 1,
            'total' => 2,
            'last_page' => 2,
        ], $page->json('meta.pagination'));
    }

    /** @param array<string, mixed> $payload */
    private function homeworkWithContentType(
        User $teacher,
        string $method,
        string $uri,
        array $payload,
        string $contentType,
    ): TestResponse {
        $server = [
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('teacher-homework-content-type-test')->plainTextToken,
        ];

        $response = $this->call(
            $method,
            $uri,
            [],
            [],
            [],
            $server,
            json_encode($payload, JSON_THROW_ON_ERROR),
        );
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** @return list<array<string, mixed>> */
    private function allQuestionTypes(): array
    {
        return [
            $this->question('q1', 'single_choice', 'Choose one.', 1, 'automatic', [
                'options' => [
                    ['text' => 'A', 'is_correct' => true, 'position' => 1],
                    ['text' => 'B', 'is_correct' => false, 'position' => 2],
                ],
            ]),
            $this->question('q2', 'multiple_choice', 'Choose all.', 2, 'automatic', [
                'options' => [
                    ['text' => 'A', 'is_correct' => true, 'position' => 1],
                    ['text' => 'B', 'is_correct' => true, 'position' => 2],
                ],
            ]),
            $this->question('q3', 'true_false', 'True?', 3, 'automatic', ['correct_value' => true]),
            $this->question('q4', 'short_written', 'Name it.', 4, 'automatic', ['accepted_answers' => ['DNS']]),
            $this->question('q5', 'open_written', 'Explain.', 5, 'manual', new stdClass),
            $this->question('q6', 'file_based', 'Upload.', 6, 'manual', ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx']]),
            $this->question('q7', 'matching', 'Match.', 7, 'automatic', ['pairs' => [
                ['client_key' => 'pair-input', 'left' => 'DNS', 'right' => 'Domain Name System'],
            ]]),
            $this->question('q8', 'ordering', 'Order.', 8, 'automatic', ['items' => [
                ['text' => 'First', 'correct_position' => 1],
                ['text' => 'Second', 'correct_position' => 2],
            ]]),
            $this->question('q9', 'fill_in_blank', 'DNS maps {{host}}.', 9, 'automatic', ['blanks' => [
                ['key' => 'host', 'position' => 1, 'accepted_answers' => ['domain name']],
            ]]),
        ];
    }

    /** @return array<string, mixed> */
    private function question(
        string $clientKey,
        string $type,
        string $prompt,
        int $position,
        string $checkingMode,
        array|stdClass $configuration,
    ): array {
        return [
            'client_key' => $clientKey,
            'type' => $type,
            'prompt' => $prompt,
            'instructions' => null,
            'points' => 0.1,
            'position' => $position,
            'checking_mode' => $checkingMode,
            'configuration' => $configuration,
        ];
    }
}
