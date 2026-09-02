<?php

namespace Tests\Unit\Domain\Assessment;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use Closure;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

class QuestionConfigurationValidatorTest extends TestCase
{
    private QuestionConfigurationValidator $validator;

    protected function setUp(): void
    {
        parent::setUp();
        $this->validator = new QuestionConfigurationValidator;
    }

    public function test_valid_configuration_is_accepted_for_all_nine_types_and_both_short_written_modes(): void
    {
        foreach ($this->validCases() as [$type, $mode, $prompt, $configuration]) {
            $this->validator->validate($type, $mode, $prompt, $configuration);
            $this->addToAssertionCount(1);
        }
    }

    public function test_wrong_checking_mode_is_rejected_for_every_fixed_mode_type(): void
    {
        foreach ($this->validCases() as [$type, $mode, $prompt, $configuration]) {
            if ($type === QuestionType::ShortWritten) {
                continue;
            }

            $wrongMode = $mode === QuestionCheckingMode::Automatic
                ? QuestionCheckingMode::Manual
                : QuestionCheckingMode::Automatic;

            $this->assertInvalid(fn () => $this->validator->validate($type, $wrongMode, $prompt, $configuration));
        }
    }

    public function test_unknown_configuration_and_nested_keys_are_rejected(): void
    {
        $this->assertInvalid(fn () => $this->validate(QuestionType::TrueFalse, ['correct_value' => true, 'future' => true]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::SingleChoice, [
            'options' => [
                ['text' => 'A', 'is_correct' => true, 'position' => 1, 'id' => 'protected'],
                ['text' => 'B', 'is_correct' => false, 'position' => 2],
            ],
        ]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::OpenWritten, ['answer' => 'hidden'], QuestionCheckingMode::Manual));
    }

    public function test_choice_rules_reject_bad_counts_text_flags_positions_and_correct_cardinality(): void
    {
        $valid = $this->choiceOptions();
        $invalidConfigurations = [
            ['options' => [$valid[0]]],
            ['options' => array_fill(0, QuestionAuthoringLimits::MAX_CHOICE_OPTIONS + 1, $valid[0])],
            ['options' => [['text' => ' ', 'is_correct' => true, 'position' => 1], $valid[1]]],
            ['options' => [['text' => str_repeat('x', QuestionAuthoringLimits::MAX_OPTION_TEXT_LENGTH + 1), 'is_correct' => true, 'position' => 1], $valid[1]]],
            ['options' => [['text' => 'A', 'is_correct' => 1, 'position' => 1], $valid[1]]],
            ['options' => [['text' => 'A', 'is_correct' => true, 'position' => 0], $valid[1]]],
            ['options' => [['text' => 'A', 'is_correct' => true, 'position' => 1], ['text' => 'B', 'is_correct' => false, 'position' => 3]]],
        ];

        foreach ($invalidConfigurations as $configuration) {
            $this->assertInvalid(fn () => $this->validate(QuestionType::SingleChoice, $configuration));
        }

        $this->assertInvalid(fn () => $this->validate(QuestionType::SingleChoice, [
            'options' => [
                ['text' => 'A', 'is_correct' => false, 'position' => 1],
                ['text' => 'B', 'is_correct' => false, 'position' => 2],
            ],
        ]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::SingleChoice, [
            'options' => [
                ['text' => 'A', 'is_correct' => true, 'position' => 1],
                ['text' => 'B', 'is_correct' => true, 'position' => 2],
            ],
        ]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::MultipleChoice, [
            'options' => [
                ['text' => 'A', 'is_correct' => false, 'position' => 1],
                ['text' => 'B', 'is_correct' => false, 'position' => 2],
            ],
        ]));

        $this->validator->validate(QuestionType::MultipleChoice, QuestionCheckingMode::Automatic, 'Choose all.', [
            'options' => [
                ['text' => 'A', 'is_correct' => true, 'position' => 1],
                ['text' => 'B', 'is_correct' => true, 'position' => 2],
            ],
        ]);
        $this->addToAssertionCount(1);
    }

    public function test_true_false_and_short_written_rules_are_exact(): void
    {
        $this->assertInvalid(fn () => $this->validate(QuestionType::TrueFalse, ['correct_value' => 1]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::TrueFalse, []));
        $this->assertInvalid(fn () => $this->validate(QuestionType::ShortWritten, ['accepted_answers' => []]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::ShortWritten, ['accepted_answers' => ['answer', 'answer']]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::ShortWritten, ['accepted_answers' => [' ']]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::ShortWritten, ['accepted_answers' => [str_repeat('x', QuestionAuthoringLimits::MAX_ACCEPTED_ANSWER_LENGTH + 1)]]));
        $this->assertInvalid(fn () => $this->validate(QuestionType::ShortWritten, [
            'accepted_answers' => array_fill(0, QuestionAuthoringLimits::MAX_SHORT_ACCEPTED_ANSWERS + 1, 'answer'),
        ]));
        $this->assertInvalid(fn () => $this->validate(
            QuestionType::ShortWritten,
            ['accepted_answers' => ['answer']],
            QuestionCheckingMode::Manual,
        ));
    }

    public function test_file_based_requires_the_fixed_existing_extension_set_in_canonical_order(): void
    {
        foreach ([
            [],
            ['allowed_extensions' => ['pdf', 'docx', 'ppt']],
            ['allowed_extensions' => ['docx', 'pdf', 'ppt', 'pptx']],
            ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx', 'zip']],
            ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'ppt']],
            ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx'], 'max_size' => 10],
        ] as $configuration) {
            $this->assertInvalid(fn () => $this->validate(QuestionType::FileBased, $configuration, QuestionCheckingMode::Manual));
        }
    }

    public function test_matching_rejects_missing_or_excess_pairs_duplicate_keys_blank_or_long_content_and_unknown_keys(): void
    {
        $pair = ['client_key' => 'pair-1', 'left' => 'Left', 'right' => 'Right'];
        foreach ([
            ['pairs' => []],
            ['pairs' => array_fill(0, QuestionAuthoringLimits::MAX_MATCHING_PAIRS + 1, $pair)],
            ['pairs' => [$pair, $pair]],
            ['pairs' => [['client_key' => '', 'left' => 'Left', 'right' => 'Right']]],
            ['pairs' => [['client_key' => str_repeat('x', QuestionAuthoringLimits::MAX_CLIENT_KEY_LENGTH + 1), 'left' => 'Left', 'right' => 'Right']]],
            ['pairs' => [['client_key' => 'pair', 'left' => ' ', 'right' => 'Right']]],
            ['pairs' => [['client_key' => 'pair', 'left' => 'Left', 'right' => str_repeat('x', QuestionAuthoringLimits::MAX_MATCHING_ITEM_TEXT_LENGTH + 1)]]],
            ['pairs' => [['client_key' => 'pair', 'left' => 'Left', 'right' => 'Right', 'match_key' => 'client-owned']]],
        ] as $configuration) {
            $this->assertInvalid(fn () => $this->validate(QuestionType::Matching, $configuration));
        }
    }

    public function test_ordering_requires_two_to_limit_items_valid_text_and_contiguous_integer_positions(): void
    {
        $item = ['text' => 'First', 'correct_position' => 1];
        foreach ([
            ['items' => [$item]],
            ['items' => array_fill(0, QuestionAuthoringLimits::MAX_ORDERING_ITEMS + 1, $item)],
            ['items' => [['text' => ' ', 'correct_position' => 1], ['text' => 'Second', 'correct_position' => 2]]],
            ['items' => [['text' => str_repeat('x', QuestionAuthoringLimits::MAX_ORDERING_ITEM_TEXT_LENGTH + 1), 'correct_position' => 1], ['text' => 'Second', 'correct_position' => 2]]],
            ['items' => [['text' => 'First', 'correct_position' => 1], ['text' => 'Second', 'correct_position' => 1]]],
            ['items' => [['text' => 'First', 'correct_position' => 1], ['text' => 'Second', 'correct_position' => 3]]],
            ['items' => [['text' => 'First', 'correct_position' => '1'], ['text' => 'Second', 'correct_position' => 2]]],
            ['items' => [['text' => 'First', 'correct_position' => 1, 'position' => 1], ['text' => 'Second', 'correct_position' => 2]]],
        ] as $configuration) {
            $this->assertInvalid(fn () => $this->validate(QuestionType::Ordering, $configuration));
        }
    }

    public function test_fill_in_blank_requires_keys_positions_answers_and_exact_placeholder_coverage(): void
    {
        $blank = ['key' => 'host', 'position' => 1, 'accepted_answers' => ['server']];
        $cases = [
            ['Prompt {{host}}.', ['blanks' => []]],
            ['Prompt {{host}}.', ['blanks' => array_fill(0, QuestionAuthoringLimits::MAX_FILL_BLANKS + 1, $blank)]],
            ['Prompt {{1host}}.', ['blanks' => [['key' => '1host', 'position' => 1, 'accepted_answers' => ['server']]]]],
            ['Prompt {{host}}.', ['blanks' => [$blank, ['key' => 'host', 'position' => 2, 'accepted_answers' => ['machine']]]]],
            ['Prompt {{host}}.', ['blanks' => [['key' => 'host', 'position' => 0, 'accepted_answers' => ['server']]]]],
            ['Prompt {{host}} {{address}}.', ['blanks' => [$blank, ['key' => 'address', 'position' => 3, 'accepted_answers' => ['IP']]]]],
            ['Prompt {{host}}.', ['blanks' => [['key' => 'host', 'position' => 1, 'accepted_answers' => []]]]],
            ['Prompt {{host}}.', ['blanks' => [['key' => 'host', 'position' => 1, 'accepted_answers' => ['server', 'server']]]]],
            ['Prompt {{host}}.', ['blanks' => [['key' => 'host', 'position' => 1, 'accepted_answers' => array_fill(0, QuestionAuthoringLimits::MAX_ACCEPTED_ANSWERS_PER_BLANK + 1, 'server')]]]],
            ['Prompt.', ['blanks' => [$blank]]],
            ['Prompt {{host}} {{address}}.', ['blanks' => [$blank]]],
            ['Prompt {{host}} twice {{host}}.', ['blanks' => [$blank]]],
            ['Prompt {{host}}.', ['blanks' => [['key' => 'address', 'position' => 1, 'accepted_answers' => ['IP']]]]],
            [
                'Prompt {{host}}.',
                ['blanks' => [
                    ['key' => 'host', 'position' => 1, 'accepted_answers' => ['server'], 'id' => 'protected'],
                ]],
            ],
        ];

        foreach ($cases as [$prompt, $configuration]) {
            $this->assertInvalid(fn () => $this->validator->validate(
                QuestionType::FillInBlank,
                QuestionCheckingMode::Automatic,
                $prompt,
                $configuration,
            ));
        }

        $this->validator->validate(
            QuestionType::FillInBlank,
            QuestionCheckingMode::Automatic,
            'Literal {braces} and {{host}}.',
            ['blanks' => [$blank]],
        );
        $this->addToAssertionCount(1);
    }

    public function test_prompt_validation_rejects_blank_and_over_limit_content(): void
    {
        $this->assertInvalid(fn () => $this->validator->validate(QuestionType::OpenWritten, QuestionCheckingMode::Manual, ' ', []));
        $this->assertInvalid(fn () => $this->validator->validate(
            QuestionType::OpenWritten,
            QuestionCheckingMode::Manual,
            str_repeat('x', QuestionAuthoringLimits::MAX_PROMPT_LENGTH + 1),
            [],
        ));
    }

    /** @return list<array{QuestionType, QuestionCheckingMode, string, array<string, mixed>}> */
    private function validCases(): array
    {
        return [
            [QuestionType::SingleChoice, QuestionCheckingMode::Automatic, 'Choose one.', ['options' => $this->choiceOptions()]],
            [QuestionType::MultipleChoice, QuestionCheckingMode::Automatic, 'Choose all.', ['options' => $this->choiceOptions()]],
            [QuestionType::TrueFalse, QuestionCheckingMode::Automatic, 'True?', ['correct_value' => true]],
            [QuestionType::ShortWritten, QuestionCheckingMode::Automatic, 'Answer.', ['accepted_answers' => ['Tashkent', 'Toshkent']]],
            [QuestionType::ShortWritten, QuestionCheckingMode::Manual, 'Explain briefly.', []],
            [QuestionType::OpenWritten, QuestionCheckingMode::Manual, 'Explain.', []],
            [QuestionType::FileBased, QuestionCheckingMode::Manual, 'Upload.', ['allowed_extensions' => ['pdf', 'docx', 'ppt', 'pptx']]],
            [QuestionType::Matching, QuestionCheckingMode::Automatic, 'Match.', ['pairs' => [
                ['client_key' => 'pair-1', 'left' => 'A', 'right' => '1'],
                ['client_key' => 'pair-2', 'left' => 'B', 'right' => '2'],
            ]]],
            [QuestionType::Ordering, QuestionCheckingMode::Automatic, 'Order.', ['items' => [
                ['text' => 'First', 'correct_position' => 1],
                ['text' => 'Second', 'correct_position' => 2],
            ]]],
            [QuestionType::FillInBlank, QuestionCheckingMode::Automatic, 'DNS maps {{host}} to {{address}}.', ['blanks' => [
                ['key' => 'host', 'position' => 1, 'accepted_answers' => ['example.uz']],
                ['key' => 'address', 'position' => 2, 'accepted_answers' => ['127.0.0.1']],
            ]]],
        ];
    }

    /** @return list<array{text: string, is_correct: bool, position: int}> */
    private function choiceOptions(): array
    {
        return [
            ['text' => 'A', 'is_correct' => true, 'position' => 1],
            ['text' => 'B', 'is_correct' => false, 'position' => 2],
        ];
    }

    /** @param array<string, mixed> $configuration */
    private function validate(
        QuestionType $type,
        array $configuration,
        QuestionCheckingMode $mode = QuestionCheckingMode::Automatic,
    ): void {
        $this->validator->validate($type, $mode, 'Valid prompt.', $configuration);
    }

    private function assertInvalid(Closure $operation): void
    {
        try {
            $operation();
        } catch (InvalidArgumentException $exception) {
            $this->assertSame('Invalid question configuration.', $exception->getMessage());

            return;
        }

        $this->fail('Expected invalid question configuration to be rejected.');
    }
}
