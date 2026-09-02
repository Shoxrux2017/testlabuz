<?php

namespace Tests\Unit\Domain\Assessment;

use App\Domain\Assessment\QuestionPositionSetValidator;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

class QuestionPositionSetValidatorTest extends TestCase
{
    private QuestionPositionSetValidator $validator;

    protected function setUp(): void
    {
        parent::setUp();
        $this->validator = new QuestionPositionSetValidator;
    }

    public function test_valid_canonical_position_sets_and_explicit_empty_set_are_accepted(): void
    {
        $this->validator->validate([1], 1);
        $this->validator->validate([3, 1, 2], 3);
        $this->validator->validate([], 100, true);
        $this->addToAssertionCount(3);
    }

    public function test_invalid_empty_zero_negative_duplicate_gap_non_integer_and_over_limit_sets_are_rejected(): void
    {
        foreach ([
            [[], 10, false],
            [[0], 10, false],
            [[-1], 10, false],
            [[1, 1], 10, false],
            [[1, 3], 10, false],
            [[1, '2'], 10, false],
            [[1, 2.0], 10, false],
            [[1, true], 10, false],
            [[1, 2], 1, false],
            [[], -1, true],
        ] as [$positions, $maximum, $allowEmpty]) {
            try {
                $this->validator->validate($positions, $maximum, $allowEmpty);
            } catch (InvalidArgumentException $exception) {
                $this->assertSame('Invalid question position set.', $exception->getMessage());

                continue;
            }

            $this->fail('Expected invalid positions to be rejected.');
        }
    }
}
