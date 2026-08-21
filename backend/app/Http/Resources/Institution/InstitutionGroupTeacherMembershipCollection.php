<?php

namespace App\Http\Resources\Institution;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

class InstitutionGroupTeacherMembershipCollection extends ResourceCollection
{
    public $collects = InstitutionGroupTeacherMembershipResource::class;

    /**
     * @param  array<string, mixed>  $paginated
     * @param  array<string, mixed>  $default
     * @return array<string, array<string, array<string, int>>>
     */
    public function paginationInformation(Request $request, array $paginated, array $default): array
    {
        return [
            'meta' => [
                'pagination' => [
                    'page' => (int) $this->resource->currentPage(),
                    'per_page' => (int) $this->resource->perPage(),
                    'total' => (int) $this->resource->total(),
                    'last_page' => (int) $this->resource->lastPage(),
                ],
            ],
        ];
    }
}
