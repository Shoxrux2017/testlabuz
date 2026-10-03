<?php

namespace Tests\Unit\Domain\Results;

use App\Domain\Results\TopicResultMath;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class TopicResultMathTest extends TestCase
{
    private TopicResultMath $math;

    protected function setUp(): void
    {
        $this->math = new TopicResultMath;
    }

    public function test_difference_is_exact_and_ignores_which_score_is_higher(): void
    {
        $this->assertSame('4.00000000', $this->math->difference('88.00000000', '84.00000000'));
        $this->assertSame('37.00000000', $this->math->difference('45', '82'));
        $this->assertSame('10.00000001', $this->math->difference('80.00000001', '70'));
        $this->assertSame('0.00000000', $this->math->difference('55.55555556', '55.55555556'));
    }

    public function test_exceeds_compares_exact_values(): void
    {
        $this->assertFalse($this->math->exceeds('10.00000000', '10'));
        $this->assertTrue($this->math->exceeds('10.00000001', '10'));
        $this->assertFalse($this->math->exceeds('9.99999999', '10.00000000'));
    }

    public function test_exact_average_keeps_the_ninth_decimal(): void
    {
        $this->assertSame('86', $this->math->exactAverage('88.00000000', '84.00000000'));
        $this->assertSame('85.5', $this->math->exactAverage('85', '86'));
        $this->assertSame('85.500000005', $this->math->exactAverage('85.00000000', '86.00000001'));
    }

    public function test_stored_score_is_rounded_half_up_to_eight_decimals(): void
    {
        $this->assertSame('86.00000000', $this->math->storedScore('86'));
        $this->assertSame('85.50000001', $this->math->storedScore('85.500000005'));
        $this->assertSame('85.04999999', $this->math->storedScore('85.049999985'));
        $this->assertSame('100.00000000', $this->math->storedScore('100'));
    }

    /** @return array<string, array{string, int}> */
    public static function categoryScores(): array
    {
        return [
            'whole number' => ['85', 85],
            'whole number with decimals' => ['85.00000000', 85],
            'below one half' => ['85.49999999', 85],
            'exactly one half rounds down' => ['85.5', 85],
            'one half with trailing zeros rounds down' => ['85.50000000', 85],
            'just above one half in the ninth decimal rounds up' => ['85.500000005', 86],
            'above one half rounds up' => ['85.50000001', 86],
            'zero' => ['0', 0],
            'zero point five rounds down' => ['0.5', 0],
            'top of the scale' => ['100', 100],
            'just above ninety-nine and a half rounds up' => ['99.50000001', 100],
        ];
    }

    #[DataProvider('categoryScores')]
    public function test_category_score_rounds_one_half_down_and_above_one_half_up(string $final, int $expected): void
    {
        $this->assertSame($expected, $this->math->categoryScore($final));
    }

    /** @return array<string, array{string}> */
    public static function invalidScores(): array
    {
        return [
            'negative' => ['-1'],
            'nine decimals' => ['1.000000001'],
            'exponent' => ['1e2'],
            'empty' => [''],
            'above one hundred' => ['100.00000001'],
        ];
    }

    #[DataProvider('invalidScores')]
    public function test_scores_outside_the_0_to_100_eight_decimal_scale_are_rejected(string $score): void
    {
        $this->expectException(LogicException::class);

        $this->math->difference($score, '50');
    }

    public function test_category_score_rejects_a_value_with_more_than_nine_decimals(): void
    {
        $this->expectException(LogicException::class);

        $this->math->categoryScore('85.5000000001');
    }
}
