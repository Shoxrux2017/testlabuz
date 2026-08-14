<?php

namespace Tests\Unit\Domain\Institution;

use App\Domain\Institution\UnderstandingCategorySetValidator;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

class UnderstandingCategorySetValidatorTest extends TestCase
{
    private UnderstandingCategorySetValidator $validator;

    protected function setUp(): void
    {
        parent::setUp();

        $this->validator = new UnderstandingCategorySetValidator;
    }

    public function test_valid_partitions_are_returned_in_canonical_fixed_order(): void
    {
        foreach ([
            [[86, 100], [71, 85], [51, 70], [0, 50]],
            [[100, 100], [99, 99], [1, 98], [0, 0]],
            [[76, 100], [51, 75], [26, 50], [0, 25]],
        ] as $ranges) {
            $input = array_reverse($this->validSet($ranges));
            $canonical = $this->validator->validate($input);

            $this->assertSame([
                'understood_well',
                'partially_understood',
                'needs_revision',
                'needs_teacher_support',
                'not_completed',
            ], array_column($canonical, 'code'));
            $this->assertSame([1, 2, 3, 4, 5], array_column($canonical, 'sort_order'));
        }
    }

    public function test_every_incomplete_code_order_type_bound_and_partition_failure_is_rejected(): void
    {
        $valid = $this->validSet();
        $invalidSets = [];

        $invalidSets['wrong count'] = array_slice($valid, 0, 4);
        $invalidSets['extra entry'] = [...$valid, $valid[0]];
        $invalidSets['duplicate code'] = array_replace($valid, [1 => $valid[0]]);
        $invalidSets['unknown code'] = $this->replace($valid, 0, ['code' => 'excellent']);
        $invalidSets['missing code key'] = $this->withoutKey($valid, 0, 'code');
        $invalidSets['unknown key'] = $this->replace($valid, 0, ['label' => 'Understood well']);
        $invalidSets['wrong sort'] = $this->replace($valid, 0, ['sort_order' => 2]);
        $invalidSets['duplicate sort'] = $this->replace($valid, 1, ['sort_order' => 1]);
        $invalidSets['string sort'] = $this->replace($valid, 0, ['sort_order' => '1']);
        $invalidSets['numeric string'] = $this->replace($valid, 0, ['min_score' => '86']);
        $invalidSets['float'] = $this->replace($valid, 0, ['min_score' => 86.0]);
        $invalidSets['boolean'] = $this->replace($valid, 0, ['min_score' => true]);
        $invalidSets['numeric null'] = $this->replace($valid, 0, ['min_score' => null]);
        $invalidSets['negative'] = $this->replace($valid, 3, ['min_score' => -1]);
        $invalidSets['above 100'] = $this->replace($valid, 0, ['max_score' => 101]);
        $invalidSets['reversed'] = $this->replace($valid, 1, ['min_score' => 90]);
        $invalidSets['first max'] = $this->replace($valid, 0, ['max_score' => 99]);
        $invalidSets['last min'] = $this->replace($valid, 3, ['min_score' => 1]);
        $invalidSets['gap'] = $this->replace($valid, 1, ['max_score' => 84]);
        $invalidSets['overlap'] = $this->replace($valid, 1, ['max_score' => 86]);
        $invalidSets['non-null not completed minimum'] = $this->replace($valid, 4, ['min_score' => 0]);
        $invalidSets['non-null not completed maximum'] = $this->replace($valid, 4, ['max_score' => 0]);
        $invalidSets['non-array entry'] = array_replace($valid, [0 => 'understood_well']);

        foreach ($invalidSets as $case => $invalidSet) {
            try {
                $this->validator->validate($invalidSet);
            } catch (InvalidArgumentException $exception) {
                $this->assertSame('Invalid understanding category configuration.', $exception->getMessage(), $case);

                continue;
            }

            $this->fail("Expected invalid set to be rejected: {$case}");
        }
    }

    /**
     * @param  list<array{0: int, 1: int}>  $ranges
     * @return list<array{code: string, min_score: ?int, max_score: ?int, sort_order: int}>
     */
    private function validSet(array $ranges = [[86, 100], [71, 85], [51, 70], [0, 50]]): array
    {
        $codes = [
            'understood_well',
            'partially_understood',
            'needs_revision',
            'needs_teacher_support',
        ];
        $entries = [];

        foreach ($codes as $index => $code) {
            $entries[] = [
                'code' => $code,
                'min_score' => $ranges[$index][0],
                'max_score' => $ranges[$index][1],
                'sort_order' => $index + 1,
            ];
        }

        $entries[] = [
            'code' => 'not_completed',
            'min_score' => null,
            'max_score' => null,
            'sort_order' => 5,
        ];

        return $entries;
    }

    /**
     * @param  list<mixed>  $set
     * @param  array<string, mixed>  $replacement
     * @return list<mixed>
     */
    private function replace(array $set, int $index, array $replacement): array
    {
        $set[$index] = array_replace($set[$index], $replacement);

        return $set;
    }

    /**
     * @param  list<array<string, mixed>>  $set
     * @return list<array<string, mixed>>
     */
    private function withoutKey(array $set, int $index, string $key): array
    {
        unset($set[$index][$key]);

        return $set;
    }
}
