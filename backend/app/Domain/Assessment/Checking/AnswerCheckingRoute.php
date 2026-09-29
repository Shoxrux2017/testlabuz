<?php

namespace App\Domain\Assessment\Checking;

use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use LogicException;

/**
 * How an answered Question is checked. An unanswered Question has no answer row
 * and is never routed; it contributes 0.
 */
enum AnswerCheckingRoute: string
{
    case Automatic = 'automatic';
    case TeacherReview = 'teacher_review';
    // Stored as auto_checked with 0 points; it never enters the review queue.
    case ZeroPointClosed = 'zero_point_closed';

    public static function resolve(QuestionType $type, QuestionCheckingMode $mode, string $points): self
    {
        $zeroPoints = (new CheckingScoreMath)->isZero($points);
        $manual = match ($type) {
            QuestionType::OpenWritten, QuestionType::FileBased => $mode === QuestionCheckingMode::Manual
                ? true
                : throw new LogicException("A {$type->value} Question is always checked manually."),
            QuestionType::ShortWritten => $mode === QuestionCheckingMode::Manual,
            default => $mode === QuestionCheckingMode::Automatic
                ? false
                : throw new LogicException("A {$type->value} Question is always checked automatically."),
        };

        if (! $manual) {
            return self::Automatic;
        }

        return $zeroPoints ? self::ZeroPointClosed : self::TeacherReview;
    }
}
