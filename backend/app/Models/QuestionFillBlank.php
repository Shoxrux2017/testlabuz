<?php

namespace App\Models;

use Database\Factories\QuestionFillBlankFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['institution_id', 'question_id', 'blank_key', 'position'])]
class QuestionFillBlank extends Model
{
    /** @use HasFactory<QuestionFillBlankFactory> */
    use HasFactory, HasUuids;

    protected function casts(): array
    {
        return ['position' => 'integer'];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function question(): BelongsTo
    {
        return $this->belongsTo(Question::class);
    }

    public function acceptedAnswers(): HasMany
    {
        return $this->hasMany(QuestionFillBlankAcceptedAnswer::class, 'blank_id');
    }
}
