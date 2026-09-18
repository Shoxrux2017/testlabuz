<?php

namespace App\Actions\Student;

use App\Models\Assessment;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;

final class ListStudentActiveBlitz
{
    public function __construct(private readonly ReadStudentBlitz $read) {}

    /** @return Collection<int, Assessment> */
    public function __invoke(User $student): Collection
    {
        return ($this->read)($student);
    }
}
