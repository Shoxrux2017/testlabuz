<?php

namespace App\Actions\Student;

use App\Enums\AssessmentType;
use App\Models\User;
use App\Support\Student\StudentAttemptSubmitResult;
use App\Support\Student\StudentAttemptTarget;

final class SubmitStudentAttempt
{
    public function __construct(
        private readonly StudentAttemptTarget $target,
        private readonly SubmitStudentHomeworkAttempt $homework,
        private readonly SubmitStudentBlitzAttempt $blitz,
    ) {}

    public function __invoke(User $student, string $attemptId, string $idempotencyKey): StudentAttemptSubmitResult
    {
        return match ($this->target->resolve($student, $attemptId)) {
            AssessmentType::Homework => ($this->homework)($student, $attemptId, $idempotencyKey),
            AssessmentType::Blitz => ($this->blitz)($student, $attemptId, $idempotencyKey),
        };
    }
}
