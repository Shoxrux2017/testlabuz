<?php

namespace Tests\Feature\Teacher;

use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptStatus;
use App\Enums\HomeworkStatus;
use App\Enums\TopicStatus;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionFillBlankAcceptedAnswer;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\TopicResultPair;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Teacher\Concerns\BuildsTeacherQuestionMutationContext;
use Tests\TestCase;

class TeacherQuestionEditingIntegrityTest extends TestCase
{
    use BuildsTeacherQuestionMutationContext;
    use RefreshDatabase;

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();

        parent::tearDown();
    }

    /**
     * @param  array<string, mixed>  $configuration
     * @param  array<string, mixed>  $reorderedConfiguration
     */
    #[DataProvider('positionBearingConfigurations')]
    public function test_position_bearing_configuration_order_is_a_semantic_no_op_and_preserves_all_timestamps_and_rows(
        string $type,
        string $prompt,
        array $configuration,
        array $reorderedConfiguration,
    ): void {
        CarbonImmutable::setTestNow('2026-09-03 09:00:00 UTC');
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework, [
            'type' => $type,
            'prompt' => $prompt,
            'configuration' => $configuration,
        ]);
        $this->synchronizeQuestionTotal($homework);
        $homework->refresh();
        $question->refresh();
        $homeworkTimestamp = $homework->updated_at->toJSON();
        $assignmentTimestamp = $homework->homeworkAssignment->updated_at->toJSON();
        $questionTimestamp = $question->updated_at->toJSON();
        $configurationRows = $this->positionBearingConfigurationRows($question);
        CarbonImmutable::setTestNow('2026-09-03 09:05:00 UTC');

        $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'configuration' => $reorderedConfiguration,
        ]);

        $response->assertOk()->assertJsonPath('message', 'Question updated successfully.');
        $question->refresh();
        $homework->refresh();
        $this->assertSame($questionTimestamp, $question->updated_at->toJSON());
        $this->assertSame($homeworkTimestamp, $homework->updated_at->toJSON());
        $this->assertSame($assignmentTimestamp, $homework->homeworkAssignment->fresh()?->updated_at->toJSON());
        $this->assertSame($configurationRows, $this->positionBearingConfigurationRows($question));
    }

    /** @return iterable<string, array{string, string, array<string, mixed>, array<string, mixed>}> */
    public static function positionBearingConfigurations(): iterable
    {
        yield 'single-choice options' => [
            'single_choice',
            'Choose one.',
            ['options' => [
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
                ['text' => 'Second', 'is_correct' => false, 'position' => 2],
            ]],
            ['options' => [
                ['text' => 'Second', 'is_correct' => false, 'position' => 2],
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
            ]],
        ];

        yield 'multiple-choice options' => [
            'multiple_choice',
            'Choose all.',
            ['options' => [
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
                ['text' => 'Second', 'is_correct' => true, 'position' => 2],
                ['text' => 'Third', 'is_correct' => false, 'position' => 3],
            ]],
            ['options' => [
                ['text' => 'Third', 'is_correct' => false, 'position' => 3],
                ['text' => 'First', 'is_correct' => true, 'position' => 1],
                ['text' => 'Second', 'is_correct' => true, 'position' => 2],
            ]],
        ];

        yield 'ordering items' => [
            'ordering',
            'Put these in order.',
            ['items' => [
                ['text' => 'First', 'correct_position' => 1],
                ['text' => 'Second', 'correct_position' => 2],
                ['text' => 'Third', 'correct_position' => 3],
            ]],
            ['items' => [
                ['text' => 'Second', 'correct_position' => 2],
                ['text' => 'Third', 'correct_position' => 3],
                ['text' => 'First', 'correct_position' => 1],
            ]],
        ];

        yield 'fill-in-blank blanks' => [
            'fill_in_blank',
            'Use {{first}} before {{second}}.',
            ['blanks' => [
                ['key' => 'first', 'position' => 1, 'accepted_answers' => ['alpha', 'one']],
                ['key' => 'second', 'position' => 2, 'accepted_answers' => ['beta', 'two']],
            ]],
            ['blanks' => [
                ['key' => 'second', 'position' => 2, 'accepted_answers' => ['beta', 'two']],
                ['key' => 'first', 'position' => 1, 'accepted_answers' => ['alpha', 'one']],
            ]],
        ];
    }

    public function test_matching_semantic_patch_no_op_ignores_correlation_keys_and_preserves_all_timestamps_and_rows(): void
    {
        CarbonImmutable::setTestNow('2026-09-03 10:00:00 UTC');
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework, [
            'type' => 'matching',
            'prompt' => 'Match.',
            'configuration' => ['pairs' => [
                ['client_key' => 'initial-key', 'left' => 'DNS', 'right' => 'Domain Name System'],
                ['client_key' => 'second-key', 'left' => 'IP', 'right' => 'Internet Protocol'],
            ]],
        ]);
        $this->synchronizeQuestionTotal($homework);
        $homework->refresh();
        $question->refresh();
        $homeworkTimestamp = $homework->updated_at->toJSON();
        $assignmentTimestamp = $homework->homeworkAssignment->updated_at->toJSON();
        $questionTimestamp = $question->updated_at->toJSON();
        $matchingRows = QuestionMatchingItem::query()
            ->where('question_id', $question->id)
            ->orderBy('position')
            ->orderBy('side')
            ->get()
            ->map(fn (QuestionMatchingItem $item): array => [
                $item->id,
                $item->match_key,
                $item->updated_at->toJSON(),
            ])->all();
        CarbonImmutable::setTestNow('2026-09-03 10:05:00 UTC');

        $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'type' => 'matching',
            'prompt' => 'Match.',
            'instructions' => null,
            'points' => 1.0,
            'checking_mode' => 'automatic',
            'configuration' => ['pairs' => [
                ['client_key' => 'different-a', 'left' => 'DNS', 'right' => 'Domain Name System'],
                ['client_key' => 'different-b', 'left' => 'IP', 'right' => 'Internet Protocol'],
            ]],
        ]);

        $response->assertOk()->assertJsonPath('message', 'Question updated successfully.');
        $question->refresh();
        $homework->refresh();
        $this->assertSame($questionTimestamp, $question->updated_at->toJSON());
        $this->assertSame($homeworkTimestamp, $homework->updated_at->toJSON());
        $this->assertSame($assignmentTimestamp, $homework->homeworkAssignment->fresh()?->updated_at->toJSON());
        $this->assertSame($matchingRows, QuestionMatchingItem::query()
            ->where('question_id', $question->id)
            ->orderBy('position')
            ->orderBy('side')
            ->get()
            ->map(fn (QuestionMatchingItem $item): array => [
                $item->id,
                $item->match_key,
                $item->updated_at->toJSON(),
            ])->all());
    }

    /** @return array<string, list<array<int, mixed>>> */
    private function positionBearingConfigurationRows(Question $question): array
    {
        return match ($question->type->value) {
            'single_choice', 'multiple_choice' => [
                'options' => QuestionChoiceOption::query()
                    ->where('question_id', $question->id)
                    ->orderBy('id')
                    ->get()
                    ->map(fn (QuestionChoiceOption $option): array => [
                        $option->id,
                        $option->created_at->toJSON(),
                        $option->updated_at->toJSON(),
                    ])->all(),
            ],
            'ordering' => [
                'items' => QuestionOrderingItem::query()
                    ->where('question_id', $question->id)
                    ->orderBy('id')
                    ->get()
                    ->map(fn (QuestionOrderingItem $item): array => [
                        $item->id,
                        $item->created_at->toJSON(),
                        $item->updated_at->toJSON(),
                    ])->all(),
            ],
            'fill_in_blank' => $this->fillBlankConfigurationRows($question),
        };
    }

    /** @return array<string, list<array<int, mixed>>> */
    private function fillBlankConfigurationRows(Question $question): array
    {
        $blanks = QuestionFillBlank::query()
            ->where('question_id', $question->id)
            ->orderBy('id')
            ->get();

        return [
            'blanks' => $blanks->map(fn (QuestionFillBlank $blank): array => [
                $blank->id,
                $blank->created_at->toJSON(),
                $blank->updated_at->toJSON(),
            ])->all(),
            'accepted_answers' => QuestionFillBlankAcceptedAnswer::query()
                ->whereIn('blank_id', $blanks->pluck('id'))
                ->orderBy('id')
                ->get()
                ->map(fn (QuestionFillBlankAcceptedAnswer $answer): array => [
                    $answer->id,
                    $answer->created_at->toJSON(),
                    $answer->updated_at->toJSON(),
                ])->all(),
        ];
    }

    public function test_no_op_reorder_preserves_question_assessment_homework_and_total_state(): void
    {
        CarbonImmutable::setTestNow('2026-09-03 11:00:00 UTC');
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $first = $this->persistedQuestion($homework, ['position' => 1, 'points' => 0.1]);
        $second = $this->persistedQuestion($homework, ['position' => 2, 'points' => 0.2]);
        $this->synchronizeQuestionTotal($homework);
        $homework->refresh();
        $first->refresh();
        $second->refresh();
        $timestamps = [
            $homework->updated_at->toJSON(),
            $homework->homeworkAssignment->updated_at->toJSON(),
            $first->updated_at->toJSON(),
            $second->updated_at->toJSON(),
        ];
        CarbonImmutable::setTestNow('2026-09-03 11:05:00 UTC');

        $this->homeworkJson(
            $teacher,
            'POST',
            "/api/v1/teacher/assessments/{$homework->id}/questions/reorder",
            ['question_ids' => [$first->id, $second->id]],
        )->assertOk()->assertJsonPath('data.total_possible_points', 0.3);

        $homework->refresh();
        $this->assertSame($timestamps, [
            $homework->updated_at->toJSON(),
            $homework->homeworkAssignment->fresh()?->updated_at->toJSON(),
            $first->fresh()?->updated_at->toJSON(),
            $second->fresh()?->updated_at->toJSON(),
        ]);
        $this->assertSame('0.300000', $homework->total_possible_points);
    }

    public function test_active_homework_allows_safe_edits_but_rejects_zero_scoreable_result_atomically(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext(TopicStatus::Active);
        $homework = $this->persistedHomework(
            $institution,
            $teacher,
            $topic,
            status: HomeworkStatus::Active,
        );
        $first = $this->persistedQuestion($homework, ['prompt' => 'First', 'points' => 1, 'position' => 1]);
        $lastScoreable = $this->persistedQuestion($homework, ['prompt' => 'Last', 'points' => 2, 'position' => 2]);
        $this->synchronizeQuestionTotal($homework);

        $this->homeworkRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$first->id}", '')
            ->assertOk()->assertJsonPath('data.total_possible_points', 2);
        $this->homeworkJson(
            $teacher,
            'POST',
            "/api/v1/teacher/assessments/{$homework->id}/questions",
            $this->questionPayload(['prompt' => 'Zero point', 'points' => 0, 'position' => 2]),
        )->assertCreated()->assertJsonPath('data.total_possible_points', 2);

        $update = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$lastScoreable->id}", [
            'points' => 0,
        ]);
        $update->assertConflict()
            ->assertJsonPath('code', 'assessment_has_no_scoreable_points')
            ->assertJsonPath('message', 'The assessment must contain at least one scoreable point.')
            ->assertJsonPath('errors', []);
        $this->assertDatabaseHas('questions', ['id' => $lastScoreable->id, 'points' => '2.000000']);
        $this->assertSame('2.000000', $homework->fresh()?->total_possible_points);

        $delete = $this->homeworkRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$lastScoreable->id}", '');
        $delete->assertConflict()->assertJsonPath('code', 'assessment_has_no_scoreable_points');
        $this->assertDatabaseHas('questions', ['id' => $lastScoreable->id]);
        $this->assertDatabaseCount('questions', 2);
    }

    public function test_any_attempt_status_locks_every_question_mutation_without_writes(): void
    {
        foreach ([
            AssessmentAttemptStatus::InProgress,
            AssessmentAttemptStatus::Submitted,
            AssessmentAttemptStatus::Checked,
        ] as $status) {
            [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
            $homework = $this->persistedHomework($institution, $teacher, $topic);
            $question = $this->persistedQuestion($homework);
            $this->synchronizeQuestionTotal($homework);
            $student = $this->eligibleStudent($institution, $admin, $group);
            $recipient = AssessmentStudent::factory()->create([
                'institution_id' => $institution->id,
                'assessment_id' => $homework->id,
                'student_id' => $student->id,
                'assignment_source' => AssessmentAssignmentSource::Group,
                'assigned_by_user_id' => $teacher->id,
            ]);
            AssessmentAttempt::factory()->create([
                'institution_id' => $institution->id,
                'assessment_id' => $homework->id,
                'assessment_student_id' => $recipient->id,
                'student_id' => $student->id,
                'status' => $status,
                'possible_points' => '1.000000',
            ]);
            $originalTimestamp = $question->fresh()?->updated_at->toJSON();

            foreach ([
                ['POST', "/api/v1/teacher/assessments/{$homework->id}/questions", $this->questionPayload(['position' => 2])],
                ['PATCH', "/api/v1/teacher/questions/{$question->id}", ['prompt' => 'Blocked']],
                ['DELETE', "/api/v1/teacher/questions/{$question->id}", null],
                ['POST', "/api/v1/teacher/assessments/{$homework->id}/questions/reorder", ['question_ids' => [$question->id]]],
            ] as [$method, $uri, $payload]) {
                $response = $payload === null
                    ? $this->homeworkRaw($teacher, $method, $uri, '')
                    : $this->homeworkJson($teacher, $method, $uri, $payload);
                $response->assertConflict()->assertJsonPath('code', 'business_conflict');
            }

            $this->assertSame(1, $homework->questions()->count());
            $this->assertDatabaseHas('questions', ['id' => $question->id, 'prompt' => 'Is this statement true?']);
            $this->assertSame($originalTimestamp, $question->fresh()?->updated_at->toJSON());
        }
    }

    public function test_locked_result_pair_precedes_attempt_lock_and_returns_the_narrow_conflict(): void
    {
        [$institution, $teacher, $admin, $group, $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework);
        TopicResultPair::factory()->create([
            'institution_id' => $institution->id,
            'topic_id' => $topic->id,
            'homework_assessment_id' => $homework->id,
            'designated_by_user_id' => $teacher->id,
            'designated_at' => now()->subMinutes(2),
            'cohort_snapshotted_at' => now()->subMinute(),
            'locked_at' => now(),
        ]);

        $response = $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'prompt' => 'Blocked',
        ]);

        $response->assertConflict()
            ->assertJsonPath('code', 'result_pair_locked')
            ->assertJsonPath('message', 'The official result pair is locked.')
            ->assertJsonPath('errors', []);
        $this->assertDatabaseHas('questions', ['id' => $question->id, 'prompt' => 'Is this statement true?']);

        $student = $this->eligibleStudent($institution, $admin, $group);
        $recipient = AssessmentStudent::factory()->create([
            'institution_id' => $institution->id,
            'assessment_id' => $homework->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $teacher->id,
        ]);
        AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient->id,
            'possible_points' => '1.000000',
        ]);
        $this->homeworkRaw($teacher, 'DELETE', "/api/v1/teacher/questions/{$question->id}", '')
            ->assertConflict()->assertJsonPath('code', 'result_pair_locked');
        $this->assertDatabaseHas('questions', ['id' => $question->id]);
    }

    public function test_topic_and_homework_lifecycle_conflicts_precede_pair_and_attempt_checks(): void
    {
        foreach ([
            [TopicStatus::Closed, HomeworkStatus::Draft, 'topic_not_editable'],
            [TopicStatus::Archived, HomeworkStatus::Draft, 'topic_not_editable'],
            [TopicStatus::Draft, HomeworkStatus::Closed, 'task_closed'],
            [TopicStatus::Draft, HomeworkStatus::Archived, 'task_archived'],
        ] as [$topicStatus, $homeworkStatus, $code]) {
            [$institution, $teacher, , , $topic] = $this->homeworkContext($topicStatus);
            $homework = $this->persistedHomework(
                $institution,
                $teacher,
                $topic,
                status: $homeworkStatus,
            );
            $question = $this->persistedQuestion($homework);
            TopicResultPair::factory()->create([
                'institution_id' => $institution->id,
                'topic_id' => $topic->id,
                'homework_assessment_id' => $homework->id,
                'designated_by_user_id' => $teacher->id,
                'designated_at' => now()->subMinutes(2),
                'cohort_snapshotted_at' => now()->subMinute(),
                'locked_at' => now(),
            ]);

            $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
                'prompt' => 'Blocked',
            ])->assertConflict()->assertJsonPath('code', $code);
            $this->assertDatabaseHas('questions', ['id' => $question->id, 'prompt' => 'Is this statement true?']);
        }
    }

    public function test_fill_blank_prompt_change_is_validated_against_the_persisted_complete_configuration(): void
    {
        [$institution, $teacher, , , $topic] = $this->homeworkContext();
        $homework = $this->persistedHomework($institution, $teacher, $topic);
        $question = $this->persistedQuestion($homework, [
            'type' => 'fill_in_blank',
            'prompt' => 'DNS maps {{host}}.',
            'configuration' => ['blanks' => [
                ['key' => 'host', 'position' => 1, 'accepted_answers' => ['domain name']],
            ]],
        ]);

        $this->homeworkJson($teacher, 'PATCH', "/api/v1/teacher/questions/{$question->id}", [
            'prompt' => 'No placeholder remains.',
        ])->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertDatabaseHas('questions', ['id' => $question->id, 'prompt' => 'DNS maps {{host}}.']);
        $this->assertDatabaseCount('question_fill_blanks', 1);
        $this->assertDatabaseCount('question_fill_blank_accepted_answers', 1);
    }
}
