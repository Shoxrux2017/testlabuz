<?php

namespace App\Models;

use Database\Factories\AnswerOrderingItemFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'answer_id',
    'ordering_item_id',
    'submitted_position',
])]
class AnswerOrderingItem extends Model
{
    /** @use HasFactory<AnswerOrderingItemFactory> */
    use HasFactory, HasUuids;

    public const UPDATED_AT = null;

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'submitted_position' => 'integer',
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function answer(): BelongsTo
    {
        return $this->belongsTo(AttemptAnswer::class, 'answer_id');
    }

    public function orderingItem(): BelongsTo
    {
        return $this->belongsTo(QuestionOrderingItem::class, 'ordering_item_id');
    }
}
