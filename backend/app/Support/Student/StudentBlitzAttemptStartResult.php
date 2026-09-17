<?php

namespace App\Support\Student;

use App\Models\AssessmentAttempt;

final readonly class StudentBlitzAttemptStartResult
{
    public string $attemptId;

    public function __construct(public AssessmentAttempt $attempt, public int $httpStatus)
    {
        $this->attemptId = $attempt->id;
    }
}
