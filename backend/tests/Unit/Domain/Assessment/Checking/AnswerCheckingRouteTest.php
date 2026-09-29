<?php

namespace Tests\Unit\Domain\Assessment\Checking;

use App\Domain\Assessment\Checking\AnswerCheckingRoute;
use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use LogicException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class AnswerCheckingRouteTest extends TestCase
{
    /** @return array<string, array{QuestionType}> */
    public static function automaticTypes(): array
    {
        return [
            'single choice' => [QuestionType::SingleChoice],
            'multiple choice' => [QuestionType::MultipleChoice],
            'true/false' => [QuestionType::TrueFalse],
            'short written' => [QuestionType::ShortWritten],
            'matching' => [QuestionType::Matching],
            'ordering' => [QuestionType::Ordering],
            'fill in blank' => [QuestionType::FillInBlank],
        ];
    }

    #[DataProvider('automaticTypes')]
    public function test_automatic_questions_are_checked_automatically_even_with_zero_points(QuestionType $type): void
    {
        $this->assertSame(
            AnswerCheckingRoute::Automatic,
            AnswerCheckingRoute::resolve($type, QuestionCheckingMode::Automatic, '2.000000'),
        );
        $this->assertSame(
            AnswerCheckingRoute::Automatic,
            AnswerCheckingRoute::resolve($type, QuestionCheckingMode::Automatic, '0.000000'),
        );
    }

    /** @return array<string, array{QuestionType}> */
    public static function manualTypes(): array
    {
        return [
            'short written' => [QuestionType::ShortWritten],
            'open written' => [QuestionType::OpenWritten],
            'file based' => [QuestionType::FileBased],
        ];
    }

    #[DataProvider('manualTypes')]
    public function test_manual_questions_wait_for_review_unless_they_are_worth_zero(QuestionType $type): void
    {
        $this->assertSame(
            AnswerCheckingRoute::TeacherReview,
            AnswerCheckingRoute::resolve($type, QuestionCheckingMode::Manual, '0.000001'),
        );
        $this->assertSame(
            AnswerCheckingRoute::ZeroPointClosed,
            AnswerCheckingRoute::resolve($type, QuestionCheckingMode::Manual, '0.000000'),
        );
        $this->assertSame(
            AnswerCheckingRoute::ZeroPointClosed,
            AnswerCheckingRoute::resolve($type, QuestionCheckingMode::Manual, '0'),
        );
    }

    public function test_route_values_are_stable(): void
    {
        $this->assertSame(
            ['automatic', 'teacher_review', 'zero_point_closed'],
            array_map(fn (AnswerCheckingRoute $route): string => $route->value, AnswerCheckingRoute::cases()),
        );
    }

    /** @return array<string, array{QuestionType, QuestionCheckingMode}> */
    public static function invalidCombinations(): array
    {
        return [
            'manual single choice' => [QuestionType::SingleChoice, QuestionCheckingMode::Manual],
            'manual multiple choice' => [QuestionType::MultipleChoice, QuestionCheckingMode::Manual],
            'manual true/false' => [QuestionType::TrueFalse, QuestionCheckingMode::Manual],
            'manual matching' => [QuestionType::Matching, QuestionCheckingMode::Manual],
            'manual ordering' => [QuestionType::Ordering, QuestionCheckingMode::Manual],
            'manual fill in blank' => [QuestionType::FillInBlank, QuestionCheckingMode::Manual],
            'automatic open written' => [QuestionType::OpenWritten, QuestionCheckingMode::Automatic],
            'automatic file based' => [QuestionType::FileBased, QuestionCheckingMode::Automatic],
        ];
    }

    #[DataProvider('invalidCombinations')]
    public function test_a_type_and_mode_combination_authoring_forbids_throws(
        QuestionType $type,
        QuestionCheckingMode $mode,
    ): void {
        $this->expectException(LogicException::class);

        AnswerCheckingRoute::resolve($type, $mode, '1.000000');
    }

    public function test_invalid_points_throw(): void
    {
        $this->expectException(LogicException::class);

        AnswerCheckingRoute::resolve(QuestionType::OpenWritten, QuestionCheckingMode::Manual, '-1');
    }
}
