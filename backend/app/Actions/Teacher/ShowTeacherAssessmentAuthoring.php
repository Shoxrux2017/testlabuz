<?php

namespace App\Actions\Teacher;

use App\Enums\AssessmentType;
use App\Models\Assessment;
use App\Models\User;
use LogicException;

final class ShowTeacherAssessmentAuthoring
{
    public function __construct(
        private readonly ShowTeacherHomework $showTeacherHomework,
        private readonly ShowTeacherBlitz $showTeacherBlitz,
    ) {}

    public function __invoke(User $teacher, Assessment $assessment): Assessment
    {
        return match ($assessment->type) {
            AssessmentType::Homework => ($this->showTeacherHomework)($teacher, $assessment->id),
            AssessmentType::Blitz => ($this->showTeacherBlitz)($teacher, $assessment->id),
            default => throw new LogicException('Unsupported Assessment authoring projection type.'),
        };
    }
}
