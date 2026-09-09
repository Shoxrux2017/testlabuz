<?php

namespace Tests\Feature\Student;

use App\Models\AttemptAnswer;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionOrderingItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Feature\Student\Concerns\BuildsStudentHomeworkAnswerContext;
use Tests\TestCase;

class StudentHomeworkAnswerValidationTest extends TestCase
{
    use BuildsStudentHomeworkAnswerContext, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-09-09 12:00:00 UTC'));
    }

    #[DataProvider('invalidJsonRequests')]
    public function test_request_requires_one_strict_raw_json_object_and_no_query_parameters(string $body, string $contentType = 'application/json', string $query = ''): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'short_written');
        $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        $before = $this->answerSnapshot();
        $attemptBefore = $attempt->getAttributes();
        $response = $this->answerRequest($student, $attempt, $question, $body, $contentType, $query)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $this->answerSnapshot());
        $this->assertSame($attemptBefore, $attempt->fresh()->getAttributes());
        $this->assertStringNotContainsString('private-short-answer-6187', $response->getContent());
    }

    public static function invalidJsonRequests(): array
    {
        $cases = [
            'absent body' => [''], 'only whitespace' => ['  '], 'broken json' => ['{"type":'],
            'top array' => ['[]'], 'array containing object' => ['[{"type":"short_written","text":"DNS"}]'],
            'null' => ['null'], 'string' => ['"DNS"'], 'integer' => ['1'], 'boolean' => ['true'],
            'plain text content type' => ['{"type":"short_written","text":"DNS"}', 'text/plain'],
            'form content type' => ['type=short_written&text=DNS', 'application/x-www-form-urlencoded'],
            'json suffix content type' => ['{"type":"short_written","text":"DNS"}', 'application/merge-patch+json'],
            'query parameter' => ['{"type":"short_written","text":"DNS"}', 'application/json', '?page=1'],
            'unknown key' => ['{"type":"short_written","text":"DNS","extra":1}'],
            'missing type' => ['{"text":"DNS"}'], 'empty object' => ['{}'],
            'unsupported type' => ['{"type":"unsupported","text":"DNS"}'],
            'file type' => ['{"type":"file_based","file_id":"11111111-1111-4111-8111-111111111111"}'],
            'null type' => ['{"type":null,"text":"DNS"}'], 'array type' => ['{"type":[],"text":"DNS"}'],
            'wrong question type' => ['{"type":"true_false","value":true}'],
        ];
        foreach (['attempt_id', 'question_id', 'institution_id', 'student_id', 'checking_status', 'awarded_points',
            'feedback', 'checked_by_user_id', 'checked_at', 'is_correct', 'correct_value', 'accepted_answers', 'correct_position', 'match_key'] as $field) {
            $cases['protected '.$field] = [json_encode(['type' => 'short_written', 'text' => 'DNS', $field => 'protected'], JSON_THROW_ON_ERROR)];
        }

        return $cases;
    }

    #[DataProvider('invalidTypedShapes')]
    public function test_invalid_typed_shapes_and_values_leave_every_existing_answer_row_unchanged(string $type, string $case): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, $type);
        $payload = $this->answerPayload($question);
        $this->answerRequest($student, $attempt, $question, $payload)->assertOk();
        $before = $this->answerSnapshot();
        $invalid = $this->invalidPayload($question, $payload, $case);
        $this->travel(1)->seconds();
        $response = $this->answerRequest($student, $attempt, $question, $invalid)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        if ($case === 'over shape limit') {
            $response->assertJsonValidationErrors(array_keys($payload)[1]);
        }
        $this->assertSame($before, $this->answerSnapshot());
        foreach (['private-short-answer-6187', 'private-fill-answer-8126', 'SQLSTATE'] as $private) {
            $this->assertStringNotContainsString($private, $response->getContent());
        }
    }

    public static function invalidTypedShapes(): array
    {
        $cases = [];
        $byType = [
            'single_choice' => ['missing answer', 'null answer', 'object answer', 'empty', 'more than one', 'duplicate', 'malformed id', 'non-string id'],
            'multiple_choice' => ['missing answer', 'null answer', 'object answer', 'over shape limit', 'duplicate', 'malformed id', 'non-string id'],
            'true_false' => ['missing answer', 'null answer', 'string boolean', 'one', 'zero', 'array boolean'],
            'short_written' => ['missing answer', 'null answer', 'number text', 'array text', 'over text limit'],
            'open_written' => ['missing answer', 'null answer', 'number text', 'array text', 'over text limit'],
            'matching' => ['missing answer', 'null answer', 'object answer', 'over shape limit', 'missing nested key', 'extra nested key',
                'array nested item', 'scalar nested item', 'malformed id', 'duplicate left', 'duplicate right', 'left is right', 'right is left'],
            'ordering' => ['missing answer', 'null answer', 'object answer', 'over shape limit', 'missing nested key', 'extra nested key',
                'array nested item', 'scalar nested item', 'malformed id', 'duplicate', 'duplicate positions', 'zero position', 'negative position', 'position beyond question'],
            'fill_in_blank' => ['missing answer', 'null answer', 'object answer', 'over shape limit', 'missing nested key', 'extra nested key',
                'array nested item', 'scalar nested item', 'malformed id', 'duplicate', 'over text limit', 'number text', 'null text', 'empty text', 'unicode empty text'],
        ];
        foreach ($byType as $type => $failures) {
            foreach ($failures as $failure) {
                $cases[$type.' '.$failure] = [$type, $failure];
            }
        }

        return $cases;
    }

    #[DataProvider('scopedChildCases')]
    public function test_child_ids_must_belong_to_the_exact_question_and_institution_without_existence_disclosure(string $type, bool $foreignInstitution): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, $type);
        $payload = $this->answerPayload($question);
        $this->answerRequest($student, $attempt, $question, $payload)->assertOk();
        if ($foreignInstitution) {
            [, $otherHomework] = $this->answerContext();
            $other = $this->answerQuestion($otherHomework, $type);
        } else {
            $other = $this->answerQuestion($homework, $type, 2);
        }
        $otherPayload = $this->answerPayload($other);
        $before = $this->answerSnapshot();
        $response = $this->answerRequest($student, $attempt, $question, $otherPayload)
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $this->answerSnapshot());
        $this->assertStringNotContainsString($other->id, $response->getContent());
        foreach (['selected_option_ids', 'pairs', 'items', 'values'] as $key) {
            if (isset($otherPayload[$key])) {
                array_walk_recursive($otherPayload[$key], function ($value) use ($response): void {
                    if (is_string($value) && Str::isUuid($value)) {
                        $this->assertStringNotContainsString($value, $response->getContent());
                    }
                });
            }
        }
    }

    public static function scopedChildCases(): array
    {
        $cases = [];
        foreach (['single_choice', 'multiple_choice', 'matching', 'ordering', 'fill_in_blank'] as $type) {
            $cases[$type.' same institution other question'] = [$type, false];
            $cases[$type.' foreign institution'] = [$type, true];
        }

        return $cases;
    }

    public function test_multiple_choice_limit_uses_only_the_number_of_correct_options_and_has_the_exact_error_contract(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'multiple_choice');
        $this->answerRequest($student, $attempt, $question, $this->answerPayload($question))->assertOk();
        $ids = QuestionChoiceOption::query()->where('question_id', $question->id)->orderBy('position')->pluck('id')->all();
        $before = $this->answerSnapshot();
        $response = $this->answerRequest($student, $attempt, $question, ['type' => 'multiple_choice', 'selected_option_ids' => array_slice($ids, 0, 3)])
            ->assertUnprocessable()->assertJsonPath('code', 'selection_limit_exceeded')
            ->assertJsonPath('message', 'Too many options were selected for this Question.')
            ->assertJsonPath('errors', ['selected_option_ids' => ['Select no more than the allowed number of options.']]);
        $this->assertSame($before, $this->answerSnapshot());
        foreach ($ids as $id) {
            $this->assertStringNotContainsString($id, $response->getContent());
        }
        $this->assertNoAnswerSecrets($response->json());
        QuestionChoiceOption::query()->where('question_id', $question->id)->update(['is_correct' => false]);
        $this->answerRequest($student, $attempt, $question, ['type' => 'multiple_choice', 'selected_option_ids' => []])
            ->assertConflict()->assertJsonPath('code', 'business_conflict');
        $this->assertSame($before, $this->answerSnapshot());
    }

    #[DataProvider('invalidRawPositions')]
    public function test_ordering_position_uses_the_original_json_numeric_type(string $rawPosition): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'ordering');
        $itemId = QuestionOrderingItem::query()->where('question_id', $question->id)->firstOrFail()->id;
        $this->answerRequest($student, $attempt, $question, '{"type":"ordering","items":[{"item_id":"'.$itemId.'","position":1}]}')
            ->assertOk()->assertJsonPath('data.answer.items.0.position', 1);
        $before = $this->answerSnapshot();
        $body = '{"type":"ordering","items":[{"item_id":"'.$itemId.'","position":'.$rawPosition.'}]}';
        $this->answerRequest($student, $attempt, $question, $body)->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
        $this->assertSame($before, $this->answerSnapshot());
    }

    public static function invalidRawPositions(): array
    {
        return ['numeric string' => ['"1"'], 'integral float' => ['1.0'], 'fraction' => ['1.5'],
            'exponent float' => ['1e0'], 'boolean' => ['true'], 'null' => ['null'], 'array' => ['[]']];
    }

    #[DataProvider('writtenTypes')]
    public function test_raw_written_strings_preserve_exact_unicode_text_and_recognize_only_the_locked_whitespace_set(string $type, int $limit): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, $type);
        foreach (['DNS', '  DNS  ', "\u{FEFF}  D\u{0085}NS\t", str_repeat('界', $limit), "\u{200B}", "\u{180E}", "\u{0086}"] as $text) {
            $this->answerRequest($student, $attempt, $question, ['type' => $type, 'text' => $text])
                ->assertOk()->assertJsonPath('data.answer.text', $text);
            $this->assertSame($text, DB::table('answer_text_values')->sole()->text_value);
        }
        $whitespace = [9, 10, 11, 12, 13, 32, 0x85, 0xA0, 0x1680,
            ...range(0x2000, 0x200A), 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF];
        foreach (['', ...array_map(fn (int $codepoint): string => mb_chr($codepoint), $whitespace)] as $empty) {
            $this->answerRequest($student, $attempt, $question, ['type' => $type, 'text' => 'saved before clear'])->assertOk();
            $this->answerRequest($student, $attempt, $question, ['type' => $type, 'text' => $empty])
                ->assertOk()->assertJsonPath('data.answer', null)->assertJsonPath('data.updated_at', null);
            $this->assertDatabaseCount('attempt_answers', 0);
            $this->assertDatabaseCount('answer_text_values', 0);
        }
    }

    public static function writtenTypes(): array
    {
        return ['short' => ['short_written', 1000], 'open' => ['open_written', 20000]];
    }

    public function test_fill_text_preserves_unicode_boundaries_and_rejects_every_semantic_whitespace_only_value(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'fill_in_blank');
        $blank = QuestionFillBlank::query()->where('question_id', $question->id)->firstOrFail();
        foreach ([str_repeat('界', 1000), " \u{FEFF}DNS\u{00A0} ", "\u{200B}", "\u{180E}"] as $text) {
            $this->answerRequest($student, $attempt, $question, ['type' => 'fill_in_blank', 'values' => [['blank_id' => $blank->id, 'text' => $text]]])
                ->assertOk()->assertJsonPath('data.answer.values.0.text', $text);
            $this->assertSame($text, DB::table('answer_fill_blank_values')->sole()->text_value);
        }
        $before = $this->answerSnapshot();
        foreach (['', "\t\n\v\f\r ", "\u{0085}\u{00A0}\u{1680}",
            implode('', array_map(fn (int $codepoint): string => mb_chr($codepoint), range(0x2000, 0x200A))),
            "\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}"] as $text) {
            $this->answerRequest($student, $attempt, $question, ['type' => 'fill_in_blank', 'values' => [['blank_id' => $blank->id, 'text' => $text]]])
                ->assertUnprocessable()->assertJsonPath('code', 'validation_failed');
            $this->assertSame($before, $this->answerSnapshot());
        }
    }

    public function test_non_file_payload_cannot_be_saved_to_a_file_question(): void
    {
        [$student, $homework, $attempt] = $this->answerContext();
        $question = $this->answerQuestion($homework, 'file_based');
        $this->answerRequest($student, $attempt, $question, ['type' => 'short_written', 'text' => 'not a file'])
            ->assertUnprocessable()->assertJsonPath('code', 'validation_failed')->assertJsonValidationErrors('type');
        $this->assertSame(0, AttemptAnswer::query()->count());
    }

    private function invalidPayload(Question $question, array $payload, string $case): array
    {
        $key = array_keys($payload)[1];
        if ($case === 'missing answer') {
            unset($payload[$key]);
        } elseif ($case === 'null answer') {
            $payload[$key] = null;
        } elseif ($case === 'object answer') {
            $payload[$key] = (object) ['0' => $payload[$key][0]];
        } elseif ($case === 'empty') {
            $payload[$key] = [];
        } elseif ($case === 'more than one') {
            $payload[$key] = QuestionChoiceOption::query()->where('question_id', $question->id)->limit(2)->pluck('id')->all();
        } elseif ($case === 'over shape limit') {
            $payload[$key] = array_fill(0, $key === 'selected_option_ids' ? 21 : 51, $payload[$key][0]);
        } elseif ($case === 'duplicate') {
            $payload[$key] = [$payload[$key][0], $payload[$key][0]];
        } elseif ($case === 'malformed id') {
            if ($key === 'selected_option_ids') {
                $payload[$key][0] = 'malformed-uuid';
            } else {
                $payload[$key][0][array_keys($payload[$key][0])[0]] = 'malformed-uuid';
            }
        } elseif ($case === 'non-string id') {
            $payload[$key][0] = 1;
        } elseif (in_array($case, ['string boolean', 'one', 'zero', 'array boolean'], true)) {
            $payload[$key] = match ($case) {
                'string boolean' => 'true', 'one' => 1, 'zero' => 0, 'array boolean' => [],
            };
        } elseif (in_array($case, ['number text', 'array text', 'over text limit', 'null text', 'empty text', 'unicode empty text'], true)) {
            $text = match ($case) {
                'number text' => 42, 'array text' => [], 'null text' => null, 'empty text' => '',
                'unicode empty text' => "\u{FEFF}\u{0085}\u{00A0}",
                'over text limit' => str_repeat('界', $question->type->value === 'open_written' ? 20001 : 1001),
            };
            if ($key === 'values') {
                $payload[$key][0]['text'] = $text;
            } else {
                $payload[$key] = $text;
            }
        } elseif ($case === 'missing nested key') {
            unset($payload[$key][0][array_keys($payload[$key][0])[1]]);
        } elseif ($case === 'extra nested key') {
            $payload[$key][0]['checking_status'] = 'pending';
        } elseif ($case === 'array nested item') {
            $payload[$key][0] = array_values($payload[$key][0]);
        } elseif ($case === 'scalar nested item') {
            $payload[$key][0] = 'invalid';
        } elseif ($case === 'duplicate left') {
            $payload['pairs'][1]['left_item_id'] = $payload['pairs'][0]['left_item_id'];
        } elseif ($case === 'duplicate right') {
            $payload['pairs'][1]['right_item_id'] = $payload['pairs'][0]['right_item_id'];
        } elseif ($case === 'left is right') {
            $payload['pairs'][0]['left_item_id'] = $payload['pairs'][0]['right_item_id'];
        } elseif ($case === 'right is left') {
            $payload['pairs'][0]['right_item_id'] = $payload['pairs'][0]['left_item_id'];
        } elseif ($case === 'duplicate positions') {
            $payload['items'][1]['position'] = $payload['items'][0]['position'];
        } else {
            $payload['items'][0]['position'] = match ($case) {
                'zero position' => 0, 'negative position' => -1, 'position beyond question' => 6,
            };
        }

        return $payload;
    }
}
