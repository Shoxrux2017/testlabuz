<?php

namespace Tests\Unit\Domain\Assessment\Checking;

use App\Domain\Assessment\Checking\CheckingScoreMath;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class CheckingScoreMathTest extends TestCase
{
    private CheckingScoreMath $math;

    protected function setUp(): void
    {
        $this->math = new CheckingScoreMath;
    }

    public function test_partial_points_are_computed_in_one_step_and_rounded_half_up(): void
    {
        $this->assertSame('0.33333333', $this->math->partialPoints('1.000000', 1, 3));
        $this->assertSame('1.33333333', $this->math->partialPoints('2', 2, 3));
        // One step: 1 × 2 / 3, not (1 / 3 rounded) × 2.
        $this->assertSame('0.66666667', $this->math->partialPoints('1', 2, 3));
        $this->assertSame('0.00000001', $this->math->partialPoints('0.000001', 1, 200));
        $this->assertSame('0.00000000', $this->math->partialPoints('0.000001', 49, 10000));
    }

    public function test_full_and_zero_credit_are_exact(): void
    {
        $this->assertSame('2.50000000', $this->math->partialPoints('2.500000', 3, 3));
        $this->assertSame('1.00000000', $this->math->partialPoints('1', 7, 7));
        $this->assertSame('0.00000000', $this->math->partialPoints('5', 0, 4));
        $this->assertSame('0.00000000', $this->math->partialPoints('0.000000', 1, 1));
    }

    /** @return array<string, array{string, int, int}> */
    public static function invalidPartialArguments(): array
    {
        return [
            'more correct than total' => ['1', 4, 3],
            'negative correct' => ['1', -1, 3],
            'zero total' => ['1', 0, 0],
            'negative points' => ['-1', 1, 1],
            'exponent points' => ['1e3', 1, 1],
            'padded points' => [' 1', 1, 1],
            'empty points' => ['', 1, 1],
            'trailing dot' => ['1.', 1, 1],
            'nine fractional digits' => ['0.123456789', 1, 1],
        ];
    }

    #[DataProvider('invalidPartialArguments')]
    public function test_invalid_partial_arguments_throw(string $points, int $correct, int $total): void
    {
        $this->expectException(LogicException::class);

        $this->math->partialPoints($points, $correct, $total);
    }

    public function test_sums_are_exact(): void
    {
        $this->assertSame('0.30000000', $this->math->sum(['0.1', '0.2']));
        $this->assertSame('1.00000000', $this->math->sum(['0.33333333', '0.33333333', '0.33333334']));
        $this->assertSame('0.00000000', $this->math->sum([]));
    }

    /** @return array<string, array{list<string>}> */
    public static function invalidSummands(): array
    {
        return [
            'not a number' => [['1', 'x']],
            'nine fractional digits' => [['0.000000001']],
            'halves that would sum exactly' => [['0.000000005', '0.000000005']],
        ];
    }

    /** @param list<string> $summands */
    #[DataProvider('invalidSummands')]
    public function test_an_invalid_summand_throws(array $summands): void
    {
        $this->expectException(LogicException::class);

        $this->math->sum($summands);
    }

    public function test_normalized_scores_are_rounded_half_up_once(): void
    {
        $this->assertSame('83.33333333', $this->math->normalizedScore('2.50000000', '3.000000'));
        $this->assertSame('66.66666667', $this->math->normalizedScore('2', '3'));
        $this->assertSame('100.00000000', $this->math->normalizedScore('3', '3'));
        $this->assertSame('0.00000000', $this->math->normalizedScore('0', '3'));
        $this->assertSame('33.33333300', $this->math->normalizedScore('0.33333333', '1'));
        // Exact ties at the ninth digit round up, not to even.
        $this->assertSame('0.00000001', $this->math->normalizedScore('0.00000001', '200'));
        $this->assertSame('0.00000013', $this->math->normalizedScore('0.00000001', '8'));
    }

    public function test_scores_compare_as_exact_decimals(): void
    {
        $this->assertSame(-1, $this->math->compare('83.33333333', '83.33333334'));
        $this->assertSame(0, $this->math->compare('100', '100.00000000'));
        $this->assertSame(-1, $this->math->compare('9.5', '10.00000000'));
        // Beyond double precision: a float comparison would call these equal.
        $this->assertSame(-1, $this->math->compare('99999999.99999998', '99999999.99999999'));
        $this->assertSame(1, $this->math->compare('0.1', '0.09999999'));
    }

    public function test_an_invalid_comparison_operand_throws(): void
    {
        $this->expectException(LogicException::class);

        $this->math->compare('1', '1e2');
    }

    /** @return array<string, array{string, string}> */
    public static function invalidNormalizedArguments(): array
    {
        return [
            'zero possible' => ['0', '0'],
            'earned above possible' => ['3.00000001', '3'],
            'invalid earned' => ['abc', '3'],
            'negative earned' => ['-1', '3'],
            'invalid possible' => ['1', '3,0'],
        ];
    }

    #[DataProvider('invalidNormalizedArguments')]
    public function test_invalid_normalized_arguments_throw(string $earned, string $possible): void
    {
        $this->expectException(LogicException::class);

        $this->math->normalizedScore($earned, $possible);
    }
}
