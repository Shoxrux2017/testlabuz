<?php

namespace App\Actions\Student;

use App\Models\Assessment;
use App\Models\User;

final class ShowStudentBlitz
{
    public function __construct(private readonly ReadStudentBlitz $read) {}

    public function __invoke(User $student, string $blitzId): Assessment
    {
        return ($this->read)($student, $blitzId)->sole();
    }
}
