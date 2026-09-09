<?php

namespace Tests\Feature\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\AnswerBooleanValue;
use App\Models\AnswerFile;
use App\Models\AttemptAnswer;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkAnswerContext;
use Tests\TestCase;

class StudentHomeworkAnswerSaveApiTest extends TestCase
{
    use BuildsStudentHomeworkAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
    }

    public function test_exact_put_route_uses_the_student_middleware_and_requires_authentication(): void
    {
        $routes = collect(Route::getRoutes())->filter(fn ($route): bool => $route->uri() === 'api/v1/student/attempts/{attempt}/answers/{question}');
        $this->assertCount(1, $routes);
        $this->assertSame(['PUT'], $routes->sole()->methods());
        $this->assertSame(['api', 'auth:sanctum', 'active.account', 'password.changed', 'role:student'], $routes->sole()->middleware());
        $this->putJson('/api/v1/student/attempts/'.Str::uuid().'/answers/'.Str::uuid(), ['type' => 'true_false', 'value' => true])
            ->assertUnauthorized()->assertJsonPath('code', 'authentication_required');
    }

    public function test_all_eight_types_save_replace_and_resume_canonical_normalized_answers_without_scoring_or_attempt_mutation(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $attemptBefore = $attempt->getAttributes();
        $expected = [];
        $questions = [];
        foreach (['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'matching', 'ordering', 'fill_in_blank'] as $index => $type) {
            $questions[] = $this->answerQuestion($homework, $type, $index + 1);
        }
        $this->answerQuestion($homework, 'file_based', 9);

        foreach (array_reverse($questions) as $question) {
            $payload = $this->answerPayload($question);
            $this->answerRequest($student, $attempt, $question, $payload)->assertOk()->assertExactJson([
                'data' => ['question_id' => $question->id, 'type' => $question->type->value,
                    'answer' => $this->canonicalAnswer($question, $payload), 'updated_at' => now()->format('Y-m-d\TH:i:s\Z')],
            ]);
            $parent = AttemptAnswer::query()->where('attempt_id', $attempt->id)->where('question_id', $question->id)->sole();
            $this->assertStoredAnswer($parent, $question, $payload);
            $identityBefore = [$parent->id, $parent->getRawOriginal('created_at')];

            $snapshot = $this->answerSnapshot();
            $same = $payload;
            foreach (['selected_option_ids', 'pairs', 'items', 'values'] as $key) {
                if (isset($same[$key])) {
                    $same[$key] = array_reverse($same[$key]);
                }
            }
            $this->travel(1)->seconds();
            DB::flushQueryLog();
            DB::enableQueryLog();
            try {
                $this->answerRequest($student, $attempt, $question, $same)->assertOk()
                    ->assertJsonPath('data.answer', $this->canonicalAnswer($question, $payload));
                $this->assertNoAnswerWrites(DB::getQueryLog());
            } finally {
                DB::disableQueryLog();
            }
            $this->assertSame($snapshot, $this->answerSnapshot());

            $replacement = $this->answerPayload($question, true);
            $response = $this->answerRequest($student, $attempt, $question, $replacement)->assertOk()->assertExactJson([
                'data' => ['question_id' => $question->id, 'type' => $question->type->value,
                    'answer' => $this->canonicalAnswer($question, $replacement), 'updated_at' => now()->format('Y-m-d\TH:i:s\Z')],
            ]);
            $parent->refresh();
            $this->assertSame($identityBefore, [$parent->id, $parent->getRawOriginal('created_at')]);
            $this->assertTrue($parent->updated_at->equalTo(now()));
            $this->assertStoredAnswer($parent, $question, $replacement);
            $this->assertNoAnswerSecrets($response->json());
            $expected[$question->position] = $response->json('data');
        }

        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->assertDatabaseCount('attempt_answers', 8);
        $this->assertDatabaseCount('idempotency_records', 0);
        ksort($expected);
        $expected = array_values($expected);
        DB::flushQueryLog();
        DB::enableQueryLog();
        try {
            $read = $this->answerHttp($student, 'GET', '/api/v1/student/attempts/'.$attempt->id)->assertOk()
                ->assertJsonPath('data.answers', $expected);
            $this->assertSafeAnswerQueries(DB::getQueryLog());
        } finally {
            DB::disableQueryLog();
        }
        $resume = $this->answerHttp($student, 'POST', '/api/v1/student/homework/'.$homework->assessment_id.'/attempts',
            headers: ['HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid()])->assertOk()->assertJsonPath('data.answers', $expected);
        $this->assertNoAnswerSecrets($read->json('data.answers'));
        $this->assertNoAnswerSecrets($resume->json('data.answers'));
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    #[DataProvider('clearableTypes')]
    public function test_supported_clear_removes_typed_children_then_parent_and_never_changes_the_attempt(string $type): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, $type);
        $attemptBefore = $attempt->getAttributes();
        $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        $this->travel(1)->seconds();
        $this->answerRequest($student, $attempt, $question, $this->clearPayload($question))->assertOk()->assertExactJson([
            'data' => ['question_id' => $question->id, 'type' => $type, 'answer' => null, 'updated_at' => null],
        ]);
        foreach ($this->answerSnapshot() as $rows) {
            $this->assertSame([], $rows);
        }
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->answerHttp($student, 'GET', '/api/v1/student/attempts/'.$attempt->id)->assertOk()->assertJsonPath('data.answers', []);
    }

    public static function clearableTypes(): array
    {
        return array_map(fn (string $type): array => [$type], ['multiple_choice', 'short_written', 'open_written', 'matching', 'ordering', 'fill_in_blank']);
    }

    #[DataProvider('corruptAnswers')]
    public function test_existing_corrupt_answer_is_never_compared_replaced_cleared_or_repaired(string $type, string $corruption): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, $type);
        $payload = $this->answerPayload($question);
        $this->answerRequest($student, $attempt, $question, $payload)->assertOk();
        $answer = AttemptAnswer::query()->where('attempt_id', $attempt->id)->sole();
        $foreignIds = [];
        if ($corruption === 'wrong question') {
            $other = $this->answerQuestion($homework, $type, 2);
            [$table, $column, $foreignId] = match ($type) {
                'single_choice', 'multiple_choice' => ['answer_choice_selections', 'option_id', QuestionChoiceOption::query()->where('question_id', $other->id)->firstOrFail()->id],
                'matching' => ['answer_matching_pairs', 'left_item_id', QuestionMatchingItem::query()->where('question_id', $other->id)->where('side', 'left')->firstOrFail()->id],
                'ordering' => ['answer_ordering_items', 'ordering_item_id', QuestionOrderingItem::query()->where('question_id', $other->id)->firstOrFail()->id],
                'fill_in_blank' => ['answer_fill_blank_values', 'blank_id', QuestionFillBlank::query()->where('question_id', $other->id)->firstOrFail()->id],
            };
            $row = DB::table($table)->where('answer_id', $answer->id)->first();
            DB::table($table)->where('answer_id', $answer->id)->where($column, $row->{$column})->update([$column => $foreignId]);
            $foreignIds[] = $foreignId;
        } elseif ($corruption === 'too many selections') {
            $selected = DB::table('answer_choice_selections')->where('answer_id', $answer->id)->pluck('option_id');
            $option = QuestionChoiceOption::query()->where('question_id', $question->id)->whereNotIn('id', $selected)->firstOrFail();
            $answer->selectedOptions()->attach($option->id, ['institution_id' => $answer->institution_id, 'created_at' => now()]);
        } elseif ($corruption === 'mixed family') {
            AnswerBooleanValue::factory()->create(['answer_id' => $answer->id]);
        } elseif ($corruption === 'file attached') {
            AnswerFile::factory()->create(['answer_id' => $answer->id]);
        } elseif (in_array($corruption, ['wrong left side', 'wrong right side'], true)) {
            $column = $corruption === 'wrong left side' ? 'left_item_id' : 'right_item_id';
            $side = $corruption === 'wrong left side' ? 'right' : 'left';
            $pair = DB::table('answer_matching_pairs')->where('answer_id', $answer->id)->first();
            $item = QuestionMatchingItem::query()->where('question_id', $question->id)->where('side', $side)->firstOrFail();
            DB::table('answer_matching_pairs')->where('id', $pair->id)->update([$column => $item->id]);
        } elseif (in_array($corruption, ['zero position', 'position beyond question'], true)) {
            $item = DB::table('answer_ordering_items')->where('answer_id', $answer->id)->first();
            DB::table('answer_ordering_items')->where('id', $item->id)->update(['submitted_position' => $corruption === 'zero position' ? 0 : 6]);
        } elseif ($corruption === 'empty text') {
            DB::table($type === 'fill_in_blank' ? 'answer_fill_blank_values' : 'answer_text_values')
                ->where('answer_id', $answer->id)->update(['text_value' => "\u{FEFF}\u{0085}\u{2007}"]);
        } elseif ($corruption === 'missing payload') {
            DB::table($this->typedTable($type))->where('answer_id', $answer->id)->delete();
        } else {
            $answer->update(match ($corruption) {
                'checked status' => ['checking_status' => AttemptAnswerCheckingStatus::TeacherChecked],
                'points' => ['awarded_points' => '1.00000000'],
                'feedback' => ['feedback' => 'private-teacher-feedback-5071'],
                'checker' => ['checked_by_user_id' => $homework->assessment->teacher_id],
                'checked timestamp' => ['checked_at' => now()],
            });
        }
        $before = $this->answerSnapshot();
        $attemptBefore = $attempt->fresh()->getAttributes();
        $requests = [$payload, $this->answerPayload($question, true)];
        if (! in_array($type, ['single_choice', 'true_false'], true)) {
            $requests[] = $this->clearPayload($question);
        }
        $this->travel(1)->minutes();
        foreach ($requests as $request) {
            $response = $this->answerRequest($student, $attempt, $question, $request)->assertConflict()->assertJsonPath('code', 'business_conflict');
            $this->assertSame($before, $this->answerSnapshot());
            $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
            $this->assertNoAnswerSecrets($response->json());
            foreach ([$answer->id, ...$foreignIds, 'attempt_answers', 'answer_choice_selections', 'answer_matching_pairs',
                'answer_ordering_items', 'answer_fill_blank_values', 'answer_files', 'SQLSTATE', 'private-teacher-feedback-5071',
                'private-short-answer-6187', 'private-fill-answer-8126', 'submitted_position', 'text_value'] as $secret) {
                $this->assertStringNotContainsString($secret, $response->getContent());
            }
        }
    }

    public static function corruptAnswers(): array
    {
        $cases = [];
        foreach (['single_choice', 'multiple_choice', 'matching', 'ordering', 'fill_in_blank'] as $type) {
            $cases[$type.' wrong question'] = [$type, 'wrong question'];
        }
        foreach (['single_choice', 'multiple_choice'] as $type) {
            $cases[$type.' excess selections'] = [$type, 'too many selections'];
        }
        foreach (['mixed family', 'file attached', 'checked status', 'points', 'feedback', 'checker', 'checked timestamp'] as $case) {
            $cases[$case] = ['short_written', $case];
        }
        foreach (['wrong left side', 'wrong right side'] as $case) {
            $cases[$case] = ['matching', $case];
        }
        foreach (['zero position', 'position beyond question'] as $case) {
            $cases[$case] = ['ordering', $case];
        }
        foreach (['short_written', 'open_written', 'fill_in_blank'] as $type) {
            $cases[$type.' semantic empty'] = [$type, 'empty text'];
        }
        foreach (['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'matching', 'ordering', 'fill_in_blank'] as $type) {
            $cases[$type.' missing payload'] = [$type, 'missing payload'];
        }

        return $cases;
    }

    private function assertStoredAnswer(AttemptAnswer $answer, Question $question, array $payload): void
    {
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->checking_status);
        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
            $this->assertNull($answer->{$field});
        }
        $this->assertSame($question->institution_id, $answer->institution_id);
        $expected = $this->canonicalAnswer($question, $payload);
        $type = $question->type->value;
        $rows = DB::table($this->typedTable($type))->where('answer_id', $answer->id)->get();
        foreach ($rows as $row) {
            $this->assertSame($answer->institution_id, $row->institution_id);
            $this->assertTrue(Carbon::parse($row->created_at)->equalTo($answer->updated_at));
        }
        if (isset($expected['selected_option_ids'])) {
            $this->assertEqualsCanonicalizing($expected['selected_option_ids'], $rows->pluck('option_id')->all());
        } elseif (isset($expected['value'])) {
            $this->assertCount(1, $rows);
            $this->assertSame($expected['value'], $rows->sole()->boolean_value);
        } elseif (isset($expected['text'])) {
            $this->assertCount(1, $rows);
            $this->assertSame($expected['text'], $rows->sole()->text_value);
        } else {
            $actual = $rows->map(fn (object $row): array => match ($type) {
                'matching' => ['left_item_id' => $row->left_item_id, 'right_item_id' => $row->right_item_id],
                'ordering' => ['item_id' => $row->ordering_item_id, 'position' => $row->submitted_position],
                'fill_in_blank' => ['blank_id' => $row->blank_id, 'text' => $row->text_value],
            })->all();
            $this->assertEqualsCanonicalizing(array_values($expected)[0], $actual);
        }
        foreach (array_keys($this->answerSnapshot()) as $table) {
            if (! in_array($table, ['attempt_answers', $this->typedTable($type)], true)) {
                $this->assertSame(0, DB::table($table)->where('answer_id', $answer->id)->count());
            }
        }
    }

    private function typedTable(string $type): string
    {
        return match ($type) {
            'single_choice', 'multiple_choice' => 'answer_choice_selections', 'true_false' => 'answer_boolean_values',
            'short_written', 'open_written' => 'answer_text_values', 'matching' => 'answer_matching_pairs',
            'ordering' => 'answer_ordering_items', 'fill_in_blank' => 'answer_fill_blank_values',
        };
    }

    private function assertNoAnswerWrites(array $queries): void
    {
        foreach ($queries as $query) {
            if (preg_match('/^\s*(insert|update|delete)\b/i', $query['query']) === 1) {
                $this->assertDoesNotMatchRegularExpression('/"(?:attempt_answers|answer_[a-z_]+|assessment_attempts)"/', $query['query']);
            }
        }
    }

    private function assertSafeAnswerQueries(array $queries): void
    {
        foreach ($queries as $query) {
            foreach (['correct_value', 'correct_position', 'match_key', 'question_short_accepted_answers', 'question_fill_blank_accepted_answers'] as $secret) {
                $this->assertStringNotContainsString($secret, $query['query']);
            }
        }
    }
}
