<?php

namespace Tests\Feature\Teacher;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionOrderingItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use stdClass;
use Tests\Feature\Teacher\Concerns\BuildsTeacherQuestionMutationContext;
use Tests\TestCase;

class TeacherQuestionMutationApiTest extends TestCase
{
    use BuildsTeacherQuestionMutationContext;
    use RefreshDatabase;

    public function test_add_inserts_at_beginning_middle_and_end_with_contiguous_positions_and_exact_total(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $this->persistedQuestion($homework, ['prompt' => 'Original one', 'points' => 2, 'position' => 1]);
        $this->persistedQuestion($homework, ['prompt' => 'Original two', 'points' => 3, 'position' => 2]);
        $this->synchronizeQuestionTotal($homework);
        $uri = "/api/v1/teacher/assessments/{$homework->id}/questions";

        $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload([
            'prompt' => 'Inserted first',
            'points' => 1,
            'position' => 1,
        ]))->assertCreated()
            ->assertJsonPath('message', 'Question created successfully.')
            ->assertJsonPath('data.total_possible_points', 6)
            ->assertJsonPath('data.questions.0.prompt', 'Inserted first');

        $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload([
            'prompt' => 'Appended',
            'points' => 4,
            'position' => 4,
        ]))->assertCreated()
            ->assertJsonPath('data.total_possible_points', 10)
            ->assertJsonPath('data.questions.3.prompt', 'Appended');

        $response = $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload([
            'prompt' => 'Inserted middle',
            'points' => 0.5,
            'position' => 3,
        ]));

        $response->assertCreated()
            ->assertJsonPath('data.total_possible_points', 10.5)
            ->assertJsonCount(5, 'data.questions');
        $this->assertSame(
            ['Inserted first', 'Original one', 'Inserted middle', 'Original two', 'Appended'],
            array_column($response->json('data.questions'), 'prompt'),
        );
        $this->assertSame([1, 2, 3, 4, 5], array_column($response->json('data.questions'), 'position'));
        $this->assertSame(
            [1, 2, 3, 4, 5],
            Question::query()->where('assessment_id', $homework->id)->orderBy('position')->pluck('position')->all(),
        );
    }

    public function test_add_persists_and_returns_all_nine_typed_configurations(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $uri = "/api/v1/teacher/assessments/{$homework->id}/questions";
        $lastResponse = null;

        foreach ($this->allDedicatedQuestionPayloads() as $index => $payload) {
            $lastResponse = $this->homeworkJson($teacher, 'POST', $uri, [
                ...$payload,
                'points' => 0.1,
                'position' => $index + 1,
            ])->assertCreated();
        }

        $this->assertInstanceOf(TestResponse::class, $lastResponse);
        $lastResponse->assertJsonCount(9, 'data.questions')
            ->assertJsonPath('data.total_possible_points', 0.9);
        $this->assertSame(
            ['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'file_based', 'matching', 'ordering', 'fill_in_blank'],
            array_column($lastResponse->json('data.questions'), 'type'),
        );
        $this->assertNotSame(
            'request-pair',
            $lastResponse->json('data.questions.6.configuration.pairs.0.client_key'),
        );
        $this->assertDatabaseCount('questions', 9);
        $this->assertDatabaseCount('question_choice_options', 4);
        $this->assertDatabaseCount('question_true_false_answers', 1);
        $this->assertDatabaseCount('question_short_accepted_answers', 1);
        $this->assertDatabaseCount('question_matching_items', 2);
        $this->assertDatabaseCount('question_ordering_items', 2);
        $this->assertDatabaseCount('question_fill_blanks', 1);
        $this->assertDatabaseCount('question_fill_blank_accepted_answers', 1);
    }

    public function test_add_strictly_rejects_invalid_bodies_fields_types_configuration_queries_and_positions(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $uri = "/api/v1/teacher/assessments/{$homework->id}/questions";

        foreach (['', '{', '42', '[]', 'null'] as $content) {
            $this->homeworkRaw($teacher, 'POST', $uri, $content)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach ([
            ['points' => '1'],
            ['points' => 0.0000001],
            ['position' => '1'],
            ['configuration' => []],
            ['configuration' => ['correct_value' => 1]],
            ['client_key' => 'not-allowed'],
            ['assessment_id' => $homework->id],
            ['unexpected' => true],
        ] as $invalid) {
            $this->homeworkJson($teacher, 'POST', $uri, [
                ...$this->questionPayload(),
                ...$invalid,
            ])->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach ([0, 2] as $position) {
            $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload(['position' => $position]))
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->homeworkJson($teacher, 'POST', $uri, $this->questionPayload(), ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->questionWithContentType($teacher, 'POST', $uri, $this->questionPayload(), 'text/plain')
            ->assertUnprocessable()
            ->assertJsonPath('errors.body.0', 'The request body must be an application/json object.');
        $this->assertDatabaseCount('questions', 0);
    }

    public function test_add_rejects_the_maximum_question_count_without_writes(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);

        for ($position = 1; $position <= QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT; $position++) {
            $this->persistedQuestion($homework, [
                'prompt' => 'Question '.$position,
                'position' => $position,
            ]);
        }
        $this->synchronizeQuestionTotal($homework);

        $this->homeworkJson(
            $teacher,
            'POST',
            "/api/v1/teacher/assessments/{$homework->id}/questions",
            $this->questionPayload(['position' => QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT + 1]),
        )->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseCount('questions', QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT);
    }

    public function test_patch_updates_common_fields_and_replaces_a_complete_typed_configuration(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework, [
            'type' => 'single_choice',
            'prompt' => 'Old prompt',
            'points' => 1,
            'configuration' => ['options' => [
                ['text' => 'Old correct', 'is_correct' => true, 'position' => 1],
                ['text' => 'Old wrong', 'is_correct' => false, 'position' => 2],
            ]],
        ]);
        $this->synchronizeQuestionTotal($homework);

        $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'type' => 'open_written',
            'prompt' => '  New prompt  ',
            'instructions' => 'Explain your reasoning.',
            'points' => 2.125,
            'checking_mode' => 'manual',
            'configuration' => new stdClass,
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Question updated successfully.')
            ->assertJsonPath('data.total_possible_points', 2.125)
            ->assertJsonPath('data.questions.0.type', 'open_written')
            ->assertJsonPath('data.questions.0.prompt', 'New prompt')
            ->assertJsonPath('data.questions.0.instructions', 'Explain your reasoning.')
            ->assertJsonPath('data.questions.0.points', 2.125)
            ->assertJsonPath('data.questions.0.checking_mode', 'manual');
        $this->assertSame([], $response->json('data.questions.0.configuration'));
        $this->assertDatabaseMissing('question_choice_options', ['question_id' => $question->id]);
        $this->assertDatabaseHas('questions', [
            'id' => $question->id,
            'type' => 'open_written',
            'checking_mode' => 'manual',
            'points' => '2.125000',
        ]);
    }

    public function test_prompt_only_patch_persists_prompt_and_returns_the_complete_teacher_homework_resource(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework);
        $this->synchronizeQuestionTotal($homework);

        $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'prompt' => 'Updated prompt',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Question updated successfully.')
            ->assertJsonPath('data.id', $homework->id)
            ->assertJsonPath('data.topic_id', $topic->id)
            ->assertJsonPath('data.assignment_mode', 'group')
            ->assertJsonPath('data.student_ids', [])
            ->assertJsonPath('data.total_possible_points', 1)
            ->assertJsonPath('data.institution_timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.attempt_policy.normal_attempts', 3)
            ->assertJsonPath('data.attempt_policy.official_score_policy', 'highest_valid_completed')
            ->assertJsonCount(1, 'data.questions')
            ->assertJsonPath('data.questions.0.id', $question->id)
            ->assertJsonPath('data.questions.0.type', 'true_false')
            ->assertJsonPath('data.questions.0.prompt', 'Updated prompt')
            ->assertJsonPath('data.questions.0.instructions', null)
            ->assertJsonPath('data.questions.0.points', 1)
            ->assertJsonPath('data.questions.0.position', 1)
            ->assertJsonPath('data.questions.0.checking_mode', 'automatic')
            ->assertJsonPath('data.questions.0.configuration.correct_value', true);
        $this->assertSame([
            'id', 'topic_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'deadline_at', 'institution_timezone', 'status',
            'attempt_policy', 'activated_at', 'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $this->assertSame([
            'id', 'type', 'prompt', 'instructions', 'points', 'position', 'checking_mode', 'configuration',
        ], array_keys($response->json('data.questions.0')));
        $this->assertDatabaseHas('questions', [
            'id' => $question->id,
            'prompt' => 'Updated prompt',
        ]);
    }

    /**
     * @param  array<string, mixed>  $configuration
     * @param  array<string, mixed>  $expectedConfiguration
     */
    #[DataProvider('positionBearingTypeTransitions')]
    public function test_patch_transitions_from_an_obsolete_typed_schema_into_a_position_bearing_schema(
        string $type,
        string $prompt,
        array $configuration,
        array $expectedConfiguration,
    ): void {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework);
        $this->synchronizeQuestionTotal($homework);

        $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'type' => $type,
            'prompt' => $prompt,
            'configuration' => $configuration,
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Question updated successfully.')
            ->assertJsonPath('data.id', $homework->id)
            ->assertJsonPath('data.topic_id', $topic->id)
            ->assertJsonPath('data.assignment_mode', 'group')
            ->assertJsonPath('data.student_ids', [])
            ->assertJsonPath('data.total_possible_points', 1)
            ->assertJsonPath('data.institution_timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.status', 'draft')
            ->assertJsonPath('data.attempt_policy.normal_attempts', 3)
            ->assertJsonPath('data.attempt_policy.official_score_policy', 'highest_valid_completed')
            ->assertJsonCount(1, 'data.questions')
            ->assertJsonPath('data.questions.0.id', $question->id)
            ->assertJsonPath('data.questions.0.type', $type)
            ->assertJsonPath('data.questions.0.prompt', $prompt)
            ->assertJsonPath('data.questions.0.instructions', null)
            ->assertJsonPath('data.questions.0.points', 1)
            ->assertJsonPath('data.questions.0.position', 1)
            ->assertJsonPath('data.questions.0.checking_mode', 'automatic')
            ->assertJsonPath('data.questions.0.configuration', $expectedConfiguration);
        $this->assertSame([
            'id', 'topic_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'deadline_at', 'institution_timezone', 'status',
            'attempt_policy', 'activated_at', 'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $this->assertSame([
            'id', 'type', 'prompt', 'instructions', 'points', 'position', 'checking_mode', 'configuration',
        ], array_keys($response->json('data.questions.0')));
        $this->assertDatabaseHas('questions', [
            'id' => $question->id,
            'type' => $type,
            'prompt' => $prompt,
            'checking_mode' => 'automatic',
        ]);
        $this->assertSame($expectedConfiguration, $this->persistedPositionBearingConfiguration($question, $type));
        $this->assertDatabaseMissing('question_true_false_answers', ['question_id' => $question->id]);
    }

    /** @return iterable<string, array{string, string, array<string, mixed>, array<string, mixed>}> */
    public static function positionBearingTypeTransitions(): iterable
    {
        yield 'single choice' => [
            'single_choice',
            'Choose one.',
            ['options' => [
                ['text' => 'Second', 'is_correct' => false, 'position' => 2],
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
            ]],
            ['options' => [
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
                ['text' => 'Second', 'is_correct' => false, 'position' => 2],
            ]],
        ];

        yield 'multiple choice' => [
            'multiple_choice',
            'Choose all.',
            ['options' => [
                ['text' => 'Third', 'is_correct' => false, 'position' => 3],
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
                ['text' => 'Second', 'is_correct' => true, 'position' => 2],
            ]],
            ['options' => [
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
                ['text' => 'Second', 'is_correct' => true, 'position' => 2],
                ['text' => 'Third', 'is_correct' => false, 'position' => 3],
            ]],
        ];

        yield 'ordering' => [
            'ordering',
            'Put these in order.',
            ['items' => [
                ['text' => 'Second', 'correct_position' => 2],
                ['text' => 'First', 'correct_position' => 1],
            ]],
            ['items' => [
                ['text' => 'First', 'correct_position' => 1],
                ['text' => 'Second', 'correct_position' => 2],
            ]],
        ];

        yield 'fill in blank' => [
            'fill_in_blank',
            'Use {{first}} before {{second}}.',
            ['blanks' => [
                ['key' => 'second', 'position' => 2, 'accepted_answers' => ['beta', 'two']],
                ['key' => 'first', 'position' => 1, 'accepted_answers' => ['alpha', 'one']],
            ]],
            ['blanks' => [
                ['key' => 'first', 'position' => 1, 'accepted_answers' => ['alpha', 'one']],
                ['key' => 'second', 'position' => 2, 'accepted_answers' => ['beta', 'two']],
            ]],
        ];
    }

    /** @return array<string, mixed> */
    private function persistedPositionBearingConfiguration(Question $question, string $type): array
    {
        return match ($type) {
            'single_choice', 'multiple_choice' => [
                'options' => QuestionChoiceOption::query()
                    ->where('question_id', $question->id)
                    ->orderBy('position')
                    ->get()
                    ->map(fn (QuestionChoiceOption $option): array => [
                        'text' => $option->option_text,
                        'is_correct' => $option->is_correct,
                        'position' => $option->position,
                    ])->all(),
            ],
            'ordering' => [
                'items' => QuestionOrderingItem::query()
                    ->where('question_id', $question->id)
                    ->orderBy('correct_position')
                    ->get()
                    ->map(fn (QuestionOrderingItem $item): array => [
                        'text' => $item->item_text,
                        'correct_position' => $item->correct_position,
                    ])->all(),
            ],
            'fill_in_blank' => [
                'blanks' => QuestionFillBlank::query()
                    ->where('question_id', $question->id)
                    ->with(['acceptedAnswers' => fn ($query) => $query->orderBy('position')])
                    ->orderBy('position')
                    ->get()
                    ->map(fn (QuestionFillBlank $blank): array => [
                        'key' => $blank->blank_key,
                        'position' => $blank->position,
                        'accepted_answers' => $blank->acceptedAnswers->pluck('accepted_text')->all(),
                    ])->all(),
            ],
        };
    }

    public function test_patch_rejects_partial_typed_transitions_position_and_invalid_resulting_configuration(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework);
        $uri = "/api/v1/teacher/questions/{$question->id}";

        foreach ([
            ['type' => 'open_written'],
            ['checking_mode' => 'manual'],
            ['position' => 2],
            ['configuration' => ['correct_value' => 'false']],
            [],
        ] as $payload) {
            $this->homeworkJson($teacher, 'PATCH', $uri, $payload)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->assertDatabaseHas('questions', [
            'id' => $question->id,
            'type' => 'true_false',
            'position' => 1,
        ]);
        $this->assertDatabaseHas('question_true_false_answers', [
            'question_id' => $question->id,
            'correct_value' => true,
        ]);
    }

    public function test_patch_replaces_configuration_without_changing_common_question_fields(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework);
        $this->synchronizeQuestionTotal($homework);

        $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'configuration' => ['correct_value' => false],
        ]);

        $response->assertOk()
            ->assertJsonPath('data.questions.0.type', 'true_false')
            ->assertJsonPath('data.questions.0.prompt', 'Is this statement true?')
            ->assertJsonPath('data.questions.0.configuration.correct_value', false)
            ->assertJsonPath('data.total_possible_points', 1);
        $this->assertDatabaseHas('question_true_false_answers', [
            'question_id' => $question->id,
            'correct_value' => false,
        ]);
        $this->assertDatabaseCount('question_true_false_answers', 1);
    }

    public function test_delete_compacts_positions_recalculates_total_and_allows_zero_question_draft(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $first = $this->persistedQuestion($homework, ['prompt' => 'First', 'points' => 1, 'position' => 1]);
        $middle = $this->persistedQuestion($homework, ['prompt' => 'Middle', 'points' => 2, 'position' => 2]);
        $last = $this->persistedQuestion($homework, ['prompt' => 'Last', 'points' => 3, 'position' => 3]);
        $this->synchronizeQuestionTotal($homework);

        $this->homeworkRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$middle->id}", '')
            ->assertOk()
            ->assertJsonPath('message', 'Question deleted successfully.')
            ->assertJsonPath('data.total_possible_points', 4)
            ->assertJsonCount(2, 'data.questions')
            ->assertJsonPath('data.questions.0.id', $first->id)
            ->assertJsonPath('data.questions.1.id', $last->id)
            ->assertJsonPath('data.questions.1.position', 2);
        $this->assertDatabaseMissing('question_true_false_answers', ['question_id' => $middle->id]);
        $this->assertDatabaseMissing('questions', ['id' => $middle->id]);

        $this->homeworkRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$first->id}", '')->assertOk();
        $this->homeworkRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$last->id}", '')
            ->assertOk()
            ->assertJsonPath('data.total_possible_points', 0)
            ->assertJsonCount(0, 'data.questions');
    }

    public function test_reorder_requires_the_exact_set_and_preserves_total(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $first = $this->persistedQuestion($homework, ['prompt' => 'First', 'points' => 0.1, 'position' => 1]);
        $second = $this->persistedQuestion($homework, ['prompt' => 'Second', 'points' => 0.2, 'position' => 2]);
        $third = $this->persistedQuestion($homework, ['prompt' => 'Third', 'points' => 0.3, 'position' => 3]);
        $this->synchronizeQuestionTotal($homework);
        $otherHomework = $this->persistedHomework($institution, $teacher, $topic);
        $foreignQuestion = $this->persistedQuestion($otherHomework);
        $uri = "/api/v1/teacher/assessments/{$homework->id}/questions/reorder";

        $response = $this->homeworkJson($teacher, 'POST', $uri, [
            'question_ids' => [$third->id, $second->id, $first->id],
        ]);
        $response->assertOk()
            ->assertJsonPath('message', 'Questions reordered successfully.')
            ->assertJsonPath('data.total_possible_points', 0.6);
        $this->assertSame([$third->id, $second->id, $first->id], array_column($response->json('data.questions'), 'id'));
        $this->assertSame([1, 2, 3], array_column($response->json('data.questions'), 'position'));

        foreach ([
            [$third->id, $second->id],
            [$third->id, $third->id, $first->id],
            [$third->id, $second->id, $foreignQuestion->id],
            [$third->id, $second->id, '00000000-0000-0000-0000-000000000001'],
            [$third->id, $second->id, $first->id, $foreignQuestion->id],
        ] as $invalidIds) {
            $this->homeworkJson($teacher, 'POST', $uri, ['question_ids' => $invalidIds])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->homeworkJson($teacher, 'POST', $uri, [
            'question_ids' => [$third->id, $second->id, $first->id],
            'unexpected' => true,
        ])->assertUnprocessable();
        $this->homeworkJson($teacher, 'POST', $uri, ['question_ids' => [$third->id]], ['q' => 'x'])
            ->assertUnprocessable();
        $this->assertSame('0.600000', $homework->fresh()?->total_possible_points);
    }

    public function test_delete_rejects_bodies_and_query_parameters(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework);
        $uri = "/api/v1/teacher/questions/{$question->id}";

        $this->homeworkRaw($teacher, 'DELETE', $uri, '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->homeworkRaw($teacher, 'DELETE', $uri, '', ['unexpected' => 'x'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseHas('questions', ['id' => $question->id]);
    }

    /** @param array<string, mixed> $payload */
    private function questionWithContentType(
        User $teacher,
        string $method,
        string $uri,
        array $payload,
        string $contentType,
    ): TestResponse {
        $server = [
            'CONTENT_TYPE' => $contentType,
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$teacher->createToken('teacher-question-content-type-test')->plainTextToken,
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
}
