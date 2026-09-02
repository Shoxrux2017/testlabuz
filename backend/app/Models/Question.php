<?php

namespace App\Models;

use App\Enums\QuestionCheckingMode;
use App\Enums\QuestionType;
use Database\Factories\QuestionFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable([
    'institution_id',
    'assessment_id',
    'type',
    'prompt',
    'instructions',
    'points',
    'position',
    'checking_mode',
])]
class Question extends Model
{
    /** @use HasFactory<QuestionFactory> */
    use HasFactory, HasUuids;

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'type' => QuestionType::class,
            'points' => 'decimal:6',
            'position' => 'integer',
            'checking_mode' => QuestionCheckingMode::class,
        ];
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(Institution::class);
    }

    public function assessment(): BelongsTo
    {
        return $this->belongsTo(Assessment::class);
    }

    public function choiceOptions(): HasMany
    {
        return $this->hasMany(QuestionChoiceOption::class);
    }

    public function trueFalseAnswer(): HasOne
    {
        return $this->hasOne(QuestionTrueFalseAnswer::class);
    }

    public function shortAcceptedAnswers(): HasMany
    {
        return $this->hasMany(QuestionShortAcceptedAnswer::class);
    }

    public function matchingItems(): HasMany
    {
        return $this->hasMany(QuestionMatchingItem::class);
    }

    public function orderingItems(): HasMany
    {
        return $this->hasMany(QuestionOrderingItem::class);
    }

    public function fillBlanks(): HasMany
    {
        return $this->hasMany(QuestionFillBlank::class);
    }
}
