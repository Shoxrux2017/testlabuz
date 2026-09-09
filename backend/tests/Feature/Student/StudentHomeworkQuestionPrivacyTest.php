<?php

namespace Tests\Feature\Student;

use App\Enums\FileExtension;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Assessment;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\InstitutionSetting;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionFillBlankAcceptedAnswer;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\QuestionShortAcceptedAnswer;
use App\Models\QuestionTrueFalseAnswer;
use App\Models\User;
use App\Support\Student\StudentQuestionAnswerUi;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use LogicException;
use Tests\TestCase;

class StudentHomeworkQuestionPrivacyTest extends TestCase
{
    use RefreshDatabase;

    private const FORBIDDEN_KEYS = [
        'is_correct', 'correct_value', 'accepted_answers', 'correct_position',
        'match_key', 'checking_mode', 'configuration', 'client_key',
    ];

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-09 12:00:00', 'UTC'));
    }

    public function test_all_nine_question_types_return_exact_safe_shapes_and_never_query_protected_configuration(): void
    {
        [$student, $homework] = $this->assignedHomework(maxFileMb: 7);
        $questions = $this->allQuestionTypes($homework);

        [$response, $queries] = $this->captureRead($student, $homework);
        $response->assertOk()->assertJsonPath('data.score_visible', false)->assertJsonCount(9, 'data.questions');
        $this->assertNoForbiddenKeys($response->json());
        $this->assertSafeQuestionQueries($queries);

        $responseQuestions = $response->json('data.questions');
        $rawQuestions = json_decode($response->getContent())->data->questions;

        foreach (array_values($questions) as $index => $question) {
            $actual = $responseQuestions[$index];
            $this->assertSame(['id', 'type', 'prompt', 'instructions', 'points', 'position', 'answer_ui'], array_keys($actual));
            $this->assertSame($question->id, $actual['id']);
            $this->assertSame($question->type->value, $actual['type']);
            $this->assertSame($question->prompt, $actual['prompt']);
            $this->assertNull($actual['instructions']);
            $this->assertEquals(1.0, $actual['points']);
            $this->assertSame($question->position, $actual['position']);
            $this->assertSame($this->expectedAnswerUi($question, 7), $actual['answer_ui']);

            if (in_array($question->type, [QuestionType::TrueFalse, QuestionType::ShortWritten, QuestionType::OpenWritten], true)) {
                $this->assertInstanceOf(\stdClass::class, $rawQuestions[$index]->answer_ui);
                $this->assertSame([], get_object_vars($rawQuestions[$index]->answer_ui));
            }
        }

        foreach (['short-answer-secret-96174', 'fill-answer-secret-58162', '71000000-0000-4000-8000-000000000'] as $secret) {
            $this->assertStringNotContainsString($secret, $response->getContent());
        }

        $multiple = collect($responseQuestions)->firstWhere('type', 'multiple_choice')['answer_ui'];
        $this->assertCount(4, $multiple['options']);
        $this->assertSame(2, $multiple['max_selections']);
        $this->assertSame(['options', 'max_selections'], array_keys($multiple));
    }

    public function test_protected_answer_changes_cannot_change_student_question_projection(): void
    {
        [$student, $homework] = $this->assignedHomework();
        $questions = $this->allQuestionTypes($homework);
        $before = $this->read($student, $homework)->assertOk()->json('data.questions');

        QuestionTrueFalseAnswer::query()->where('question_id', $questions['true_false']->id)->update(['correct_value' => false]);
        QuestionShortAcceptedAnswer::query()->where('question_id', $questions['short_written']->id)
            ->update(['accepted_text' => 'changed-short-secret-33881']);
        $blankIds = QuestionFillBlank::query()->where('question_id', $questions['fill_in_blank']->id)->pluck('id');
        QuestionFillBlankAcceptedAnswer::query()->whereIn('blank_id', $blankIds)
            ->update(['accepted_text' => 'changed-fill-secret-93662']);
        $questions['short_written']->update(['checking_mode' => QuestionCheckingMode::Manual]);

        foreach (QuestionMatchingItem::query()->where('question_id', $questions['matching']->id)->get() as $item) {
            $item->update(['match_key' => $this->uuid('72000000', $item->position)]);
        }

        $after = $this->read($student, $homework)->assertOk();
        $this->assertSame($before, $after->json('data.questions'));
        $this->assertNoForbiddenKeys($after->json());
        $this->assertStringNotContainsString('changed-short-secret-33881', $after->getContent());
        $this->assertStringNotContainsString('changed-fill-secret-93662', $after->getContent());
    }

    public function test_matching_sides_follow_independent_hash_order_instead_of_persisted_pair_positions(): void
    {
        [$student, $homework] = $this->assignedHomework();
        $question = $this->allQuestionTypes($homework)['matching'];
        $matchingUi = collect($this->read($student, $homework)->assertOk()->json('data.questions'))
            ->firstWhere('id', $question->id)['answer_ui'];

        foreach (['left', 'right'] as $side) {
            $items = QuestionMatchingItem::query()->where('question_id', $question->id)->where('side', $side)
                ->orderBy('position')->get();
            $expected = $this->safeOrder($items->pluck('id')->all(), 'matching-'.$side, $question->id);
            $actual = array_column($matchingUi[$side.'_items'], 'id');
            $this->assertSame($expected, $actual);
            $this->assertNotSame($items->pluck('id')->all(), $actual);
        }

        $this->assertSame(['left_items', 'right_items'], array_keys($matchingUi));
    }

    public function test_ordering_display_stays_identical_when_correct_sequence_equals_or_differs_from_hash_order(): void
    {
        [$student, $homework] = $this->assignedHomework();
        $question = $this->allQuestionTypes($homework)['ordering'];
        $ids = QuestionOrderingItem::query()->where('question_id', $question->id)->orderBy('id')->pluck('id')->all();
        $expected = $this->safeOrder($ids, 'ordering', $question->id);
        $this->assertNotSame($ids, $expected);

        foreach ([$expected, array_reverse($expected)] as $correctOrder) {
            $this->setCorrectOrder($question, $correctOrder);
            [$response, $queries] = $this->captureRead($student, $homework);
            $response->assertOk();
            $this->assertSafeQuestionQueries($queries);
            $orderingUi = collect($response->json('data.questions'))->firstWhere('id', $question->id)['answer_ui'];
            $this->assertSame(['items'], array_keys($orderingUi));
            $this->assertSame($expected, array_column($orderingUi['items'], 'id'));
        }
    }

    public function test_file_metadata_uses_the_platform_extensions_and_effective_institution_limit(): void
    {
        [$student, $homework] = $this->assignedHomework(maxFileMb: 15);
        $this->question($homework, QuestionType::FileBased, 1);

        foreach ([15, 1, 9] as $maxFileMb) {
            InstitutionSetting::query()->where('institution_id', $student->institution_id)
                ->update(['student_submission_max_mb' => $maxFileMb]);

            $this->assertSame([
                'allowed_extensions' => FileExtension::values(),
                'max_size_bytes' => min(15, $maxFileMb) * 1_048_576,
            ], $this->read($student, $homework)->assertOk()->json('data.questions.0.answer_ui'));
        }
    }

    public function test_missing_institution_setting_is_an_invariant_failure_without_a_file_limit_fallback(): void
    {
        [$student, $homework] = $this->assignedHomework();
        $this->question($homework, QuestionType::FileBased, 1);
        InstitutionSetting::query()->where('institution_id', $student->institution_id)->delete();

        $this->withoutExceptionHandling();
        $this->expectException(LogicException::class);
        $this->read($student, $homework);
    }

    public function test_multiple_choice_without_a_correct_option_fails_as_an_invariant(): void
    {
        [$student, $homework] = $this->assignedHomework();
        $question = $this->question($homework, QuestionType::MultipleChoice, 1);
        QuestionChoiceOption::factory()->create(['question_id' => $question->id, 'is_correct' => false]);

        $this->withoutExceptionHandling();
        $this->expectException(LogicException::class);
        $this->read($student, $homework);
    }

    public function test_projection_requires_explicitly_loaded_question_relations_and_does_not_query_them(): void
    {
        $question = (new Question)->forceFill([
            'id' => $this->uuid('40000000', 1),
            'type' => QuestionType::SingleChoice,
        ]);

        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            (new StudentQuestionAnswerUi)->project($question, 15 * 1_048_576);
            $this->fail('Missing eager-loaded relation must fail.');
        } catch (LogicException) {
            $this->assertSame([], DB::getQueryLog());
        } finally {
            DB::disableQueryLog();
        }
    }

    public function test_detail_typed_relation_query_count_stays_fixed_as_question_count_grows(): void
    {
        [$student, $homework] = $this->assignedHomework();
        $this->allQuestionTypes($homework);
        [$smallResponse, $smallQueries] = $this->captureRead($student, $homework);
        $smallResponse->assertOk()->assertJsonCount(9, 'data.questions');

        for ($batch = 1; $batch <= 4; $batch++) {
            $this->allQuestionTypes($homework, $batch * 100);
        }

        [$largeResponse, $largeQueries] = $this->captureRead($student, $homework);
        $largeResponse->assertOk()->assertJsonCount(45, 'data.questions');
        $this->assertSafeQuestionQueries($largeQueries);

        $smallCount = count($this->typedQueries($smallQueries));
        $largeCount = count($this->typedQueries($largeQueries));
        $this->assertGreaterThan(0, $smallCount);
        $this->assertSame($smallCount, $largeCount);
        $this->assertLessThanOrEqual(4, $largeCount);
    }

    /** @return array{User, Assessment} */
    private function assignedHomework(int $maxFileMb = 15): array
    {
        $institution = Institution::factory()->create();
        InstitutionSetting::factory()->create([
            'institution_id' => $institution->id,
            'student_submission_max_mb' => $maxFileMb,
        ]);
        $student = User::factory()->student($institution)->create(['must_change_password' => false]);
        $homework = Assessment::factory()->homework()->create(['institution_id' => $institution->id]);
        HomeworkAssignment::factory()->active()->create([
            'assessment_id' => $homework->id,
            'institution_id' => $institution->id,
            'deadline_at' => null,
        ]);
        AssessmentStudent::factory()->create([
            'assessment_id' => $homework->id,
            'institution_id' => $institution->id,
            'student_id' => $student->id,
            'assigned_by_user_id' => $homework->teacher_id,
        ]);

        return [$student, $homework];
    }

    /** @return array<string, Question> */
    private function allQuestionTypes(Assessment $homework, int $offset = 0): array
    {
        $questions = [];

        foreach (QuestionType::cases() as $index => $type) {
            $question = $this->question($homework, $type, $offset + $index + 1);
            $questions[$type->value] = $question;

            if (in_array($type, [QuestionType::SingleChoice, QuestionType::MultipleChoice], true)) {
                foreach ([3, 1, 4, 2] as $position) {
                    QuestionChoiceOption::factory()->create([
                        'id' => $this->uuid('50000000', ($offset + $index + 1) * 100 + $position),
                        'question_id' => $question->id,
                        'institution_id' => $homework->institution_id,
                        'option_text' => 'Visible option '.$position,
                        'position' => $position,
                        'is_correct' => $position === 2 || ($type === QuestionType::MultipleChoice && $position === 4),
                    ]);
                }
            } elseif ($type === QuestionType::TrueFalse) {
                QuestionTrueFalseAnswer::factory()->create(['question_id' => $question->id, 'correct_value' => true]);
            } elseif ($type === QuestionType::ShortWritten) {
                QuestionShortAcceptedAnswer::factory()->create([
                    'question_id' => $question->id, 'accepted_text' => 'short-answer-secret-96174',
                ]);
            } elseif ($type === QuestionType::Matching) {
                foreach (range(1, 5) as $position) {
                    foreach (QuestionMatchingSide::cases() as $sideIndex => $side) {
                        QuestionMatchingItem::factory()->create([
                            'id' => $this->uuid('50000000', ($offset + 7) * 100 + $position * 2 + $sideIndex),
                            'question_id' => $question->id,
                            'institution_id' => $homework->institution_id,
                            'side' => $side,
                            'item_text' => $side->value.' visible '.$position,
                            'position' => $position,
                            'match_key' => $this->uuid('71000000', $position),
                        ]);
                    }
                }
            } elseif ($type === QuestionType::Ordering) {
                foreach (range(1, 5) as $position) {
                    QuestionOrderingItem::factory()->create([
                        'id' => $this->uuid('50000000', ($offset + 8) * 100 + $position),
                        'question_id' => $question->id,
                        'institution_id' => $homework->institution_id,
                        'item_text' => 'Visible ordering item '.$position,
                        'correct_position' => $position,
                    ]);
                }
            } elseif ($type === QuestionType::FillInBlank) {
                foreach ([2 => 'ip_address', 1 => 'dns_name'] as $position => $key) {
                    $blank = QuestionFillBlank::factory()->create([
                        'id' => $this->uuid('50000000', ($offset + 9) * 100 + $position),
                        'question_id' => $question->id,
                        'institution_id' => $homework->institution_id,
                        'blank_key' => $key,
                        'position' => $position,
                    ]);
                    QuestionFillBlankAcceptedAnswer::factory()->create([
                        'blank_id' => $blank->id, 'accepted_text' => 'fill-answer-secret-58162',
                    ]);
                }
            }
        }

        return $questions;
    }

    private function question(Assessment $homework, QuestionType $type, int $position): Question
    {
        return Question::factory()->create([
            'id' => $this->uuid('40000000', $position),
            'assessment_id' => $homework->id,
            'institution_id' => $homework->institution_id,
            'type' => $type,
            'prompt' => $type === QuestionType::FillInBlank ? 'Enter {{dns_name}} and {{ip_address}}.' : 'Visible '.$type->value.' prompt',
            'instructions' => null,
            'points' => '1.000000',
            'position' => $position,
            'checking_mode' => in_array($type, [QuestionType::OpenWritten, QuestionType::FileBased], true)
                ? QuestionCheckingMode::Manual : QuestionCheckingMode::Automatic,
        ]);
    }

    private function expectedAnswerUi(Question $question, int $maxFileMb): array
    {
        if (in_array($question->type, [QuestionType::SingleChoice, QuestionType::MultipleChoice], true)) {
            $expected = ['options' => QuestionChoiceOption::query()->where('question_id', $question->id)->orderBy('position')->orderBy('id')
                ->get()->map(fn (QuestionChoiceOption $option): array => ['id' => $option->id, 'text' => $option->option_text])->all()];

            if ($question->type === QuestionType::MultipleChoice) {
                $expected['max_selections'] = 2;
            }

            return $expected;
        }

        if ($question->type === QuestionType::FileBased) {
            return ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx'], 'max_size_bytes' => $maxFileMb * 1_048_576];
        }

        if ($question->type === QuestionType::Matching) {
            $expected = [];

            foreach (['left', 'right'] as $side) {
                $items = QuestionMatchingItem::query()->where('question_id', $question->id)->where('side', $side)->get()->keyBy('id');
                $expected[$side.'_items'] = array_map(
                    fn (string $id): array => ['id' => $id, 'text' => $items[$id]->item_text],
                    $this->safeOrder($items->keys()->all(), 'matching-'.$side, $question->id),
                );
            }

            return $expected;
        }

        if ($question->type === QuestionType::Ordering) {
            $items = QuestionOrderingItem::query()->where('question_id', $question->id)->get()->keyBy('id');

            return ['items' => array_map(
                fn (string $id): array => ['id' => $id, 'text' => $items[$id]->item_text],
                $this->safeOrder($items->keys()->all(), 'ordering', $question->id),
            )];
        }

        if ($question->type === QuestionType::FillInBlank) {
            return ['blanks' => QuestionFillBlank::query()->where('question_id', $question->id)->orderBy('position')->orderBy('id')
                ->get()->map(fn (QuestionFillBlank $blank): array => [
                    'id' => $blank->id, 'key' => $blank->blank_key, 'position' => $blank->position,
                ])->all()];
        }

        return [];
    }

    private function setCorrectOrder(Question $question, array $ids): void
    {
        QuestionOrderingItem::query()->where('question_id', $question->id)
            ->update(['correct_position' => DB::raw('correct_position + 100')]);

        foreach ($ids as $index => $id) {
            QuestionOrderingItem::query()->whereKey($id)->update(['correct_position' => $index + 1]);
        }
    }

    /** @return list<string> */
    private function safeOrder(array $ids, string $prefix, string $questionId): array
    {
        $hashes = [];

        foreach ($ids as $id) {
            $hashes[$id] = hash('sha256', $prefix.'|'.$questionId.'|'.$id);
        }

        usort($ids, fn (string $left, string $right): int => [$hashes[$left], $left] <=> [$hashes[$right], $right]);

        return $ids;
    }

    private function assertNoForbiddenKeys(array $payload): void
    {
        foreach ($payload as $key => $value) {
            $this->assertNotContains($key, self::FORBIDDEN_KEYS);

            if (is_array($value)) {
                $this->assertNoForbiddenKeys($value);
            }
        }
    }

    private function assertSafeQuestionQueries(array $queries): void
    {
        $sql = strtolower(implode("\n", $queries));

        foreach (['question_true_false_answers', 'question_short_accepted_answers', 'question_fill_blank_accepted_answers', 'correct_value', 'correct_position', 'match_key', 'checking_mode'] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $sql);
        }

        foreach ($this->typedQueries($queries) as $query) {
            $this->assertDoesNotMatchRegularExpression('/select\s+(?:"?\w+"?\.)?\*/i', $query);
        }

        $this->assertStringNotContainsString('attempt_answers', $sql);
    }

    private function typedQueries(array $queries): array
    {
        return array_values(array_filter($queries, fn (string $query): bool => preg_match(
            '/from\s+"?question_(?:choice_options|matching_items|ordering_items|fill_blanks)"?/i', $query,
        ) === 1));
    }

    /** @return array{TestResponse, list<string>} */
    private function captureRead(User $student, Assessment $homework): array
    {
        DB::flushQueryLog();
        DB::enableQueryLog();

        try {
            $response = $this->read($student, $homework);
            $queries = array_column(DB::getQueryLog(), 'query');
        } finally {
            DB::disableQueryLog();
        }

        return [$response, $queries];
    }

    private function read(User $student, Assessment $homework): TestResponse
    {
        $response = $this->call('GET', '/api/v1/student/homework/'.$homework->id, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('student-homework-privacy-test')->plainTextToken,
        ]);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function uuid(string $prefix, int $number): string
    {
        return $prefix.'-0000-4000-8000-'.str_pad((string) $number, 12, '0', STR_PAD_LEFT);
    }
}
