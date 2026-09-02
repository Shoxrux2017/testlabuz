<?php

namespace Tests\Unit\Domain\Assessment;

use App\Domain\Assessment\AssessmentPointMath;
use PHPUnit\Framework\TestCase;

class AssessmentPointMathTest extends TestCase
{
    public function test_it_normalizes_every_valid_fractional_scale_from_one_through_six(): void
    {
        $math = new AssessmentPointMath;

        foreach ([
            '1.1' => '1.100000',
            '1.12' => '1.120000',
            '1.123' => '1.123000',
            '1.1234' => '1.123400',
            '1.12345' => '1.123450',
            '1.123456' => '1.123456',
        ] as $points => $expected) {
            $this->assertSame($expected, $math->sum([$points]));
        }
    }

    public function test_it_sums_integer_and_scale_six_points_exactly(): void
    {
        $math = new AssessmentPointMath;

        $this->assertSame('6.123456', $math->sum([1, 2, '3.123456']));
        $this->assertSame('0.000001', $math->sum(['0.000001']));
        $this->assertSame('0.000000', $math->sum([0]));
    }

    public function test_decimal_tenths_do_not_accumulate_binary_float_drift(): void
    {
        $this->assertSame('0.300000', (new AssessmentPointMath)->sum([0.1, 0.2]));
    }

    public function test_maximum_safe_one_hundred_question_aggregate_is_exact(): void
    {
        $points = array_fill(0, 100, '999999.999999');

        $this->assertSame('99999999.999900', (new AssessmentPointMath)->sum($points));
    }
}
