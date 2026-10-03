<?php

namespace Tests\Unit\Domain\Results;

use App\Domain\Results\CategoryBand;
use App\Domain\Results\TopicResultCalculator;
use App\Domain\Results\TopicResultMath;
use App\Domain\Results\TopicResultSide;
use App\Enums\TopicResultCalculationMethod;
use App\Enums\TopicResultConsistency;
use App\Enums\TopicResultMissingComponent;
use App\Enums\TopicResultSideState as State;
use App\Enums\TopicResultStatus;
use App\Enums\UnderstandingCategoryCode as Code;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class TopicResultCalculatorTest extends TestCase
{
    private TopicResultCalculator $calculator;

    protected function setUp(): void
    {
        $this->calculator = new TopicResultCalculator(new TopicResultMath);
    }

    public function test_close_scores_average_and_are_consistent(): void
    {
        $result = $this->calculate($this->ready('88.00000000'), $this->ready('84.00000000'));

        $this->assertSame(TopicResultStatus::Calculated, $result->status);
        $this->assertSame('4.00000000', $result->difference);
        $this->assertSame('10.00000000', $result->threshold);
        $this->assertSame(TopicResultCalculationMethod::Average, $result->method);
        $this->assertSame(TopicResultConsistency::Consistent, $result->consistency);
        $this->assertSame('86.00000000', $result->finalScore);
        $this->assertSame(86, $result->categoryScore);
        $this->assertSame(Code::UnderstoodWell, $result->category);
        $this->assertSame([86, 100], [$result->categoryMinScore, $result->categoryMaxScore]);
        $this->assertNull($result->missingComponent);
        $this->assertTrue($result->terminal());
    }

    public function test_large_difference_takes_the_blitz_score_and_is_inconsistent(): void
    {
        $result = $this->calculate($this->ready('92'), $this->ready('58'));

        $this->assertSame(TopicResultCalculationMethod::Blitz, $result->method);
        $this->assertSame(TopicResultConsistency::Inconsistent, $result->consistency);
        $this->assertSame('34.00000000', $result->difference);
        $this->assertSame('58.00000000', $result->finalScore);
        $this->assertSame(Code::NeedsRevision, $result->category);
    }

    public function test_the_same_rule_applies_when_the_blitz_score_is_higher(): void
    {
        $result = $this->calculate($this->ready('45'), $this->ready('82'));

        $this->assertSame(TopicResultCalculationMethod::Blitz, $result->method);
        $this->assertSame('82.00000000', $result->finalScore);
        $this->assertSame(Code::PartiallyUnderstood, $result->category);
    }

    public function test_a_difference_equal_to_the_threshold_is_consistent(): void
    {
        $result = $this->calculate($this->ready('80'), $this->ready('70'));

        $this->assertSame(TopicResultCalculationMethod::Average, $result->method);
        $this->assertSame('75.00000000', $result->finalScore);
    }

    public function test_a_difference_above_the_threshold_only_in_the_eighth_decimal_is_inconsistent(): void
    {
        $result = $this->calculate($this->ready('80.00000001'), $this->ready('70'));

        $this->assertSame('10.00000001', $result->difference);
        $this->assertSame(TopicResultCalculationMethod::Blitz, $result->method);
        $this->assertSame('70.00000000', $result->finalScore);
    }

    public function test_the_category_comes_from_the_exact_final_score_not_the_stored_one(): void
    {
        // exact final 85.500000005: stored 85.50000001, category score 86.
        $result = $this->calculate($this->ready('85.00000000'), $this->ready('86.00000001'));

        $this->assertSame('85.50000001', $result->finalScore);
        $this->assertSame(86, $result->categoryScore);
        $this->assertSame(Code::UnderstoodWell, $result->category);
    }

    public function test_one_half_rounds_down_into_the_lower_category(): void
    {
        $result = $this->calculate($this->ready('85'), $this->ready('86'));

        $this->assertSame('85.50000000', $result->finalScore);
        $this->assertSame(85, $result->categoryScore);
        $this->assertSame(Code::PartiallyUnderstood, $result->category);
    }

    public function test_display_rounding_never_changes_the_category(): void
    {
        // 85.45 shows as 85.5 with one decimal, but the category score stays 85.
        $result = $this->calculate($this->ready('85.4'), $this->ready('85.5'));

        $this->assertSame('85.45000000', $result->finalScore);
        $this->assertSame(85, $result->categoryScore);
        $this->assertSame(Code::PartiallyUnderstood, $result->category);
    }

    /** @return array<string, array{int, int, Code}> */
    public static function categoryBoundaries(): array
    {
        return [
            'zero' => [0, 0, Code::NeedsTeacherSupport],
            'top of the lowest band' => [50, 50, Code::NeedsTeacherSupport],
            'bottom of needs revision' => [51, 51, Code::NeedsRevision],
            'top of needs revision' => [70, 70, Code::NeedsRevision],
            'bottom of partially understood' => [71, 71, Code::PartiallyUnderstood],
            'top of partially understood' => [85, 85, Code::PartiallyUnderstood],
            'bottom of understood well' => [86, 86, Code::UnderstoodWell],
            'one hundred' => [100, 100, Code::UnderstoodWell],
        ];
    }

    #[DataProvider('categoryBoundaries')]
    public function test_category_ranges_are_inclusive_integer_bands(int $homework, int $blitz, Code $expected): void
    {
        $result = $this->calculate($this->ready((string) $homework), $this->ready((string) $blitz));

        $this->assertSame($expected, $result->category);
    }

    /** @return array<string, array{State, State, TopicResultStatus, ?TopicResultMissingComponent}> */
    public static function statusPrecedence(): array
    {
        return [
            'missing homework' => [State::Missing, State::Ready, TopicResultStatus::NotCompleted, TopicResultMissingComponent::Homework],
            'missing blitz' => [State::Ready, State::Missing, TopicResultStatus::NotCompleted, TopicResultMissingComponent::Blitz],
            'both missing' => [State::Missing, State::Missing, TopicResultStatus::NotCompleted, TopicResultMissingComponent::Both],
            'missing homework while the blitz waits for review' => [State::Missing, State::WaitingForTeacherReview, TopicResultStatus::NotCompleted, TopicResultMissingComponent::Homework],
            'missing blitz while the homework is still open' => [State::Open, State::Missing, TopicResultStatus::NotCompleted, TopicResultMissingComponent::Blitz],
            'homework not activated' => [State::NotActivated, State::NotDesignated, TopicResultStatus::WaitingForHomework, null],
            'homework open' => [State::Open, State::Ready, TopicResultStatus::WaitingForHomework, null],
            'homework checking' => [State::Checking, State::WaitingForTeacherReview, TopicResultStatus::WaitingForHomework, null],
            'homework before blitz' => [State::Open, State::Open, TopicResultStatus::WaitingForHomework, null],
            'blitz not designated' => [State::Ready, State::NotDesignated, TopicResultStatus::WaitingForBlitz, null],
            'blitz not activated' => [State::Ready, State::NotActivated, TopicResultStatus::WaitingForBlitz, null],
            'blitz open' => [State::WaitingForTeacherReview, State::Open, TopicResultStatus::WaitingForBlitz, null],
            'blitz checking' => [State::Ready, State::Checking, TopicResultStatus::WaitingForBlitz, null],
            'homework waits for review' => [State::WaitingForTeacherReview, State::Ready, TopicResultStatus::WaitingForTeacherReview, null],
            'blitz waits for review' => [State::Ready, State::WaitingForTeacherReview, TopicResultStatus::WaitingForTeacherReview, null],
        ];
    }

    #[DataProvider('statusPrecedence')]
    public function test_status_precedence(State $homework, State $blitz, TopicResultStatus $status, ?TopicResultMissingComponent $missing): void
    {
        $result = $this->calculate($this->side($homework), $this->side($blitz));

        $this->assertSame($status, $result->status);
        $this->assertSame($missing, $result->missingComponent);
        $this->assertNull($result->difference);
        $this->assertNull($result->threshold);
        $this->assertNull($result->method);
        $this->assertNull($result->consistency);
        $this->assertNull($result->finalScore);
        $this->assertNull($result->categoryScore);
        $this->assertNull($result->categoryMinScore);
        $this->assertNull($result->categoryMaxScore);
        $this->assertSame($status === TopicResultStatus::NotCompleted ? Code::NotCompleted : null, $result->category);
        $this->assertSame($status === TopicResultStatus::NotCompleted, $result->terminal());
    }

    public function test_ready_scores_without_a_threshold_wait_for_settings(): void
    {
        $result = $this->calculator->calculate($this->ready('80'), $this->ready('80'), null, $this->bands());

        $this->assertSame(TopicResultStatus::WaitingForSettings, $result->status);
        $this->assertNull($result->finalScore);
        $this->assertNull($result->category);
        $this->assertFalse($result->terminal());
    }

    public function test_ready_scores_without_a_category_set_wait_for_settings(): void
    {
        $result = $this->calculator->calculate($this->ready('80'), $this->ready('80'), '10.00000000', null);

        $this->assertSame(TopicResultStatus::WaitingForSettings, $result->status);
    }

    public function test_a_missing_side_wins_over_missing_settings(): void
    {
        $result = $this->calculator->calculate($this->side(State::Missing), $this->ready('80'), null, null);

        $this->assertSame(TopicResultStatus::NotCompleted, $result->status);
    }

    public function test_a_ready_side_requires_a_score_and_only_a_ready_side_has_one(): void
    {
        $this->expectException(LogicException::class);

        new TopicResultSide(State::Ready, null);
    }

    public function test_a_waiting_side_cannot_carry_a_score(): void
    {
        $this->expectException(LogicException::class);

        new TopicResultSide(State::Open, '80.00000000');
    }

    private function calculate(TopicResultSide $homework, TopicResultSide $blitz)
    {
        return $this->calculator->calculate($homework, $blitz, '10.00000000', $this->bands());
    }

    private function ready(string $score): TopicResultSide
    {
        return new TopicResultSide(State::Ready, $score);
    }

    private function side(State $state): TopicResultSide
    {
        return new TopicResultSide($state, $state === State::Ready ? '80.00000000' : null);
    }

    /** @return list<CategoryBand> */
    private function bands(): array
    {
        return [
            new CategoryBand(Code::UnderstoodWell, 86, 100),
            new CategoryBand(Code::PartiallyUnderstood, 71, 85),
            new CategoryBand(Code::NeedsRevision, 51, 70),
            new CategoryBand(Code::NeedsTeacherSupport, 0, 50),
        ];
    }
}
