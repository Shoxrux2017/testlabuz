<?php

namespace Tests\Feature\Student;

use App\Enums\AttemptAnswerCheckingStatus;
use App\Models\AttemptAnswer;
use App\Models\Question;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentBlitzAnswerContext;

class StudentBlitzAnswerSaveApiTest extends StudentHomeworkAnswerSaveApiTest
{
    use BuildsStudentBlitzAnswerContext;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-17 12:00:00 UTC'));
    }

    public function test_all_eight_types_save_replace_and_resume_canonical_normalized_answers_without_scoring_or_attempt_mutation(): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $attemptBefore = $attempt->getAttributes();
        $expected = [];
        foreach (['single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written', 'matching', 'ordering', 'fill_in_blank'] as $index => $type) {
            $question = $this->answerQuestion($blitz, $type, $index + 1);
            $payload = $this->answerPayload($question);
            $saved = $this->answerRequest($student, $attempt, $question, $payload)->assertOk()->assertExactJson([
                'data' => ['question_id' => $question->id, 'type' => $type,
                    'answer' => $this->canonicalAnswer($question, $payload), 'updated_at' => now()->format('Y-m-d\TH:i:s\Z')],
            ]);
            $answer = AttemptAnswer::query()->where('attempt_id', $attempt->id)->where('question_id', $question->id)->sole();
            $this->assertNormalizedAnswer($answer, $question, $payload);
            $identity = [$answer->id, $answer->getRawOriginal('created_at')];
            $before = $this->answerSnapshot();
            $equivalent = $payload;
            foreach (['selected_option_ids', 'pairs', 'items', 'values'] as $key) {
                if (isset($equivalent[$key])) {
                    $equivalent[$key] = array_reverse($equivalent[$key]);
                }
            }
            $this->travel(1)->seconds();
            DB::flushQueryLog();
            DB::enableQueryLog();
            try {
                $this->answerRequest($student, $attempt, $question, $equivalent)->assertOk()->assertExactJson($saved->json());
                foreach (DB::getQueryLog() as $query) {
                    if (preg_match('/^\s*(insert|update|delete)\b/i', $query['query']) === 1) {
                        $this->assertDoesNotMatchRegularExpression('/"(?:attempt_answers|answer_[a-z_]+|assessment_attempts)"/', $query['query']);
                    }
                }
            } finally {
                DB::disableQueryLog();
            }
            $this->assertSame($before, $this->answerSnapshot());
            $replacement = $this->answerPayload($question, true);
            $response = $this->answerRequest($student, $attempt, $question, $replacement)->assertOk()->assertExactJson([
                'data' => ['question_id' => $question->id, 'type' => $type,
                    'answer' => $this->canonicalAnswer($question, $replacement), 'updated_at' => now()->format('Y-m-d\TH:i:s\Z')],
            ]);
            $answer->refresh();
            $this->assertSame($identity, [$answer->id, $answer->getRawOriginal('created_at')]);
            $this->assertNormalizedAnswer($answer, $question, $replacement);
            $this->assertNoAnswerSecrets($response->json());
            $expected[] = $response->json('data');
        }
        $this->answerQuestion($blitz, 'file_based', 9);
        $this->assertDatabaseCount('attempt_answers', 8);
        $this->assertDatabaseCount('idempotency_records', 0);
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $resume = $this->startStudentBlitz($student, $blitz->assessment)->assertOk()->assertJsonPath('data.id', $attempt->id)
            ->assertJsonPath('data.answers', $expected)->assertJsonPath('data.deadline_at', $attempt->deadline_at->format('Y-m-d\TH:i:s\Z'));
        $this->assertNoAnswerSecrets($resume->json('data.answers'));
        foreach (['private-short-answer-6187', 'private-fill-answer-8126', 'is_correct', 'correct_value', 'match_key', 'correct_position'] as $secret) {
            $this->assertStringNotContainsString($secret, $resume->getContent());
        }
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
    }

    #[DataProvider('clearableTypes')]
    public function test_supported_clear_removes_typed_children_then_parent_and_never_changes_the_attempt(string $type): void
    {
        [$student, $blitz, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($blitz, $type);
        $attemptBefore = $attempt->getAttributes();
        $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        $this->travel(1)->seconds();
        $clear = $this->clearPayload($question);
        $this->answerRequest($student, $attempt, $question, $clear)->assertOk()->assertExactJson([
            'data' => ['question_id' => $question->id, 'type' => $type, 'answer' => null, 'updated_at' => null],
        ]);
        foreach ($this->answerSnapshot() as $rows) {
            $this->assertSame([], $rows);
        }
        $this->answerRequest($student, $attempt, $question, $clear)->assertOk()->assertJsonPath('data.answer', null);
        $this->assertDatabaseCount('attempt_answers', 0);
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->startStudentBlitz($student, $blitz->assessment)->assertOk()->assertJsonPath('data.answers', []);
    }

    private function assertNormalizedAnswer(AttemptAnswer $answer, Question $question, array $payload): void
    {
        $this->assertSame(AttemptAnswerCheckingStatus::Pending, $answer->checking_status);
        foreach (['awarded_points', 'feedback', 'checked_by_user_id', 'checked_at'] as $field) {
            $this->assertNull($answer->{$field});
        }
        $type = $question->type->value;
        $table = match ($type) {
            'single_choice', 'multiple_choice' => 'answer_choice_selections', 'true_false' => 'answer_boolean_values',
            'short_written', 'open_written' => 'answer_text_values', 'matching' => 'answer_matching_pairs',
            'ordering' => 'answer_ordering_items', 'fill_in_blank' => 'answer_fill_blank_values',
        };
        $rows = DB::table($table)->where('answer_id', $answer->id)->get();
        $expected = $this->canonicalAnswer($question, $payload);
        $actual = $rows->map(fn (object $row): mixed => match ($type) {
            'single_choice', 'multiple_choice' => $row->option_id,
            'true_false' => $row->boolean_value,
            'short_written', 'open_written' => $row->text_value,
            'matching' => ['left_item_id' => $row->left_item_id, 'right_item_id' => $row->right_item_id],
            'ordering' => ['item_id' => $row->ordering_item_id, 'position' => $row->submitted_position],
            'fill_in_blank' => ['blank_id' => $row->blank_id, 'text' => $row->text_value],
        })->all();
        $values = array_values($expected)[0];
        $this->assertEqualsCanonicalizing(is_array($values) ? $values : [$values], $actual);
        foreach ($rows as $row) {
            $this->assertSame($answer->institution_id, $row->institution_id);
            $this->assertTrue(Carbon::parse($row->created_at)->equalTo($answer->updated_at));
        }
        foreach (array_keys($this->answerSnapshot()) as $otherTable) {
            if (! in_array($otherTable, ['attempt_answers', $table], true)) {
                $this->assertSame(0, DB::table($otherTable)->where('answer_id', $answer->id)->count());
            }
        }
    }
}
