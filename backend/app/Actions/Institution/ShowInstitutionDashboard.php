<?php

namespace App\Actions\Institution;

use App\Enums\UserRole;
use App\Models\User;

class ShowInstitutionDashboard
{
    /**
     * @return array{users: array{teachers: int, students: int, parents: int}}
     */
    public function __invoke(User $actor): array
    {
        $counts = User::query()
            ->where('institution_id', $actor->institution_id)
            ->whereIn('role', [
                UserRole::Teacher->value,
                UserRole::Student->value,
                UserRole::Parent->value,
            ])
            ->selectRaw('count(*) filter (where role = ?) as teachers', [UserRole::Teacher->value])
            ->selectRaw('count(*) filter (where role = ?) as students', [UserRole::Student->value])
            ->selectRaw('count(*) filter (where role = ?) as parents', [UserRole::Parent->value])
            ->toBase()
            ->first();

        return [
            'users' => [
                'teachers' => (int) ($counts->teachers ?? 0),
                'students' => (int) ($counts->students ?? 0),
                'parents' => (int) ($counts->parents ?? 0),
            ],
        ];
    }
}
