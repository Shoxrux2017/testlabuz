<?php

namespace App\Models;

use App\Enums\UnderstandingCategoryCode;
use Database\Factories\InstitutionUnderstandingCategoryFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'code',
    'min_score',
    'max_score',
    'sort_order',
    'updated_by_user_id',
])]
class InstitutionUnderstandingCategory extends Model
{
    /** @use HasFactory<InstitutionUnderstandingCategoryFactory> */
    use HasFactory, HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'code' => UnderstandingCategoryCode::class,
            'min_score' => 'integer',
            'max_score' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by_user_id');
    }
}
