<?php

namespace App\Http\Resources\Teacher;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;
use Illuminate\Pagination\LengthAwarePaginator;

/** A page of Topic results with the status counts of the whole cohort (docs/09 §25.5). */
class TeacherTopicResultCollection extends ResourceCollection
{
    public $collects = TeacherTopicResultResource::class;

    /** @param array<string, int> $counts */
    public function __construct(LengthAwarePaginator $page, private readonly array $counts)
    {
        parent::__construct($page);
    }

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
                'counts' => $this->counts,
            ],
        ];
    }
}
