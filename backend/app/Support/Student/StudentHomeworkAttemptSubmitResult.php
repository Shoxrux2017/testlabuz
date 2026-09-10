<?php

namespace App\Support\Student;

final readonly class StudentHomeworkAttemptSubmitResult
{
    public function __construct(public string $attemptId, public int $httpStatus = 200) {}
}
