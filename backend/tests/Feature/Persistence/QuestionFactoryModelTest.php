<?php

namespace Tests\Feature\Persistence;

use App\Domain\Assessment\QuestionAuthoringLimits;
use App\Enums\FileExtension;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionMatchingSide;
use App\Enums\QuestionType;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionFillBlankAcceptedAnswer;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\QuestionShortAcceptedAnswer;
use App\Models\QuestionTrueFalseAnswer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class QuestionFactoryModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_enums_and_authoring_limits_expose_exact_contract_values(): void
    {
        $this->assertSame([
            'single_choice', 'multiple_choice', 'true_false', 'short_written', 'open_written',
            'file_based', 'matching', 'ordering', 'fill_in_blank',
        ], QuestionType::values());
        $this->assertSame(['automatic', 'manual'], QuestionCheckingMode::values());
        $this->assertSame(['left', 'right'], QuestionMatchingSide::values());
        $this->assertSame(['pdf', 'docx', 'ppt', 'pptx'], FileExtension::values());

        $this->assertSame([
            'MAX_QUESTIONS_PER_ASSESSMENT' => 100,
            'MAX_PROMPT_LENGTH' => 10000,
            'MAX_INSTRUCTIONS_LENGTH' => 5000,
            'MAX_CHOICE_OPTIONS' => 20,
            'MAX_OPTION_TEXT_LENGTH' => 2000,
            'MAX_SHORT_ACCEPTED_ANSWERS' => 20,
            'MAX_ACCEPTED_ANSWER_LENGTH' => 1000,
            'MAX_MATCHING_PAIRS' => 50,
            'MAX_MATCHING_ITEM_TEXT_LENGTH' => 2000,
            'MAX_CLIENT_KEY_LENGTH' => 80,
            'MAX_ORDERING_ITEMS' => 50,
            'MAX_ORDERING_ITEM_TEXT_LENGTH' => 2000,
            'MAX_FILL_BLANKS' => 50,
            'MAX_ACCEPTED_ANSWERS_PER_BLANK' => 20,
        ], (new \ReflectionClass(QuestionAuthoringLimits::class))->getConstants());
    }

    public function test_models_cast_fields_use_uuid_keys_and_resolve_the_complete_relationship_graph(): void
    {
        $question = Question::factory()->matching()->create(['points' => '12.345678', 'position' => 2]);
        $choice = QuestionChoiceOption::factory()->create(['question_id' => $question, 'institution_id' => $question->institution_id, 'is_correct' => true]);
        $trueFalse = QuestionTrueFalseAnswer::factory()->create(['question_id' => $question, 'institution_id' => $question->institution_id, 'correct_value' => false]);
        $short = QuestionShortAcceptedAnswer::factory()->create(['question_id' => $question, 'institution_id' => $question->institution_id]);
        $matchKey = Str::uuid()->toString();
        $matching = QuestionMatchingItem::factory()->right()->create([
            'question_id' => $question,
            'institution_id' => $question->institution_id,
            'match_key' => $matchKey,
        ]);
        $ordering = QuestionOrderingItem::factory()->create(['question_id' => $question, 'institution_id' => $question->institution_id]);
        $blank = QuestionFillBlank::factory()->create(['question_id' => $question, 'institution_id' => $question->institution_id]);
        $blankAnswer = QuestionFillBlankAcceptedAnswer::factory()->create(['blank_id' => $blank, 'institution_id' => $question->institution_id]);

        foreach ([$question, $choice, $short, $matching, $ordering, $blank, $blankAnswer] as $model) {
            $this->assertTrue(Str::isUuid($model->id));
        }

        $this->assertSame('question_id', $trueFalse->getKeyName());
        $this->assertSame($question->id, $trueFalse->getKey());
        $this->assertFalse($trueFalse->getIncrementing());
        $this->assertSame('string', $trueFalse->getKeyType());

        $this->assertSame(QuestionType::Matching, $question->type);
        $this->assertSame(QuestionCheckingMode::Automatic, $question->checking_mode);
        $this->assertSame('12.345678', $question->points);
        $this->assertSame(2, $question->position);
        $this->assertTrue($choice->is_correct);
        $this->assertFalse($trueFalse->correct_value);
        $this->assertSame(QuestionMatchingSide::Right, $matching->side);

        $this->assertTrue($question->institution->is($question->assessment->institution));
        $this->assertTrue($question->assessment->questions->contains($question));
        $this->assertTrue($question->choiceOptions->contains($choice));
        $this->assertTrue($trueFalse->is($question->trueFalseAnswer));
        $this->assertTrue($question->shortAcceptedAnswers->contains($short));
        $this->assertTrue($question->matchingItems->contains($matching));
        $this->assertTrue($question->orderingItems->contains($ordering));
        $this->assertTrue($question->fillBlanks->contains($blank));
        $this->assertTrue($blank->acceptedAnswers->contains($blankAnswer));

        foreach ([$choice, $trueFalse, $short, $matching, $ordering, $blank] as $child) {
            $this->assertTrue($question->is($child->question));
            $this->assertTrue($question->institution->is($child->institution));
        }

        $this->assertTrue($blank->is($blankAnswer->blank));
        $this->assertTrue($question->institution->is($blankAnswer->institution));
    }

    public function test_question_type_states_and_child_factories_create_same_institution_graphs(): void
    {
        $states = [
            'singleChoice' => [QuestionType::SingleChoice, QuestionCheckingMode::Automatic],
            'multipleChoice' => [QuestionType::MultipleChoice, QuestionCheckingMode::Automatic],
            'trueFalse' => [QuestionType::TrueFalse, QuestionCheckingMode::Automatic],
            'shortWrittenAutomatic' => [QuestionType::ShortWritten, QuestionCheckingMode::Automatic],
            'shortWrittenManual' => [QuestionType::ShortWritten, QuestionCheckingMode::Manual],
            'openWritten' => [QuestionType::OpenWritten, QuestionCheckingMode::Manual],
            'fileBased' => [QuestionType::FileBased, QuestionCheckingMode::Manual],
            'matching' => [QuestionType::Matching, QuestionCheckingMode::Automatic],
            'ordering' => [QuestionType::Ordering, QuestionCheckingMode::Automatic],
            'fillInBlank' => [QuestionType::FillInBlank, QuestionCheckingMode::Automatic],
        ];

        foreach ($states as $state => [$type, $mode]) {
            $question = Question::factory()->{$state}()->create();
            $this->assertSame($type, $question->type);
            $this->assertSame($mode, $question->checking_mode);
            $this->assertSame($question->institution_id, $question->assessment->institution_id);
        }

        $children = [
            QuestionChoiceOption::factory()->create(),
            QuestionTrueFalseAnswer::factory()->create(),
            QuestionShortAcceptedAnswer::factory()->create(),
            QuestionMatchingItem::factory()->left()->create(),
            QuestionMatchingItem::factory()->right()->create(),
            QuestionOrderingItem::factory()->create(),
            QuestionFillBlank::factory()->create(),
        ];

        foreach ($children as $child) {
            $this->assertSame($child->institution_id, $child->question->institution_id);
        }

        $answer = QuestionFillBlankAcceptedAnswer::factory()->create();
        $this->assertSame($answer->institution_id, $answer->blank->institution_id);
    }
}
