<?php

namespace App\Models;

use Database\Factories\AnswerMatchingPairFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'institution_id',
    'answer_id',
    'left_item_id',
    'right_item_id',
])]
class AnswerMatchingPair extends Model
{
    /** @use HasFactory<AnswerMatchingPairFactory> */
    use HasFactory, HasUuids;

    public const UPDATED_AT = null;

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function answer(): BelongsTo
    {
        return $this->belongsTo(AttemptAnswer::class, 'answer_id');
    }

    public function leftItem(): BelongsTo
    {
        return $this->belongsTo(QuestionMatchingItem::class, 'left_item_id');
    }

    public function rightItem(): BelongsTo
    {
        return $this->belongsTo(QuestionMatchingItem::class, 'right_item_id');
    }
}
