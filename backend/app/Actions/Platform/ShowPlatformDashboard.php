<?php

namespace App\Actions\Platform;

use App\Enums\InstitutionStatus;
use App\Models\Institution;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;

class ShowPlatformDashboard
{
    public const RECENT_INSTITUTIONS_LIMIT = 5;

    /**
     * @return array{
     *     institutions: array{total: int, active: int, inactive: int},
     *     users: array{total: int, active: int},
     *     recent_institutions: Collection<int, Institution>
     * }
     */
    public function __invoke(): array
    {
        return [
            'institutions' => $this->institutionCounts(),
            'users' => $this->userCounts(),
            'recent_institutions' => $this->recentInstitutions(),
        ];
    }

    /**
     * @return array{total: int, active: int, inactive: int}
     */
    private function institutionCounts(): array
    {
        $counts = Institution::query()
            ->selectRaw('count(*) as total')
            ->selectRaw('count(*) filter (where status = ?) as active', [InstitutionStatus::Active->value])
            ->selectRaw('count(*) filter (where status = ?) as inactive', [InstitutionStatus::Inactive->value])
            ->toBase()
            ->first();

        return [
            'total' => (int) ($counts->total ?? 0),
            'active' => (int) ($counts->active ?? 0),
            'inactive' => (int) ($counts->inactive ?? 0),
        ];
    }

    /**
     * @return array{total: int, active: int}
     */
    private function userCounts(): array
    {
        $counts = User::query()
            ->selectRaw('count(*) as total')
            ->selectRaw('count(*) filter (where is_active = true) as active')
            ->toBase()
            ->first();

        return [
            'total' => (int) ($counts->total ?? 0),
            'active' => (int) ($counts->active ?? 0),
        ];
    }

    /**
     * @return Collection<int, Institution>
     */
    private function recentInstitutions(): Collection
    {
        return Institution::query()
            ->select([
                'id',
                'name',
                'type',
                'status',
                'created_at',
            ])
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit(self::RECENT_INSTITUTIONS_LIMIT)
            ->get();
    }
}
