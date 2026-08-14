<?php

namespace App\Http\Resources\Institution;

use App\Models\InstitutionUnderstandingCategory;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin InstitutionUnderstandingCategory
 */
class InstitutionUnderstandingCategoryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'code' => $this->code->value,
            'label' => $this->code->label(),
            'min_score' => $this->min_score,
            'max_score' => $this->max_score,
            'sort_order' => $this->sort_order,
        ];
    }
}
