<?php

namespace App\Support\Student;

use App\Enums\AssessmentType;
use App\Models\AssessmentAttempt;

final readonly class StudentAttemptSubmitResult
{
    public function __construct(
        public string $attemptId,
        public AssessmentType $assessmentType,
        public int $httpStatus = 200,
        public ?AssessmentAttempt $attempt = null,
    ) {}
}
