<?php

namespace App\Http\Resources\Platform;

use App\Models\Institution;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PlatformDashboardResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var array{
         *     institutions: array{total: int, active: int, inactive: int},
         *     users: array{total: int, active: int},
         *     recent_institutions: Collection<int, Institution>
         * } $dashboard
         */
        $dashboard = $this->resource;

        return [
            'institutions' => [
                'total' => (int) $dashboard['institutions']['total'],
                'active' => (int) $dashboard['institutions']['active'],
                'inactive' => (int) $dashboard['institutions']['inactive'],
            ],
            'users' => [
                'total' => (int) $dashboard['users']['total'],
                'active' => (int) $dashboard['users']['active'],
            ],
            'recent_institutions' => PlatformRecentInstitutionResource::collection(
                $dashboard['recent_institutions'],
            )->resolve($request),
        ];
    }
}
