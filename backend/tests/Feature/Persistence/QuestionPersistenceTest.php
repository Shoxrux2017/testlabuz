<?php

namespace Tests\Feature\Persistence;

use App\Models\Assessment;
use App\Models\Institution;
use App\Models\Question;
use App\Models\QuestionChoiceOption;
use App\Models\QuestionFillBlank;
use App\Models\QuestionFillBlankAcceptedAnswer;
use App\Models\QuestionMatchingItem;
use App\Models\QuestionOrderingItem;
use App\Models\QuestionShortAcceptedAnswer;
use App\Models\QuestionTrueFalseAnswer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class QuestionPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_questions_persist_and_reject_invalid_values_duplicate_positions_and_cross_tenant_assessments(): void
    {
        $question = Question::factory()->create(['points' => '0.000000', 'position' => 0]);
        $this->assertDatabaseHas('questions', ['id' => $question->id, 'type' => 'single_choice']);

        foreach ([
            ['type' => 'essay'],
            ['checking_mode' => 'hybrid'],
            ['prompt' => '   '],
            ['instructions' => '   '],
            ['points' => '-0.000001'],
            ['position' => -1],
        ] as $attributes) {
            $this->assertDatabaseRejects(fn () => DB::table('questions')->where('id', $question->id)->update($attributes));
        }

        $assessment = Assessment::factory()->create();
        Question::factory()->create(['assessment_id' => $assessment, 'institution_id' => $assessment->institution_id, 'position' => 1]);
        $this->assertDatabaseRejects(fn () => Question::factory()->create([
            'assessment_id' => $assessment,
            'institution_id' => $assessment->institution_id,
            'position' => 1,
        ]));

        $foreignAssessment = Assessment::factory()->create();
        $this->assertDatabaseRejects(fn () => Question::factory()->create([
            'institution_id' => $assessment->institution_id,
            'assessment_id' => $foreignAssessment,
            'position' => 2,
        ]));
    }

    public function test_choice_true_false_and_short_answer_constraints_are_enforced(): void
    {
        $choiceQuestion = Question::factory()->singleChoice()->create();
        $choice = QuestionChoiceOption::factory()->create([
            'question_id' => $choiceQuestion,
            'institution_id' => $choiceQuestion->institution_id,
            'position' => 0,
        ]);
        $this->assertDatabaseRejects(fn () => DB::table('question_choice_options')->where('id', $choice->id)->update(['option_text' => ' ']));
        $this->assertDatabaseRejects(fn () => DB::table('question_choice_options')->where('id', $choice->id)->update(['position' => -1]));
        $this->assertDatabaseRejects(fn () => QuestionChoiceOption::factory()->create([
            'question_id' => $choiceQuestion,
            'institution_id' => $choiceQuestion->institution_id,
            'position' => 0,
        ]));

        $trueFalse = QuestionTrueFalseAnswer::factory()->create();
        $this->assertDatabaseRejects(fn () => QuestionTrueFalseAnswer::factory()->create([
            'question_id' => $trueFalse->question_id,
            'institution_id' => $trueFalse->institution_id,
        ]));

        $short = QuestionShortAcceptedAnswer::factory()->create(['position' => 0]);
        $this->assertDatabaseRejects(fn () => DB::table('question_short_accepted_answers')->where('id', $short->id)->update(['accepted_text' => ' ']));
        $this->assertDatabaseRejects(fn () => QuestionShortAcceptedAnswer::factory()->create([
            'question_id' => $short->question_id,
            'institution_id' => $short->institution_id,
            'position' => 0,
        ]));
    }

    public function test_matching_ordering_and_fill_blank_structural_constraints_are_enforced(): void
    {
        $matchingQuestion = Question::factory()->matching()->create();
        $matchKey = Str::uuid()->toString();
        $left = QuestionMatchingItem::factory()->left()->create([
            'question_id' => $matchingQuestion,
            'institution_id' => $matchingQuestion->institution_id,
            'match_key' => $matchKey,
            'position' => 0,
        ]);
        QuestionMatchingItem::factory()->right()->create([
            'question_id' => $matchingQuestion,
            'institution_id' => $matchingQuestion->institution_id,
            'match_key' => $matchKey,
            'position' => 0,
        ]);

        foreach ([
            ['side' => 'middle'], ['item_text' => ' '], ['position' => -1],
        ] as $attributes) {
            $this->assertDatabaseRejects(fn () => DB::table('question_matching_items')->where('id', $left->id)->update($attributes));
        }

        $this->assertDatabaseRejects(fn () => QuestionMatchingItem::factory()->left()->create([
            'question_id' => $matchingQuestion,
            'institution_id' => $matchingQuestion->institution_id,
            'position' => 0,
        ]));
        $this->assertDatabaseRejects(fn () => QuestionMatchingItem::factory()->left()->create([
            'question_id' => $matchingQuestion,
            'institution_id' => $matchingQuestion->institution_id,
            'position' => 1,
            'match_key' => $matchKey,
        ]));

        $ordering = QuestionOrderingItem::factory()->create(['correct_position' => 0]);
        $this->assertDatabaseRejects(fn () => DB::table('question_ordering_items')->where('id', $ordering->id)->update(['item_text' => ' ']));
        $this->assertDatabaseRejects(fn () => DB::table('question_ordering_items')->where('id', $ordering->id)->update(['correct_position' => -1]));
        $this->assertDatabaseRejects(fn () => QuestionOrderingItem::factory()->create([
            'question_id' => $ordering->question_id,
            'institution_id' => $ordering->institution_id,
            'correct_position' => 0,
        ]));

        $blank = QuestionFillBlank::factory()->create(['blank_key' => 'item-1', 'position' => 0]);
        foreach (['', '1item', 'item.key', 'item key', '{item}', str_repeat('a', 81)] as $invalidKey) {
            $this->assertDatabaseRejects(fn () => DB::table('question_fill_blanks')->where('id', $blank->id)->update(['blank_key' => $invalidKey]));
        }
        $this->assertDatabaseRejects(fn () => QuestionFillBlank::factory()->create([
            'question_id' => $blank->question_id,
            'institution_id' => $blank->institution_id,
            'blank_key' => $blank->blank_key,
            'position' => 1,
        ]));
        $this->assertDatabaseRejects(fn () => QuestionFillBlank::factory()->create([
            'question_id' => $blank->question_id,
            'institution_id' => $blank->institution_id,
            'blank_key' => 'other',
            'position' => 0,
        ]));

        $answer = QuestionFillBlankAcceptedAnswer::factory()->create(['blank_id' => $blank, 'institution_id' => $blank->institution_id, 'position' => 0]);
        $this->assertDatabaseRejects(fn () => DB::table('question_fill_blank_accepted_answers')->where('id', $answer->id)->update(['accepted_text' => ' ']));
        $this->assertDatabaseRejects(fn () => QuestionFillBlankAcceptedAnswer::factory()->create([
            'blank_id' => $blank,
            'institution_id' => $blank->institution_id,
            'position' => 0,
        ]));
    }

    public function test_every_tenant_owned_child_rejects_a_cross_institution_parent(): void
    {
        $institution = Institution::factory()->create();
        $foreignQuestion = Question::factory()->create();
        $foreignBlank = QuestionFillBlank::factory()->create();

        $operations = [
            fn () => QuestionChoiceOption::factory()->create(['institution_id' => $institution, 'question_id' => $foreignQuestion]),
            fn () => QuestionTrueFalseAnswer::factory()->create(['institution_id' => $institution, 'question_id' => $foreignQuestion]),
            fn () => QuestionShortAcceptedAnswer::factory()->create(['institution_id' => $institution, 'question_id' => $foreignQuestion]),
            fn () => QuestionMatchingItem::factory()->create(['institution_id' => $institution, 'question_id' => $foreignQuestion]),
            fn () => QuestionOrderingItem::factory()->create(['institution_id' => $institution, 'question_id' => $foreignQuestion]),
            fn () => QuestionFillBlank::factory()->create(['institution_id' => $institution, 'question_id' => $foreignQuestion]),
            fn () => QuestionFillBlankAcceptedAnswer::factory()->create(['institution_id' => $institution, 'blank_id' => $foreignBlank]),
        ];

        foreach ($operations as $operation) {
            $this->assertDatabaseRejects($operation);
        }
    }

    public function test_restrictive_foreign_keys_preserve_question_configuration_history(): void
    {
        $question = Question::factory()->fillInBlank()->create();
        $blank = QuestionFillBlank::factory()->create([
            'question_id' => $question,
            'institution_id' => $question->institution_id,
        ]);
        QuestionFillBlankAcceptedAnswer::factory()->create([
            'blank_id' => $blank,
            'institution_id' => $blank->institution_id,
        ]);

        $this->assertDatabaseRejects(fn () => $blank->delete());
        $this->assertDatabaseRejects(fn () => $question->delete());
        $this->assertDatabaseRejects(fn () => $question->assessment->delete());
        $this->assertDatabaseRejects(fn () => $question->institution->delete());
    }
}
