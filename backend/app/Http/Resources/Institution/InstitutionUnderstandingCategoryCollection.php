<?php

namespace App\Http\Resources\Institution;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

class InstitutionUnderstandingCategoryCollection extends ResourceCollection
{
    public $collects = InstitutionUnderstandingCategoryResource::class;

    public function __construct(
        mixed $resource,
        private readonly bool $configured,
    ) {
        parent::__construct($resource);
    }

    /**
     * @return array<string, array<string, bool>>
     */
    public function with(Request $request): array
    {
        if ($this->configured) {
            return [];
        }

        return [
            'meta' => [
                'configured' => false,
            ],
        ];
    }
}
