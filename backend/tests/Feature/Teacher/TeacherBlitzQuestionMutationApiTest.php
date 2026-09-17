<?php

namespace Tests\Feature\Teacher;

use App\Actions\Teacher\ShowTeacherAssessmentAuthoring;
use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Enums\BlitzStatus;
use App\Http\Resources\Teacher\TeacherAssessmentAuthoringResource;
use App\Models\Assessment;
use App\Models\Question;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use stdClass;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzContext;
use Tests\Feature\Teacher\Concerns\BuildsTeacherQuestionMutationContext;
use Tests\TestCase;

class TeacherBlitzQuestionMutationApiTest extends TestCase
{
    use BuildsTeacherBlitzContext;
    use BuildsTeacherQuestionMutationContext;
    use RefreshDatabase;

    public function test_add_persists_all_nine_types_and_exact_total_without_changing_blitz_state(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $blitzBefore = $assessment->blitzTask->getRawOriginal();
        $this->travel(1)->hour();

        foreach ($this->allDedicatedQuestionPayloads() as $index => $payload) {
            $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/assessments/{$assessment->id}/questions", [
                ...$payload, 'points' => 0.1, 'position' => $index + 1,
            ])->assertCreated()
                ->assertJsonPath('message', 'Question created successfully.')
                ->assertJsonPath("data.questions.{$index}.type", $payload['type'])
                ->assertJsonPath("data.questions.{$index}.checking_mode", $payload['checking_mode'])
                ->assertJsonPath("data.questions.{$index}.points", 0.1);

            if ($payload['type'] === 'matching') {
                $response->assertJsonPath("data.questions.{$index}.configuration.pairs.0.left", 'DNS')
                    ->assertJsonPath("data.questions.{$index}.configuration.pairs.0.right", 'Domain Name System');
                $this->assertNotSame('request-pair', $response->json("data.questions.{$index}.configuration.pairs.0.client_key"));
            } else {
                $response->assertJsonPath("data.questions.{$index}.configuration", (array) $payload['configuration']);
            }

            $this->assertSame(number_format(($index + 1) / 10, 6, '.', ''), $assessment->fresh()->total_possible_points);
            $this->assertCompleteBlitzResource($response, $assessment, $teacher);
        }

        $response->assertJsonCount(9, 'data.questions')->assertJsonPath('data.total_possible_points', 0.9);
        foreach ([
            'questions' => 9, 'question_choice_options' => 4, 'question_true_false_answers' => 1,
            'question_short_accepted_answers' => 1, 'question_matching_items' => 2,
            'question_ordering_items' => 2, 'question_fill_blanks' => 1, 'question_fill_blank_accepted_answers' => 1,
        ] as $table => $count) {
            $this->assertDatabaseCount($table, $count);
        }

        $this->assertBlitzStateUnchanged($assessment, $blitzBefore);
    }

    #[DataProvider('editableBlitzStatuses')]
    public function test_add_inserts_first_middle_and_last_with_contiguous_positions_and_exact_total(BlitzStatus $status): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
        $this->persistedQuestion($assessment, ['prompt' => 'Original first', 'points' => 0.1, 'position' => 1]);
        $this->persistedQuestion($assessment, ['prompt' => 'Original last', 'points' => 0.2, 'position' => 2]);
        $this->synchronizeQuestionTotal($assessment);
        $blitzBefore = $assessment->blitzTask->getRawOriginal();
        $this->travel(1)->hour();

        foreach ([
            ['First', 1, 0.000001, '0.300001'],
            ['Last', 4, 0.3, '0.600001'],
            ['Middle', 3, 0.000009, '0.600010'],
        ] as [$prompt, $position, $points, $expectedTotal]) {
            $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/assessments/{$assessment->id}/questions", $this->questionPayload([
                'prompt' => $prompt, 'position' => $position, 'points' => $points,
            ]))->assertCreated()->assertJsonPath('message', 'Question created successfully.');
            $this->assertSame($expectedTotal, $assessment->fresh()->total_possible_points);
            $this->assertCompleteBlitzResource($response, $assessment, $teacher);
        }

        $this->assertSame(['First', 'Original first', 'Middle', 'Original last', 'Last'], array_column($response->json('data.questions'), 'prompt'));
        $this->assertSame([1, 2, 3, 4, 5], array_column($response->json('data.questions'), 'position'));
        $this->assertSame([1, 2, 3, 4, 5], Question::query()->where('assessment_id', $assessment->id)->orderBy('position')->pluck('position')->all());
        $this->assertBlitzStateUnchanged($assessment, $blitzBefore);
    }

    public function test_add_rejects_maximum_question_count_without_changing_questions_total_or_timestamps(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);

        for ($position = 1; $position <= QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT; $position++) {
            $this->persistedQuestion($assessment, ['position' => $position]);
        }

        $this->synchronizeQuestionTotal($assessment);
        $assessmentBefore = $assessment->fresh()->getRawOriginal();
        $questionsBefore = $this->questionRows($assessment);
        $this->travel(1)->hour();
        $this->blitzJson($teacher, 'POST', "/api/v1/teacher/assessments/{$assessment->id}/questions", $this->questionPayload([
            'position' => QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT + 1,
        ]))->assertUnprocessable()->assertJsonPath('code', 'validation_failed');

        $this->assertSame($assessmentBefore, $assessment->fresh()->getRawOriginal());
        $this->assertSame($questionsBefore, $this->questionRows($assessment));
        $this->assertDatabaseCount('questions', QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT);
        $this->assertDatabaseCount('question_true_false_answers', QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT);
    }

    public function test_patch_updates_common_fields_checking_mode_and_type_without_leaving_obsolete_children(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $question = $this->persistedQuestion($assessment, [
            'type' => 'single_choice', 'points' => 0.1,
            'configuration' => ['options' => [
                ['text' => 'Old correct', 'is_correct' => true, 'position' => 1],
                ['text' => 'Old incorrect', 'is_correct' => false, 'position' => 2],
            ]],
        ]);
        $this->persistedQuestion($assessment, ['points' => 0.2, 'position' => 2]);
        $this->synchronizeQuestionTotal($assessment);
        $blitzBefore = $assessment->blitzTask->getRawOriginal();
        $questionUpdatedAt = $question->updated_at->toJSON();
        $assessmentUpdatedAt = $assessment->fresh()->updated_at->toJSON();
        $this->travel(1)->hour();

        $response = $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'type' => 'open_written', 'prompt' => '  Explain the answer.  ',
            'instructions' => 'Show your reasoning.', 'points' => 0.100001,
            'checking_mode' => 'manual', 'configuration' => new stdClass,
        ])->assertOk()
            ->assertJsonPath('message', 'Question updated successfully.')
            ->assertJsonPath('data.total_possible_points', 0.300001)
            ->assertJsonPath('data.questions.0.id', $question->id)
            ->assertJsonPath('data.questions.0.type', 'open_written')
            ->assertJsonPath('data.questions.0.prompt', 'Explain the answer.')
            ->assertJsonPath('data.questions.0.instructions', 'Show your reasoning.')
            ->assertJsonPath('data.questions.0.checking_mode', 'manual')
            ->assertJsonPath('data.questions.0.configuration', []);

        $this->assertDatabaseMissing('question_choice_options', ['question_id' => $question->id]);
        $this->assertSame('0.300001', $assessment->fresh()->total_possible_points);
        $this->assertNotSame($questionUpdatedAt, $question->fresh()->updated_at->toJSON());
        $this->assertNotSame($assessmentUpdatedAt, $assessment->fresh()->updated_at->toJSON());
        $this->assertCompleteBlitzResource($response, $assessment, $teacher);
        $this->assertBlitzStateUnchanged($assessment, $blitzBefore);
    }

    public function test_patch_completely_replaces_nested_typed_children_and_preserves_other_question_fields(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $question = $this->persistedQuestion($assessment, [
            'type' => 'fill_in_blank', 'prompt' => 'Use {{first}} before {{second}}.',
            'configuration' => ['blanks' => [
                ['key' => 'first', 'position' => 1, 'accepted_answers' => ['Old first', 'Old alias']],
                ['key' => 'second', 'position' => 2, 'accepted_answers' => ['Old second']],
            ]],
        ]);
        $oldBlankIds = QuestionFillBlank::query()->where('question_id', $question->id)->pluck('id')->all();
        $this->synchronizeQuestionTotal($assessment);
        $configuration = ['blanks' => [
            ['key' => 'first', 'position' => 1, 'accepted_answers' => ['New first']],
            ['key' => 'second', 'position' => 2, 'accepted_answers' => ['New second']],
        ]];

        $response = $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'configuration' => $configuration,
        ])->assertOk()
            ->assertJsonPath('data.questions.0.prompt', $question->prompt)
            ->assertJsonPath('data.questions.0.type', 'fill_in_blank')
            ->assertJsonPath('data.questions.0.checking_mode', 'automatic')
            ->assertJsonPath('data.questions.0.configuration', $configuration)
            ->assertJsonPath('data.total_possible_points', 1);

        foreach ($oldBlankIds as $blankId) {
            $this->assertDatabaseMissing('question_fill_blanks', ['id' => $blankId]);
            $this->assertDatabaseMissing('question_fill_blank_accepted_answers', ['blank_id' => $blankId]);
        }

        $this->assertDatabaseCount('question_fill_blanks', 2);
        $this->assertDatabaseCount('question_fill_blank_accepted_answers', 2);
        $this->assertCompleteBlitzResource($response, $assessment, $teacher);
    }

    public function test_exact_and_matching_semantic_no_op_updates_preserve_question_children_and_parent_timestamps(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Scheduled);
        $question = $this->persistedQuestion($assessment, [
            'type' => 'matching', 'prompt' => 'Match the abbreviation.',
            'configuration' => ['pairs' => [
                ['client_key' => 'original-key', 'left' => 'DNS', 'right' => 'Domain Name System'],
            ]],
        ]);
        $this->synchronizeQuestionTotal($assessment);
        $assessmentBefore = $assessment->fresh()->getRawOriginal();
        $questionsBefore = $this->questionRows($assessment);
        $childrenBefore = QuestionMatchingItem::query()->where('question_id', $question->id)->orderBy('id')->get()->toArray();
        $blitzBefore = $assessment->blitzTask->getRawOriginal();
        $this->travel(1)->hour();

        foreach ([
            ['prompt' => $question->prompt, 'instructions' => null, 'points' => 1],
            ['configuration' => ['pairs' => [
                ['client_key' => 'a-new-request-key', 'left' => 'DNS', 'right' => 'Domain Name System'],
            ]]],
        ] as $payload) {
            $response = $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", $payload)
                ->assertOk()->assertJsonPath('message', 'Question updated successfully.');

            $this->assertSame($assessmentBefore, $assessment->fresh()->getRawOriginal());
            $this->assertSame($questionsBefore, $this->questionRows($assessment));
            $this->assertSame($childrenBefore, QuestionMatchingItem::query()->where('question_id', $question->id)->orderBy('id')->get()->toArray());
            $this->assertCompleteBlitzResource($response, $assessment, $teacher);
            $this->assertBlitzStateUnchanged($assessment, $blitzBefore);
        }
    }

    #[DataProvider('editableBlitzStatuses')]
    public function test_delete_removes_nested_configuration_compacts_positions_and_allows_deleting_last_question(BlitzStatus $status): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
        $first = $this->persistedQuestion($assessment, ['points' => 0.1, 'position' => 1]);
        $middle = $this->persistedQuestion($assessment, [
            'type' => 'fill_in_blank', 'prompt' => 'Use {{value}}.', 'points' => 0.2, 'position' => 2,
            'configuration' => ['blanks' => [['key' => 'value', 'position' => 1, 'accepted_answers' => ['one']]]],
        ]);
        $blankId = QuestionFillBlank::query()->where('question_id', $middle->id)->firstOrFail()->id;
        $last = $this->persistedQuestion($assessment, ['points' => 0.000001, 'position' => 3]);
        $this->synchronizeQuestionTotal($assessment);
        $blitzBefore = $assessment->blitzTask->getRawOriginal();
        $this->travel(1)->hour();

        $response = $this->blitzRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$middle->id}")
            ->assertOk()
            ->assertJsonPath('message', 'Question deleted successfully.')
            ->assertJsonPath('data.total_possible_points', 0.100001)
            ->assertJsonPath('data.questions.0.id', $first->id)
            ->assertJsonPath('data.questions.1.id', $last->id)
            ->assertJsonPath('data.questions.1.position', 2);
        $this->assertSame('0.100001', $assessment->fresh()->total_possible_points);
        $this->assertSame([1, 2], Question::query()->where('assessment_id', $assessment->id)->orderBy('position')->pluck('position')->all());
        $this->assertDatabaseMissing('questions', ['id' => $middle->id]);
        $this->assertDatabaseMissing('question_fill_blanks', ['id' => $blankId]);
        $this->assertDatabaseMissing('question_fill_blank_accepted_answers', ['blank_id' => $blankId]);
        $this->assertCompleteBlitzResource($response, $assessment, $teacher);

        $this->blitzRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$first->id}")->assertOk();
        $emptyResponse = $this->blitzRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$last->id}")
            ->assertOk()->assertJsonCount(0, 'data.questions')->assertJsonPath('data.total_possible_points', 0);
        $this->assertSame('0.000000', $assessment->fresh()->total_possible_points);
        $this->assertDatabaseMissing('question_true_false_answers', ['question_id' => $first->id]);
        $this->assertDatabaseMissing('question_true_false_answers', ['question_id' => $last->id]);
        $this->assertCompleteBlitzResource($emptyResponse, $assessment, $teacher);
        $this->assertBlitzStateUnchanged($assessment, $blitzBefore);
    }

    #[DataProvider('editableBlitzStatuses')]
    public function test_zero_point_add_and_update_are_valid_before_activation(BlitzStatus $status): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: $status);
        $blitzBefore = $assessment->blitzTask->getRawOriginal();
        $response = $this->blitzJson($teacher, 'POST', "/api/v1/teacher/assessments/{$assessment->id}/questions", $this->questionPayload(['points' => 0]))
            ->assertCreated()->assertJsonPath('data.total_possible_points', 0);
        $questionId = $response->json('data.questions.0.id');
        $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$questionId}", ['points' => 0.000001])
            ->assertOk()->assertJsonPath('data.total_possible_points', 0.000001);
        $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$questionId}", ['points' => 0])
            ->assertOk()->assertJsonPath('data.total_possible_points', 0);
        $this->assertSame('0.000000', $assessment->fresh()->total_possible_points);
        $this->assertBlitzStateUnchanged($assessment, $blitzBefore);
    }

    public function test_reorder_requires_exact_current_ids_and_preserves_configuration_points_and_no_op_timestamps(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic, status: BlitzStatus::Scheduled);
        $first = $this->persistedQuestion($assessment, ['points' => 0.1, 'position' => 1]);
        $second = $this->persistedQuestion($assessment, ['points' => 0.2, 'position' => 2]);
        $third = $this->persistedQuestion($assessment, ['points' => 0.000001, 'position' => 3]);
        $otherAssessment = $this->persistedBlitz($institution, $teacher, $topic);
        $foreignQuestion = $this->persistedQuestion($otherAssessment);
        $this->synchronizeQuestionTotal($assessment);
        $blitzBefore = $assessment->blitzTask->getRawOriginal();
        $childrenBefore = DB::table('question_true_false_answers')->orderBy('question_id')->get()->map(fn (object $row): array => (array) $row)->all();
        $this->travel(1)->hour();
        $uri = "/api/v1/teacher/assessments/{$assessment->id}/questions/reorder";
        $orderedIds = [$third->id, $first->id, $second->id];
        $response = $this->blitzJson($teacher, 'POST', $uri, ['question_ids' => $orderedIds])
            ->assertOk()->assertJsonPath('message', 'Questions reordered successfully.')
            ->assertJsonPath('data.total_possible_points', 0.300001);
        $this->assertSame($orderedIds, array_column($response->json('data.questions'), 'id'));
        $this->assertSame([1, 2, 3], array_column($response->json('data.questions'), 'position'));
        $this->assertSame($orderedIds, Question::query()->where('assessment_id', $assessment->id)->orderBy('position')->pluck('id')->all());
        $this->assertCompleteBlitzResource($response, $assessment, $teacher);
        $assessmentBefore = $assessment->fresh()->getRawOriginal();
        $questionsBefore = $this->questionRows($assessment);
        $this->travel(1)->hour();

        $noOpResponse = $this->blitzJson($teacher, 'POST', $uri, ['question_ids' => $orderedIds])->assertOk();
        $this->assertCompleteBlitzResource($noOpResponse, $assessment, $teacher);
        foreach ([
            [],
            [$third->id, $first->id],
            [$third->id, $first->id, $first->id],
            [$third->id, $first->id, $foreignQuestion->id],
            [$third->id, $first->id, '00000000-0000-0000-0000-000000000001'],
            [...$orderedIds, $foreignQuestion->id],
        ] as $invalidIds) {
            $this->blitzJson($teacher, 'POST', $uri, ['question_ids' => $invalidIds])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->assertSame($assessmentBefore, $assessment->fresh()->getRawOriginal());
        $this->assertSame($questionsBefore, $this->questionRows($assessment));
        $this->assertSame($childrenBefore, DB::table('question_true_false_answers')->orderBy('question_id')->get()->map(fn (object $row): array => (array) $row)->all());
        $this->assertSame('0.300001', $assessment->fresh()->total_possible_points);
        $this->assertBlitzStateUnchanged($assessment, $blitzBefore);
    }

    public function test_shared_question_requests_reject_protected_fields_and_invalid_configuration_without_writes(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $question = $this->persistedQuestion($assessment);
        $this->synchronizeQuestionTotal($assessment);
        $before = $assessment->fresh()->getRawOriginal();
        $questionsBefore = $this->questionRows($assessment);

        foreach ([
            ['total_possible_points' => 123], ['time_limit_seconds' => 30], ['client_key' => 'unapproved'],
            ['configuration' => ['correct_value' => 'true']], ['position' => 3],
        ] as $invalid) {
            $this->blitzJson($teacher, 'POST', "/api/v1/teacher/assessments/{$assessment->id}/questions", [
                ...$this->questionPayload(['position' => 2]), ...$invalid,
            ])->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        foreach ([['position' => 2], ['type' => 'open_written'], ['checking_mode' => 'manual'], ['total_possible_points' => 5]] as $invalid) {
            $this->blitzJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", $invalid)
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        }

        $this->blitzRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$question->id}", '{}')
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $assessment->fresh()->getRawOriginal());
        $this->assertSame($questionsBefore, $this->questionRows($assessment));
        $this->assertDatabaseCount('question_true_false_answers', 1);
    }

    public function test_parent_resource_dispatch_serializes_the_loaded_projection_without_queries(): void
    {
        [$institution, $teacher, , , $topic] = $this->blitzContext();
        $assessment = $this->persistedBlitz($institution, $teacher, $topic);
        $this->persistedQuestion($assessment);
        $this->synchronizeQuestionTotal($assessment);
        $projection = app(ShowTeacherAssessmentAuthoring::class)($teacher, $assessment);
        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $serialized = (new TeacherAssessmentAuthoringResource($projection))->response()->getData(true);
            $this->assertSame([], DB::getQueryLog());
            $this->assertSame($assessment->id, $serialized['data']['id']);
            $this->assertSame(true, $serialized['data']['questions'][0]['configuration']['correct_value']);
        } finally {
            DB::disableQueryLog();
            DB::flushQueryLog();
        }
    }

    /** @return iterable<string, array{BlitzStatus}> */
    public static function editableBlitzStatuses(): iterable
    {
        yield 'draft' => [BlitzStatus::Draft];
        yield 'scheduled' => [BlitzStatus::Scheduled];
    }

    private function assertCompleteBlitzResource(TestResponse $response, Assessment $assessment, User $teacher): void
    {
        $response->assertJsonPath('data.id', $assessment->id)
            ->assertJsonPath('data.topic_id', $assessment->topic_id)
            ->assertJsonPath('data.group_id', $assessment->topic->group_id)
            ->assertJsonPath('data.assignment_mode', 'group')
            ->assertJsonPath('data.student_ids', [])
            ->assertJsonPath('data.institution_timezone', 'Asia/Tashkent')
            ->assertJsonPath('data.attempt_policy', ['normal_attempts' => 1, 'max_additional_exception_attempts' => 1]);
        $this->assertSame([
            'id', 'topic_id', 'group_id', 'title', 'description', 'student_instructions', 'assignment_mode',
            'student_ids', 'total_possible_points', 'duration_seconds', 'scheduled_at', 'institution_timezone',
            'status', 'timer_start_mode_snapshot', 'attempt_policy', 'activated_at', 'synchronized_ends_at',
            'closed_at', 'archived_at', 'created_at', 'updated_at', 'questions',
        ], array_keys($response->json('data')));
        $detail = $this->blitzRaw($teacher, 'GET', "/api/v1/teacher/blitz/{$assessment->id}")->assertOk();
        $this->assertSame($detail->json('data'), $response->json('data'));
    }

    /** @param array<string, mixed> $blitzBefore */
    private function assertBlitzStateUnchanged(Assessment $assessment, array $blitzBefore): void
    {
        $this->assertSame($blitzBefore, $assessment->blitzTask->fresh()->getRawOriginal());
        $this->assertDatabaseMissing('assessment_students', ['assessment_id' => $assessment->id]);
        $this->assertDatabaseMissing('assessment_attempts', ['assessment_id' => $assessment->id]);
    }

    /** @return list<array<string, mixed>> */
    private function questionRows(Assessment $assessment): array
    {
        return Question::query()->where('assessment_id', $assessment->id)->orderBy('id')
            ->get()->map(fn (Question $question): array => $question->getRawOriginal())->all();
    }
}
