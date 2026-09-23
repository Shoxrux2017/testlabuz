<?php

namespace App\Models;

use App\Enums\QuestionMatchingSide;
use Database\Factories\QuestionMatchingItemFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

#[Fillable(['institution_id', 'question_id', 'side', 'match_key', 'item_text', 'position'])]
class QuestionMatchingItem extends Model
{
    /** @use HasFactory<QuestionMatchingItemFactory> */
    use HasFactory, HasUuids;

    public function newUniqueId(): string
    {
        // Students receive these IDs; time-ordered IDs would reveal authoring order and thus the pairs.
        return (string) Str::uuid();
    }

    protected function casts(): array
    {
        return ['side' => QuestionMatchingSide::class, 'position' => 'integer'];
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
