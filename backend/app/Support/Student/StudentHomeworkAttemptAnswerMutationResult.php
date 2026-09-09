<?php

namespace App\Support\Student;

use App\Models\AttemptAnswer;
use App\Models\Question;

final readonly class StudentHomeworkAttemptAnswerMutationResult
{
    public function __construct(
        public Question $question,
        public ?AttemptAnswer $attemptAnswer,
    ) {}
}
