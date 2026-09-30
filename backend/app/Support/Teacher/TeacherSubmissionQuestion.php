<?php

namespace App\Support\Teacher;

use App\Models\AttemptAnswer;
use App\Models\Question;
use App\Models\User;

/** One Question of a reviewed submission with the Student's answer and its last reviewer. */
final readonly class TeacherSubmissionQuestion
{
    public function __construct(
        public Question $question,
        public ?AttemptAnswer $answer,
        public ?User $reviewer,
    ) {}
}
