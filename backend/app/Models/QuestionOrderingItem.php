<?php

namespace App\Models;

use Database\Factories\QuestionOrderingItemFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['institution_id', 'question_id', 'item_text', 'correct_position'])]
class QuestionOrderingItem extends Model
{
    /** @use HasFactory<QuestionOrderingItemFactory> */
    use HasFactory, HasUuids;

    protected function casts(): array
    {
        return ['correct_position' => 'integer'];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function question(): BelongsTo
    {
        return $this->belongsTo(Question::class);
    }
}
