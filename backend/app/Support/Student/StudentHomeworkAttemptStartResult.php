<?php

namespace App\Support\Student;

final readonly class StudentHomeworkAttemptStartResult
{
    public function __construct(public string $attemptId, public int $httpStatus) {}
}
