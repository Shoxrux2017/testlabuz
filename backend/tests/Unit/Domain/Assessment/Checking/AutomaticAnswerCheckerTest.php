<?php

namespace Tests\Unit\Domain\Assessment\Checking;

use App\Domain\Assessment\Checking\AutomaticAnswerChecker;
use Closure;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class AutomaticAnswerCheckerTest extends TestCase
{
    private AutomaticAnswerChecker $checker;

    protected function setUp(): void
    {
        $this->checker = new AutomaticAnswerChecker;
    }

    public function test_single_choice_is_all_or_nothing(): void
    {
        $options = ['opt-a' => false, 'OPT-B' => true, 'opt-c' => false];

        $this->assertSame('2.00000000', $this->checker->singleChoice('2.000000', $options, ['opt-B']));
        $this->assertSame('0.00000000', $this->checker->singleChoice('2.000000', $options, ['opt-a']));
        $this->assertSame('0.00000000', $this->checker->singleChoice('0.000000', $options, ['opt-b']));
    }

    public function test_multiple_choice_awards_the_share_of_correct_options_selected(): void
    {
        $options = ['a' => true, 'b' => true, 'C' => true, 'x' => false];

        $this->assertSame('3.00000000', $this->checker->multipleChoice('3', $options, ['c', 'a', 'b']));
        $this->assertSame('2.00000000', $this->checker->multipleChoice('3', $options, ['a', 'b']));
        $this->assertSame('1.00000000', $this->checker->multipleChoice('3', $options, ['A']));
        $this->assertSame('0.66666667', $this->checker->multipleChoice('1', $options, ['a', 'b']));
    }

    public function test_a_wrong_multiple_choice_selection_earns_and_deducts_nothing(): void
    {
        $options = ['a' => true, 'b' => true, 'x' => false, 'y' => false];

        $this->assertSame('1.00000000', $this->checker->multipleChoice('2', $options, ['a', 'x']));
        $this->assertSame('0.00000000', $this->checker->multipleChoice('2', $options, ['x']));
        // More selections than correct options is a save-time rule; checking still counts only correct ones.
        $this->assertSame('2.00000000', $this->checker->multipleChoice('2', $options, ['a', 'b', 'x']));
    }

    public function test_true_false_is_all_or_nothing(): void
    {
        $this->assertSame('1.50000000', $this->checker->trueFalse('1.5', true, true));
        $this->assertSame('1.50000000', $this->checker->trueFalse('1.5', false, false));
        $this->assertSame('0.00000000', $this->checker->trueFalse('1.5', true, false));
    }

    public function test_short_written_matches_any_accepted_answer_after_normalization(): void
    {
        $accepted = ['Toshkent', "O\u{2018}zbekiston"];

        $this->assertSame('4.00000000', $this->checker->shortWritten('4', $accepted, '  TOSHKENT '));
        $this->assertSame('4.00000000', $this->checker->shortWritten('4', $accepted, "o\u{02BB}zbekiston"));
        $this->assertSame('0.00000000', $this->checker->shortWritten('4', $accepted, 'Toshkent.'));
        $this->assertSame('0.00000000', $this->checker->shortWritten('4', $accepted, 'Samarqand'));
    }

    public function test_matching_awards_the_share_of_correct_pairs_over_all_left_items(): void
    {
        $left = ['L1' => 'k1', 'l2' => 'k2', 'l3' => 'k3', 'l4' => 'k4'];
        $right = ['r1' => 'K1', 'R2' => 'k2', 'r3' => 'k3', 'r4' => 'k4'];

        $this->assertSame('4.00000000', $this->checker->matching('4', $left, $right, [
            ['left_item_id' => 'l1', 'right_item_id' => 'R1'],
            ['left_item_id' => 'l2', 'right_item_id' => 'r2'],
            ['left_item_id' => 'l3', 'right_item_id' => 'r3'],
            ['left_item_id' => 'l4', 'right_item_id' => 'r4'],
        ]));
        // Two correct, one wrong, one left item unmatched.
        $this->assertSame('2.00000000', $this->checker->matching('4', $left, $right, [
            ['left_item_id' => 'l1', 'right_item_id' => 'r1'],
            ['left_item_id' => 'l2', 'right_item_id' => 'r2'],
            ['left_item_id' => 'l3', 'right_item_id' => 'r4'],
        ]));
        $this->assertSame('0.00000000', $this->checker->matching('4', $left, $right, [
            ['left_item_id' => 'l1', 'right_item_id' => 'r2'],
        ]));
    }

    public function test_ordering_counts_only_items_at_their_exact_position(): void
    {
        $correct = ['i1' => 1, 'I2' => 2, 'i3' => 3];

        $this->assertSame('3.00000000', $this->checker->ordering('3', $correct, [
            ['item_id' => 'i1', 'position' => 1],
            ['item_id' => 'i2', 'position' => 2],
            ['item_id' => 'I3', 'position' => 3],
        ]));
        // Shifted by one: nothing is at its exact position.
        $this->assertSame('0.00000000', $this->checker->ordering('3', $correct, [
            ['item_id' => 'i3', 'position' => 1],
            ['item_id' => 'i1', 'position' => 2],
            ['item_id' => 'i2', 'position' => 3],
        ]));
        // Partial answer: one item placed correctly, the others unplaced.
        $this->assertSame('1.00000000', $this->checker->ordering('3', $correct, [
            ['item_id' => 'i2', 'position' => 2],
        ]));
    }

    public function test_fill_in_blank_awards_the_share_of_correct_blanks_over_all_blanks(): void
    {
        $accepted = [
            'b1' => ['Paris'],
            'B2' => ['ikki', '2'],
            'b3' => ["o'n"],
        ];

        $this->assertSame('3.00000000', $this->checker->fillInBlank('3', $accepted, [
            ['blank_id' => 'b1', 'text' => ' PARIS'],
            ['blank_id' => 'b2', 'text' => '2'],
            ['blank_id' => 'B3', 'text' => "O\u{2019}N"],
        ]));
        // One wrong, one correct, one unfilled.
        $this->assertSame('1.00000000', $this->checker->fillInBlank('3', $accepted, [
            ['blank_id' => 'b1', 'text' => 'London'],
            ['blank_id' => 'b2', 'text' => 'Ikki'],
        ]));
        $this->assertSame('0.33333333', $this->checker->fillInBlank('1', $accepted, [
            ['blank_id' => 'b1', 'text' => 'paris'],
        ]));
    }

    /** @return array<string, array{Closure(AutomaticAnswerChecker): mixed}> */
    public static function integrityErrors(): array
    {
        $options = ['a' => true, 'b' => false];
        $pair = fn (string $left, string $right): array => ['left_item_id' => $left, 'right_item_id' => $right];
        $left = ['l1' => 'k1', 'l2' => 'k2'];
        $right = ['r1' => 'k1', 'r2' => 'k2'];
        $placed = fn (string $item, int $position): array => ['item_id' => $item, 'position' => $position];
        $positions = ['i1' => 1, 'i2' => 2];
        $filled = fn (string $blank, string $text): array => ['blank_id' => $blank, 'text' => $text];
        $blanks = ['b1' => ['a'], 'b2' => ['b']];

        return [
            'single choice without a selection' => [fn (AutomaticAnswerChecker $c) => $c->singleChoice('1', $options, [])],
            'single choice with two selections' => [fn (AutomaticAnswerChecker $c) => $c->singleChoice('1', $options, ['a', 'b'])],
            'single choice with an unknown option' => [fn (AutomaticAnswerChecker $c) => $c->singleChoice('1', $options, ['z'])],
            'single choice without options' => [fn (AutomaticAnswerChecker $c) => $c->singleChoice('1', [], ['a'])],
            'single choice without a correct option' => [fn (AutomaticAnswerChecker $c) => $c->singleChoice('1', ['a' => false, 'b' => false], ['a'])],
            'single choice with two correct options' => [fn (AutomaticAnswerChecker $c) => $c->singleChoice('1', ['a' => true, 'b' => true], ['a'])],
            'multiple choice without a correct option' => [fn (AutomaticAnswerChecker $c) => $c->multipleChoice('1', ['a' => false], ['a'])],
            'multiple choice with a repeated option id' => [fn (AutomaticAnswerChecker $c) => $c->multipleChoice('1', ['a' => true, 'A' => true], ['a'])],
            'multiple choice without a selection' => [fn (AutomaticAnswerChecker $c) => $c->multipleChoice('1', $options, [])],
            'multiple choice with a duplicate selection' => [fn (AutomaticAnswerChecker $c) => $c->multipleChoice('1', $options, ['a', 'A'])],
            'multiple choice with an unknown option' => [fn (AutomaticAnswerChecker $c) => $c->multipleChoice('1', $options, ['a', 'z'])],
            'short written without accepted answers' => [fn (AutomaticAnswerChecker $c) => $c->shortWritten('1', [], 'x')],
            'matching without left items' => [fn (AutomaticAnswerChecker $c) => $c->matching('1', [], $right, [$pair('l1', 'r1')])],
            'matching without pairs' => [fn (AutomaticAnswerChecker $c) => $c->matching('1', $left, $right, [])],
            'matching with an unknown left item' => [fn (AutomaticAnswerChecker $c) => $c->matching('1', $left, $right, [$pair('lx', 'r1')])],
            'matching with an unknown right item' => [fn (AutomaticAnswerChecker $c) => $c->matching('1', $left, $right, [$pair('l1', 'rx')])],
            'matching with a left item used twice' => [fn (AutomaticAnswerChecker $c) => $c->matching('1', $left, $right, [$pair('l1', 'r1'), $pair('L1', 'r2')])],
            'matching with a right item used twice' => [fn (AutomaticAnswerChecker $c) => $c->matching('1', $left, $right, [$pair('l1', 'r1'), $pair('l2', 'R1')])],
            'ordering without items in the key' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', [], [$placed('i1', 1)])],
            'ordering without placed items' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', $positions, [])],
            'ordering with an unknown item' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', $positions, [$placed('ix', 1)])],
            'ordering with an item placed twice' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', $positions, [$placed('i1', 1), $placed('I1', 2)])],
            'ordering with a position used twice' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', $positions, [$placed('i1', 1), $placed('i2', 1)])],
            'ordering with position zero' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', $positions, [$placed('i1', 0)])],
            'ordering with a position after the last item' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', $positions, [$placed('i1', 3)])],
            'ordering with a non-integer placed position' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', $positions, [['item_id' => 'i1', 'position' => '1']])],
            'ordering with a non-integer correct position' => [fn (AutomaticAnswerChecker $c) => $c->ordering('1', ['i1' => '1', 'i2' => 2], [$placed('i1', 1)])],
            'fill in blank without blanks' => [fn (AutomaticAnswerChecker $c) => $c->fillInBlank('1', [], [$filled('b1', 'a')])],
            'fill in blank without accepted answers for a filled blank' => [fn (AutomaticAnswerChecker $c) => $c->fillInBlank('1', ['b1' => []], [$filled('b1', 'a')])],
            'fill in blank without accepted answers for an unfilled blank' => [fn (AutomaticAnswerChecker $c) => $c->fillInBlank('1', ['b1' => ['a'], 'b2' => []], [$filled('b1', 'a')])],
            'fill in blank without values' => [fn (AutomaticAnswerChecker $c) => $c->fillInBlank('1', $blanks, [])],
            'fill in blank with an unknown blank' => [fn (AutomaticAnswerChecker $c) => $c->fillInBlank('1', $blanks, [$filled('bx', 'a')])],
            'fill in blank with a blank filled twice' => [fn (AutomaticAnswerChecker $c) => $c->fillInBlank('1', $blanks, [$filled('b1', 'a'), $filled('B1', 'a')])],
            'invalid points' => [fn (AutomaticAnswerChecker $c) => $c->trueFalse('one', true, true)],
        ];
    }

    /** @param Closure(AutomaticAnswerChecker): mixed $check */
    #[DataProvider('integrityErrors')]
    public function test_an_answer_that_breaks_saved_answer_integrity_is_never_scored(Closure $check): void
    {
        $this->expectException(LogicException::class);

        $check($this->checker);
    }
}
