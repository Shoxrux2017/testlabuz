<?php

namespace App\Http\Resources\Institution;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstitutionDashboardResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var array{users: array{teachers: int, students: int, parents: int}} $dashboard */
        $dashboard = $this->resource;

        return [
            'users' => [
                'teachers' => (int) $dashboard['users']['teachers'],
                'students' => (int) $dashboard['users']['students'],
                'parents' => (int) $dashboard['users']['parents'],
            ],
        ];
    }
}
